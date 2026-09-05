from pathlib import Path
from decouple import config, Csv

# base.py lives at cosmoscrud/settings/base.py — three .parent calls to reach project root
BASE_DIR = Path(__file__).resolve().parent.parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='', cast=Csv())

INSTALLED_APPS = [
    'django.contrib.staticfiles',
    'django.contrib.messages',
    'items',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'cosmoscrud.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'cosmoscrud.wsgi.application'

# No relational database — all application data lives in Cosmos DB.
DATABASES = {}

# The messages framework defaults to session-backed storage; this app has no
# django.contrib.sessions (nothing else needs a relational DB), so store
# messages in a signed cookie instead.
MESSAGE_STORAGE = 'django.contrib.messages.storage.cookie.CookieStorage'

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/cosmos_crud/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ── Cosmos DB ───────────────────────────────────────────────────────
COSMOS_DB_ENDPOINT = config('COSMOS_DB_ENDPOINT')
# Leave blank in Azure — the Container App authenticates with its managed
# identity instead, which Terraform grants the "Cosmos DB Built-in Data
# Contributor" data-plane role (see environments/*/main.tf).
COSMOS_DB_KEY = config('COSMOS_DB_KEY', default='')
COSMOS_DB_DATABASE = config('COSMOS_DB_DATABASE', default='appdb')
COSMOS_DB_CONTAINER = config('COSMOS_DB_CONTAINER', default='items')
