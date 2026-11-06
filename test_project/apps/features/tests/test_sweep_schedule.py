"""What runs the boundary sweep: one run at the next boundary, with the beat hourly behind it."""

from datetime import timedelta

from django.conf import settings

from test_project.celery import app


def test_a_run_is_scheduled_at_the_next_boundary():
    assert settings.ISIK_FEATURES["SWEEP"] == "next_boundary"


def test_the_beat_is_an_hourly_backstop_for_a_run_the_broker_lost():
    assert app.conf.beat_schedule["isik.features.sweep"]["schedule"] == timedelta(hours=1)
