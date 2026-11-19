from apps.common.api.routers import AppRouter
from apps.notifications.api.viewsets.delivery import DeliveryViewSet
from apps.notifications.api.viewsets.device import DeviceViewSet
from apps.notifications.api.viewsets.endpoint import EndpointViewSet
from apps.notifications.api.viewsets.inbox import InboxViewSet
from apps.notifications.api.viewsets.notice_kind import NoticeKindViewSet
from apps.notifications.api.viewsets.subscription import SubscriptionViewSet


app_name = "notifications"

router = AppRouter()
router.register("notifications/inbox", InboxViewSet, basename=InboxViewSet.endpoint)
router.register("notifications/subscriptions", SubscriptionViewSet, basename=SubscriptionViewSet.endpoint)
router.register("notifications/kinds", NoticeKindViewSet, basename=NoticeKindViewSet.endpoint)
router.register("notifications/devices", DeviceViewSet, basename=DeviceViewSet.endpoint)
router.register("notifications/endpoints", EndpointViewSet, basename=EndpointViewSet.endpoint)
router.register("notifications/deliveries", DeliveryViewSet, basename=DeliveryViewSet.endpoint)

urlpatterns = router.urls
