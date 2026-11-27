"""Something always starts the fan-out: the beat."""

from datetime import timedelta

from isik.django.scheduling import beat_schedule, uses_isiks_scheduler

from test_project.celery import app


def test_the_beat_runs_the_declared_tasks_the_fan_out_among_them():
    """isik's scheduler makes the declarations beat's schedule; Celery's own would run only what was merged."""
    assert uses_isiks_scheduler(app.conf)
    assert beat_schedule()["isik.notifications.fan_out"]["schedule"] == timedelta(seconds=10)
