from functools import lru_cache

from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosResourceNotFoundError
from azure.identity import DefaultAzureCredential
from django.conf import settings


@lru_cache(maxsize=1)
def _get_container():
    kwargs = {}
    # The Cosmos DB Emulator serves HTTPS with a self-signed certificate.
    if 'localhost' in settings.COSMOS_DB_ENDPOINT:
        kwargs['connection_verify'] = False

    if settings.COSMOS_DB_KEY:
        credential = settings.COSMOS_DB_KEY
    else:
        # No key configured — authenticate as the Container App's managed
        # identity (or the logged-in `az` account locally). Terraform grants
        # this principal the "Cosmos DB Built-in Data Contributor" role.
        credential = DefaultAzureCredential()

    client = CosmosClient(settings.COSMOS_DB_ENDPOINT, credential=credential, **kwargs)
    database = client.get_database_client(settings.COSMOS_DB_DATABASE)
    return database.get_container_client(settings.COSMOS_DB_CONTAINER)


def ping():
    try:
        _get_container().read()
        return True
    except Exception:
        return False


def list_items():
    return list(
        _get_container().query_items(
            query='SELECT * FROM c ORDER BY c._ts DESC',
            enable_cross_partition_query=True,
        )
    )


def get_item(item_id):
    try:
        return _get_container().read_item(item=item_id, partition_key=item_id)
    except CosmosResourceNotFoundError:
        return None


def create_item(item):
    return _get_container().create_item(body=item)


def update_item(item_id, item):
    return _get_container().replace_item(item=item_id, body=item)


def delete_item(item_id):
    try:
        _get_container().delete_item(item=item_id, partition_key=item_id)
        return True
    except CosmosResourceNotFoundError:
        return False
