from celery import shared_task

from test_project.celery_task import OnCommitTask


@shared_task(name="ping", base=OnCommitTask)
def ping():
    """Proves the Celery pipeline works end to end - replace with real tasks."""
    return "pong"
