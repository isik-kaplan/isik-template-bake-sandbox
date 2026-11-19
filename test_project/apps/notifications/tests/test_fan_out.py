"""Something always starts the fan-out: the beat."""

from isik.django.apps.notifications.schedule import beat_schedule

from test_project.celery import app


def test_the_beat_runs_every_notifications_task():
    """isik.W006 catches a schedule never merged; this catches one merged and later lost."""
    assert beat_schedule().items() <= app.conf.beat_schedule.items()
