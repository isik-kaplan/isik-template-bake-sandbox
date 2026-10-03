from django_hosts import host, patterns


host_patterns = patterns(
    "",
    host(r"api", "test_project.urls.api", name="api"),
    host(r"admin", "test_project.urls.admin", name="admin"),
    host(r"auth", "test_project.urls.auth", name="auth"),
)
