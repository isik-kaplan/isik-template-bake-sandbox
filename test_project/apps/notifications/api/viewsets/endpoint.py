from django.contrib.auth import get_user_model
from django.utils.translation import gettext as _
from isik.django.apps.features.drf import HasFeature
from isik.django.apps.features.resolution import effective
from isik.django.apps.notifications import drf
from isik.django.drf.error_handling import refusal

from apps.common.api.reauthentication import ProvesWhoTheyAre
from apps.features.declarations import WEBHOOKS


class EndpointViewSet(ProvesWhoTheyAre, drf.EndpointViewSet):
    """The signed-in person's webhook endpoints: each is sent their notices of the kinds it wants, signed with its
    secret, which is shown once."""

    endpoint = "endpoints"
    reauthentication_acts = {"create": None, "update": None, "partial_update": None, "rotate_secret": None}
    owner_field = "owner"

    def get_permissions(self):
        # Registering one needs the feature; the ones somebody already has stay theirs to read and delete.
        if self.action == "create":
            return [*super().get_permissions(), HasFeature(WEBHOOKS)()]
        return super().get_permissions()

    def perform_create(self, serializer):
        # The owner's row is the lock, so two registrations at once can't both fit under the limit.
        owner = get_user_model()._default_manager.select_for_update().get(pk=self.request.user.pk)
        if self.owned_endpoints().count() >= effective(owner, "max_endpoints").value:
            raise refusal(_("You have as many webhook endpoints as you may."), code="endpoint_limit_reached")
        super().perform_create(serializer)
