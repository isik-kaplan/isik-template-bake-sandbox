"""serve_file() answers with where nginx finds the file, never the file itself. nginx's half, the
`internal` location it names, is test_project-server/template.nginx.conf's."""

import uuid
from urllib.parse import parse_qs, urlsplit
from urllib.request import urlopen

import pytest
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage

from apps.common.files import serve_file


@pytest.fixture
def stored():
    name = default_storage.save(f"serve-file/{uuid.uuid4().hex}/summary ü.txt", ContentFile(b"hello"))
    yield name
    default_storage.delete(name)


def _url(response):
    return urlsplit(response["X-Storage-Url"])


def test_the_file_is_left_to_nginx_with_a_short_lived_url_to_fetch_it_from(stored):
    response = serve_file(stored)

    assert response["X-Accel-Redirect"] == "/internal/storage/"
    assert response.content == b""
    assert parse_qs(_url(response).query)["X-Amz-Expires"] == ["60"]


def test_the_url_is_the_one_nginx_fetches_and_the_bucket_answers_it(stored):
    with urlopen(serve_file(stored)["X-Storage-Url"]) as answer:
        assert answer.read() == b"hello"


@pytest.mark.parametrize(
    ("kwargs", "disposition"),
    [
        ({}, "inline; filename*=utf-8''summary%20%C3%BC.txt"),
        ({"as_attachment": True}, "attachment; filename*=utf-8''summary%20%C3%BC.txt"),
        ({"filename": "Q3.txt"}, 'inline; filename="Q3.txt"'),
        ({"as_attachment": True, "filename": "Q3.txt"}, 'attachment; filename="Q3.txt"'),
    ],
)
def test_it_is_shown_inline_or_offered_as_a_download_under_its_own_name_or_a_given_one(stored, kwargs, disposition):
    assert serve_file(stored, **kwargs)["Content-Disposition"] == disposition
