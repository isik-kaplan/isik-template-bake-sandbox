"""The task base every `@shared_task` here gets."""

from isik.django.celery import HistoryContextTask

from test_project import __version__
from test_project.config import CONFIG as config


class OnCommitTask(HistoryContextTask):
    """Dispatched on commit (isik's default), or a worker may read a row not there yet."""

    def worker_history_context(self):
        """This process's version, not the dispatcher's: the build running the task wrote the rows."""
        return {**super().worker_history_context(), "version": __version__, "build": config.BUILD}
