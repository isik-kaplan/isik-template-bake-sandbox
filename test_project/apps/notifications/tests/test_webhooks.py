"""Webhook endpoints: who may register them, what they're sent, and that our own network is out of reach."""

import pytest
from django.urls import reverse
from isik.django.apps.features.operations import force_setting, grant
from isik.django.apps.notifications import conf, pipeline

from apps.features.declarations import STAFF, WEBHOOKS
from apps.notifications.models import Delivery, Endpoint, EndpointKind, NoticeKindPolicy
from apps.users.models.user import User
from apps.users.personal_access_tokens import make_token
from conftest import deliver_waiting_notices


ENDPOINTS = reverse("notification-endpoints-list")


def _endpoint(url, **fields):
    endpoint = Endpoint.objects.create(url=url, secret="s3cret", **fields)
    EndpointKind.objects.create(endpoint=endpoint, kind=NoticeKindPolicy.objects.get(name="token_created"))
    return endpoint


def test_receivers_verify_a_header_named_for_the_project_not_its_display_name():
    assert conf.signature_header() == "X-test-project-Signature"


@pytest.mark.django_db
def test_an_endpoint_on_our_own_network_is_refused_without_saying_where_it_led(alice):
    _endpoint("http://database:5432/", owner=alice)
    make_token(user=alice, scopes=[], name="CI")

    deliver_waiting_notices()

    delivery = Delivery.objects.get(channel="webhook")
    assert delivery.state == "abandoned"
    assert "private" in delivery.attempts.get().error
    assert "database" not in delivery.attempts.get().error


@pytest.mark.django_db
def test_an_endpoint_is_sent_its_owners_notices_and_nobody_elses(alice):
    bob = User.objects.create_user(username="bob", email="bob@example.test")
    hers = _endpoint("https://alice.example.test/", owner=alice)
    _endpoint("https://bob.example.test/", owner=bob)
    make_token(user=alice, scopes=[], name="CI")

    pipeline.fan_out()

    (delivery,) = Delivery.objects.filter(channel="webhook")
    assert delivery.webhook.endpoint_id == str(hers.pk)


@pytest.mark.django_db
def test_somebody_sees_and_registers_only_their_own_endpoints(client, signed_in, headless):
    _endpoint("https://bob.example.test/", owner=User.objects.create_user(username="bob", email="bob@example.test"))
    grant(signed_in, WEBHOOKS, source="staff")
    headless.prove()

    made = client.post(ENDPOINTS, {"url": "https://mine.example.test/"}, content_type="application/json")

    assert made.status_code == 201, made.content
    assert Endpoint.objects.get(pk=made.json()["id"]).owner == signed_in
    assert [endpoint["id"] for endpoint in client.get(ENDPOINTS).json()["results"]] == [made.json()["id"]]


@pytest.mark.django_db
def test_registering_an_endpoint_needs_somebody_to_have_just_proved_it_is_them(client, signed_in):
    assert (
        client.post(ENDPOINTS, {"url": "https://mine.example.test/"}, content_type="application/json").status_code
        == 403
    )


@pytest.mark.django_db
def test_registering_one_needs_the_webhooks_feature(client, signed_in, headless):
    headless.prove()

    response = client.post(ENDPOINTS, {"url": "https://mine.example.test/"}, content_type="application/json")

    assert (response.status_code, response.json()["code"]) == (403, "feature_missing")


@pytest.mark.django_db
def test_no_more_endpoints_than_the_limit_staff_set(client, signed_in, headless):
    grant(signed_in, WEBHOOKS, source="staff")
    force_setting(signed_in, "max_endpoints", 1, source=STAFF, reason="One endpoint while the integration is reviewed.")
    _endpoint("https://first.example.test/", owner=signed_in)
    headless.prove()

    response = client.post(ENDPOINTS, {"url": "https://second.example.test/"}, content_type="application/json")

    assert response.status_code == 409
    assert response.json() == {
        "detail": "You have as many webhook endpoints as you may.",
        "code": "endpoint_limit_reached",
    }
