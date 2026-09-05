# Azure Container Apps baseline architecture

Terraform implementation of the architecture described in
[Azure Well-Architected: Container Apps service guide](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-container-apps),
extended to **two independent Django apps sharing one Application Gateway** via
path-based routing:

```
                    Internet
                       |
             Azure Application Gateway (WAF v2)
                       |
         +-------------+-------------+
         |                           |
   Path: /tasks/*             Path: /cosmos_crud/*
         |                           |
         v                           v
  ca-django-todo               ca-cosmos-crud
 (Django_todo_app/)             (cosmos_crud/)
         |                           |
         v                           v
  PostgreSQL Flexible          Cosmos DB (SQL API)
       Server
```

Both Container Apps are internal-only (reachable exclusively from inside the
VNet, via the Container Apps Environment's internal load balancer) — the
Application Gateway is the only public entry point. Each app has its own
user-assigned managed identity (`id-django-todo-*` / `id-cosmos-crud-*`),
scoped to only the resources it needs: `django_todo` gets `AcrPull` + `Key
Vault Secrets User`; `cosmos_crud` gets `AcrPull` + the Cosmos DB "Built-in
Data Contributor" data-plane role. Neither identity can touch the other app's
database.

## Repository structure

```
terraform_Architecture_Azure_Container_Apps/
│
├── environments/            # one deployable root module per environment
│   ├── dev/
│   ├── staging/             # this is Django_todo_app's "UAT"
│   └── prod/
│       ├── backend.tf       # remote state config (state `key` differs per env)
│       ├── providers.tf
│       ├── versions.tf
│       ├── main.tf          # wires the modules together
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars # the only file that actually differs in content between envs
│
├── modules/
│   ├── network/              # VNet + 4 subnets (App Gateway, Container Apps, private endpoints, PostgreSQL)
│   ├── nsg/                  # NSGs + subnet associations for those subnets
│   ├── appgateway/            # WAF policy + Application Gateway, path-based routing to 2 backends
│   ├── containerapps/         # Container Apps Environment + its own private DNS zone (shared by both apps)
│   ├── containerapp/           # One Container App (generic — instantiated twice: django_todo, cosmos_crud)
│   ├── database/               # Cosmos DB (SQL API)
│   ├── postgresql/              # PostgreSQL Flexible Server (VNet-integrated, for Django_todo_app)
│   ├── keyvault/                # Key Vault (RBAC-authorized)
│   ├── containerregistry/        # Azure Container Registry (SKU per environment)
│   ├── privateendpoints/          # Private DNS zones + private endpoints for ACR/Key Vault/Cosmos DB
│   └── monitoring/                 # Log Analytics workspace
│
├── Django_todo_app/           # Django app served at /tasks/* — PostgreSQL
├── cosmos_crud/                # Django app served at /cosmos_crud/* — Cosmos DB
│
├── scripts/
│   ├── deploy.sh               # apply -> build+push images -> apply again, for one environment
│   ├── build-images.sh          # docker build+push both apps straight from the local dirs above
│   └── bootstrap-acr.sh          # documented no-op — see the file header
│
├── backend.tf                # canonical template — copy into environments/<env>/backend.tf
├── providers.tf               # canonical template — copy into environments/<env>/providers.tf
├── versions.tf                 # canonical template — copy into environments/<env>/versions.tf
└── README.md
```

**Note on the root `backend.tf` / `providers.tf` / `versions.tf`:** Terraform has no
concept of a parent root module — each `environments/<env>/` directory is a
fully independent root module that you `cd` into and `terraform init` directly.
The copies at the repo root exist as the canonical, kept-in-sync template;
the real, active configuration is the copy inside each environment directory.
If you change provider/version constraints, edit the root copy and re-sync it
into all three environments.

The requested template also listed `vmss`, `bastion`, and `storage` modules.
This architecture doesn't use IaaS VMs (Container Apps is a fully managed
compute platform, so there's no VM Scale Set or bastion host to manage) or a
general-purpose storage account, so those were swapped for `containerapps`,
`containerregistry`, and `privateendpoints` — the pieces this specific
diagram actually needs. `loadbalancer` became `appgateway` since the diagram
uses an Application Gateway (L7, WAF-capable), not an Azure Load Balancer.

## Before you apply

1. Create (once, outside this config) a storage account for remote state, and
   fill in its real name in each `environments/<env>/backend.tf`
   (`resource_group_name` / `storage_account_name` / `container_name`).
2. `az login` and select the target subscription (`az account set --subscription <id>`).
3. Review `environments/<env>/terraform.tfvars` and adjust as needed.
4. The Application Gateway ships with only an HTTP (port 80) listener so the
   stack is deployable as-is. For production, add a port 443 listener with a
   certificate (ideally Key Vault-backed via a User Assigned Identity on the
   gateway) — see the comment in `modules/appgateway/main.tf`.
5. Both container apps start on the public sample image
   `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` (via
   `todo_container_image` / `cosmos_crud_container_image`), so the first
   apply succeeds before either app's real image exists. After that, run
   `../../scripts/deploy.sh <environment>` (or `build-images.sh` + a second
   `apply` by hand — see "Building and deploying the apps" below) to build
   and push the real images and roll them out.
6. Cosmos DB and Key Vault have public network access disabled — you'll need
   connectivity to the VNet (VPN/ExpressRoute/bastion/jumpbox) to manage their
   data planes directly; Terraform itself only needs the ARM control plane,
   which stays reachable. ACR has public network access enabled so `docker
   push` works from outside the VNet.
7. The Container Apps infrastructure subnet must be delegated to
   `Microsoft.App/environments` (handled in `modules/network`) — Azure
   rejects the Managed Environment otherwise.
8. ACR private endpoints require the **Premium** SKU. `acr_sku` /
   `acr_private_endpoint_enabled` are set per environment:
   staging/prod default to Premium with the private endpoint enabled; dev
   defaults to Basic with the private endpoint disabled (ACR stays reachable
   over the public network instead) to avoid the ~$50/month Premium cost on
   a free/trial subscription. Set `acr_sku = "Premium"` and
   `acr_private_endpoint_enabled = true` for dev if you want it locked down
   like staging/prod.
9. PostgreSQL Flexible Server (added for `Django_todo_app`) has no private
   endpoint support — it's reachable only via VNet integration into its own
   delegated subnet (`postgresql_subnet_prefix`), resolved through the
   `privateendpoints`-style private DNS zone the `postgresql` module creates
   itself. The admin password is generated by Terraform (`random_password`)
   and never appears in tfvars; it's only readable via a sensitive
   `terraform output`.

## Secrets: Django Todo + Key Vault

`Django_todo_app`'s `SECRET_KEY` and `POSTGRES_PASSWORD` are generated by
Terraform (`random_password`), written into Key Vault as
`azurerm_key_vault_secret` resources, and wired into the `ca-django-todo`
Container App as native Key Vault secret references (`secret { ... }` /
`env { secret_name = ... }` on `azurerm_container_app`, via the
`modules/containerapp` module's `secrets` / `secret_env_vars` inputs) —
there's no post-apply script to run, and no secret value ever appears in
tfvars or `env_vars`. The Container App's managed identity
(`id-django-todo-*`) holds "Key Vault Secrets User" on the vault so it can
read them at runtime. Everything else Django needs (`POSTGRES_DB`,
`POSTGRES_USER`, `DB_HOST`, `DB_PORT`, `ALLOWED_HOSTS`,
`DJANGO_SETTINGS_MODULE`) is non-secret configuration, passed as plain
`env_vars` straight from Terraform. `cosmos_crud` needs no Key Vault secret at
all — it authenticates to Cosmos DB purely via its own managed identity
(`id-cosmos-crud-*`, granted the Cosmos DB "Built-in Data Contributor" role),
so `COSMOS_DB_KEY` is never set in Azure.

`SECRET_KEY` won't rotate on a later `terraform apply` (that would invalidate
every active Django session) unless you deliberately change the
`random_password.django_secret_key` resource's own arguments.

Prod-only SMTP credentials (`EMAIL_HOST_PASSWORD` etc.) aren't derivable from
this Terraform config; set them by hand with `az keyvault secret set` and add
a corresponding `secrets`/`secret_env_vars` entry to the `django_todo` module
call in `environments/prod/main.tf` if/when you need outbound email.

## Building and deploying the apps

Both Django apps live in this repository (`Django_todo_app/`, `cosmos_crud/`)
— there's no separate app repo to clone. `scripts/build-images.sh` builds and
pushes both straight from those local directories to the target
environment's ACR, tagged with the current git commit SHA; `scripts/deploy.sh`
runs the full `apply -> build+push -> apply` sequence for one environment:

```bash
./scripts/deploy.sh dev   # or staging / prod
```

or step by step:

```bash
cd environments/dev
terraform init
terraform apply -var-file=terraform.tfvars   # infra, placeholder image on a first run

cd ../..
./scripts/build-images.sh dev                # builds + pushes django-todo and cosmos-crud

cd environments/dev
terraform apply -var-file=terraform.tfvars \
  -var="todo_container_image=<printed by build-images.sh>" \
  -var="cosmos_crud_container_image=<printed by build-images.sh>"
```

`scripts/bootstrap-acr.sh` is a documented no-op — see its header comment for
why (the ACR is created by Terraform itself, not by a separate bootstrap
step).

## Notes / things to extend for production

- Add HTTPS listener + cert on the Application Gateway, and an HTTP->HTTPS redirect rule.
- Consider Azure Front Door in front of the Application Gateway for global routing/CDN, per the WAF service guide.
- Lock down NSGs further once real traffic patterns are known.
- Add diagnostic settings (Log Analytics/Storage) for App Gateway, Key Vault, ACR, and Cosmos DB if not already covered by policy.
- The `Key Vault Administrator` role is granted to the Terraform caller's identity for bootstrapping secrets; narrow or remove this in production.
- CI/CD: point separate pipeline stages at `environments/dev`, `environments/staging`, `environments/prod`, each with its own state and (ideally) its own service principal / OIDC federation scoped to that subscription or resource group.
