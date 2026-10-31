import os

from celery import Celery
from isik.django.apps.features.schedule import merge_beat_schedule as merge_features_beat_schedule
from isik.django.apps.notifications.schedule import merge_beat_schedule


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "test_project.settings")

app = Celery(
    "test_project",
    task_cls="test_project.celery_task:OnCommitTask",
)
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
app.conf.task_time_limit = 240
app.conf.task_soft_time_limit = 120
# django-celery-beat copies the schedule into its table when beat starts.
merge_beat_schedule(app)
# Tells a trial that ended with no write that it ended.
merge_features_beat_schedule(app)
