from isik.django.apps.notifications.audience import bases

from apps.common.models.base import primary_key
from apps.notifications.keys import user_key


class Endpoint(bases.AbstractEndpoint):
    id = primary_key()
    owner = user_key("who registered it, and whose notices it receives")

    class Meta(bases.AbstractEndpoint.Meta):
        db_table = "notifications_endpoint"
