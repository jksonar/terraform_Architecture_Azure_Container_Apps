from .base import *

DEBUG = False

# UAT is typically not behind HTTPS — keep secure flags off until TLS is configured
SECURE_SSL_REDIRECT = False
CSRF_COOKIE_SECURE = False
