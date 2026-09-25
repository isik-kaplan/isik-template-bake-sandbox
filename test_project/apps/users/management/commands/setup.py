from django.core.management.base import BaseCommand

from apps.users.models.user import User
from test_project.config import CONFIG as config


class Command(BaseCommand):
    help = "Bootstraps a local-dev superuser from SETUP__SUPERUSER__* if none exists yet."

    def handle(self, *args, **options):
        if User.objects.filter(is_superuser=True).exists():
            self.stdout.write("A superuser already exists, skipping.")
            return
        User.objects.create_superuser(
            username=config.SETUP.SUPERUSER.USERNAME,
            email=config.SETUP.SUPERUSER.EMAIL,
            password=config.SETUP.SUPERUSER.PASSWORD,
        )
        self.stdout.write(self.style.SUCCESS(f"Created superuser '{config.SETUP.SUPERUSER.USERNAME}'."))
