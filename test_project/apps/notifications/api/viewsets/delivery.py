from isik.django.apps.notifications import drf


class DeliveryViewSet(drf.DeliveryViewSet):
    """What the signed-in person's webhook endpoints were sent, each with its attempts. retry/ sends an abandoned one
    again."""

    endpoint = "notification-deliveries"
    owner_field = "owner"
