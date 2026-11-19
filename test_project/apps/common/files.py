"""A view authorizes, nginx sends, via `X-Accel-Redirect` to an `internal` location in
test_project-server/template.nginx.conf: no worker tied up, and no public media URL.
"""

import posixpath

from django.core.files.storage import default_storage
from django.http import HttpResponse
from django.utils.http import content_disposition_header


ACCEL_REDIRECT_HEADER = "X-Accel-Redirect"

# nginx's location fetching from the bucket, and the header it reads the presigned URL from.
STORAGE_LOCATION = "/internal/storage/"
STORAGE_URL_HEADER = "X-Storage-Url"

# Seconds; nginx fetches as soon as the response arrives, and the client never sees the URL.
URL_LIFETIME = 60


def serve_file(name, *, as_attachment=False, filename=None):
    """Inline unless `as_attachment`. The disposition is set here because a bucket answering a range
    may leave its own out."""
    response = HttpResponse()
    response[ACCEL_REDIRECT_HEADER] = STORAGE_LOCATION
    response[STORAGE_URL_HEADER] = default_storage.url(name, expire=URL_LIFETIME)
    response["Content-Disposition"] = content_disposition_header(as_attachment, filename or posixpath.basename(name))
    return response
