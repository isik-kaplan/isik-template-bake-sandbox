import os

from celery import Celery


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "test_project.settings")

# Every task defers its dispatch until the transaction that asked for it commits - see celery_task.py.
app = Celery(
    "test_project",
    task_cls="test_project.celery_task:OnCommitTask",
)
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
app.conf.task_time_limit = 240
app.conf.task_soft_time_limit = 120
