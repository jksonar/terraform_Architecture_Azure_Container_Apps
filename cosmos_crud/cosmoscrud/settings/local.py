from .base import *
from decouple import config

DEBUG = True
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0']

# Fallback insecure key so bare git-clone works without any .env file
SECRET_KEY = config('SECRET_KEY', default='django-insecure-local-dev-only-change-me')

# Defaults point at the Azure Cosmos DB Emulator so a bare git-clone works
# without any .env file. The key below is the emulator's well-known, publicly
# documented master key — not a secret. Override in .env.local to point at a
# real (dev) Cosmos account instead.
COSMOS_DB_ENDPOINT = config('COSMOS_DB_ENDPOINT', default='https://localhost:8081')
COSMOS_DB_KEY = config(
    'COSMOS_DB_KEY',
    default='C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==',
)
