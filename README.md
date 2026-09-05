# Azure Container Apps baseline architecture

Terraform implementation of the architecture described in
[Azure Well-Architected: Container Apps service guide](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-container-apps):
`Internet -> Application Gateway -> Container App (VNet-internal) -> [Cosmos DB | Key Vault | Container Registry]`,
all downstream dependencies reachable only via private endpoints.

## Repository structure

```
azure-terraform-project/
│
├── environments/            # one deployable root module per environment
│   ├── dev/
│   ├── staging/
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
│   ├── network/              # VNet + 3 subnets (App Gateway, Container Apps, private endpoints)
│   ├── nsg/                  # NSGs + subnet associations for those 3 subnets
│   ├── appgateway/            # Public IP + WAF policy + Application Gateway
│   ├── containerapps/         # Container Apps Environment + Container App + its own private DNS zone
│   ├── database/               # Cosmos DB (SQL API)
│   ├── keyvault/                # Key Vault (RBAC-authorized)
│   ├── containerregistry/        # Azure Container Registry (SKU per environment)
│   ├── privateendpoints/          # Private DNS zones + private endpoints for ACR/Key Vault/Cosmos DB
│   └── monitoring/                 # Log Analytics workspace
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
5. The container app starts on the public sample image
   `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`. After the
   first apply, push your real image to the created ACR and set
   `container_image` in that environment's `terraform.tfvars`, then re-apply.
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

## Usage

```bash
cd environments/dev   # or staging / prod
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Notes / things to extend for production

- Add HTTPS listener + cert on the Application Gateway, and an HTTP->HTTPS redirect rule.
- Consider Azure Front Door in front of the Application Gateway for global routing/CDN, per the WAF service guide.
- Lock down NSGs further once real traffic patterns are known.
- Add diagnostic settings (Log Analytics/Storage) for App Gateway, Key Vault, ACR, and Cosmos DB if not already covered by policy.
- The `Key Vault Administrator` role is granted to the Terraform caller's identity for bootstrapping secrets; narrow or remove this in production.
- CI/CD: point separate pipeline stages at `environments/dev`, `environments/staging`, `environments/prod`, each with its own state and (ideally) its own service principal / OIDC federation scoped to that subscription or resource group.
