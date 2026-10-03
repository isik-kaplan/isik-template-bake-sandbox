import os

from celery import Celery


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "test_project.settings")

app = Celery("test_project")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
app.conf.task_time_limit = 240
app.conf.task_soft_time_limit = 120
