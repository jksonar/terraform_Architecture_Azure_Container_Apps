Question
Help me to create plan for my terraform architecture.
I want container application environment like https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-container-apps in this URL.

But i will have some changes 
there will be two container application sharing same application gateway with route path like /tasks to "git@github.com:jksonar/Django_todo_app.git" python django application and one for /cosmos_crud which will be crud django application 
Django_todo_app will use postgresql flexible  server and crud django application will use cosmos DB 
I am using this terraform code git@github.com:jksonar/terraform_Architecture_Azure_Container_Apps.git
I like to edit this code
i like to use azure key vault to store all credentials for Django_todo_app.
if container registry require before container application creation then need some solution to create it before then build and push image to registry so image can be use during terraform apply. 

Answer

Yes. I reviewed your current Terraform repository, the Django Todo application, and the Microsoft Azure Container Apps Well-Architected architecture you referenced.

Your current repository is already a good starting point: it has separate modules for networking, Application Gateway, Container Apps, ACR, PostgreSQL, Key Vault, Cosmos DB, private endpoints, monitoring, and separate environment roots. ([GitHub][1])

The main architectural change I recommend is to **separate infrastructure provisioning from container image build/deployment**.

![Image](https://images.openai.com/static-rsc-4/ZkZTyf52FeMyKDhAoBtEpGy_XIQoIqjJaxxw9t4LhS2cUQMdTeHlc8xLIP5Pot-38L9sD3azZzgfxdRFantQmNjwieVEQbOmSTk4FHGm7FR335vuSY2kIaTPY8duA9YVTdrRwuTr0ml8UsBg6c000z-CZlL1g7Ikg8r_WY1jmNqcVb6RGExru5iNn8VW-4B0?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/zDT4BZTTG1g8fqLKqJmH8A9wU1vo7RDF_9pCwRBlp1TY89M6Tro1yAYf7PB0kBL09-gC2Uc1BlMy_fb4uR3hmeSHgrKmjubhmSb8IoHYjeRndKGWmjq3sba54P7qLTW4JkSohPmoYBytFs-IbkbJRGbw5oJ62JYYODinRVijuwP13039DqmM8GVaIk9qiDtj?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/yFnjeQujnafskSEm_dVSGaoHqcHqOoNptkWs3cpASuKUq-PLxbeFZhSbIkWQojSgPSSDkiSxcKy5WLPz76gCKD4CrJ26JnwSmTR3XV-vWKuZ05fPEkYpe4gsCmWzO_9-nph1reEA1VbIJL3Q5bpebZd_wIo0SBdCl0VAwCZcFG-MT7weiMk43zIpcWUvXkwT?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/SSQfVaZQzScjZDsnYTn4ciSJ1eru50gCvNYOPy4uuozkheAsvUEItSODBuZyisyr9PlpSDQbsooomxuvxnhTJRYn4yGdtCZrjWv4qml7QatDwOoeleqTemug-1_lBie7K2ldAUywiwtI_WTOh-e7e2iM_d_M9RFILwd9kLcc30hlvGWZmC8-aNME2_mYuD50?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/KzTw1jxEdIvWmN02gmx_3CDii5lAnCZ-SR8iVC-gXIoQy157K9Sw6HiR0pXKP7bBimLA5Iv_9E9R9b8maphESmwumQPBy5oq7JUN_tDSmWYyKrylYFl91BFXQdntt3quK-MizziNzsnGvpG6TNGZm4y7Nz3HexmpIIN_cvbaFD3ODGnx1nOJaGtyHwOP2mT9?purpose=fullsize)

# 1. Target architecture

I would build your architecture like this:

```text
                         Internet
                            |
                            |
                    Azure Application Gateway
                         WAF v2
                            |
                  HTTPS / TLS termination
                            |
              +-------------+-------------+
              |                           |
        Path: /tasks               Path: /cosmos_crud
              |                           |
              v                           v
     Django Todo Container        Django Cosmos CRUD Container
        Azure Container App          Azure Container App
              |                           |
              |                           |
              v                           v
   PostgreSQL Flexible Server          Cosmos DB
              |
              |
        Private networking


                    Azure Container Apps
                           |
             +-------------+-------------+
             |             |             |
             v             v             v
          Key Vault       ACR       Log Analytics
             ^
             |
      Managed Identity
```

The important part is that **both Django applications are independent Container Apps but share the same Application Gateway**.

Your routing becomes:

```text
https://your-domain.com/tasks/*
                         |
                         +--> django-todo-app


https://your-domain.com/cosmos_crud/*
                         |
                         +--> django-cosmos-crud
```

This is a good fit for Application Gateway because it provides L7/path-based routing. The Terraform provider supports separate listeners, backend pools, probes, HTTP settings and routing rules. ([Terraform Registry][2])

---

# 2. What I would change in your existing repository

Your current repository looks approximately like:

```text
terraform_Architecture_Azure_Container_Apps/
│
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
│
├── modules/
│   ├── appgateway/
│   ├── containerapps/
│   ├── containerregistry/
│   ├── database/
│   ├── keyvault/
│   ├── monitoring/
│   ├── network/
│   ├── nsg/
│   ├── postgresql/
│   └── privateendpoints/
│
└── Django_todo_app/
```

This is already modular and I would **not rewrite the entire repository**. ([GitHub][3])

Instead, I recommend evolving it into:

```text
terraform_Architecture_Azure_Container_Apps/
│
├── environments/
│   │
│   ├── dev/
│   │   ├── foundation.tf
│   │   ├── workloads.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   │
│   ├── staging/
│   │
│   └── prod/
│
├── modules/
│   ├── network/
│   ├── nsg/
│   ├── appgateway/
│   ├── containerapps/
│   ├── containerregistry/
│   ├── database/
│   ├── postgresql/
│   ├── keyvault/
│   ├── privateendpoints/
│   ├── monitoring/
│   └── identities/
│
└── scripts/
    ├── bootstrap-acr.sh
    ├── build-images.sh
    └── deploy.sh
```

I would particularly add an **`identities` module**.

---

# 3. Two Container Apps

Instead of the current single Container App, create two:

```text
containerapps
│
├── django-todo
│   ├── image
│   ├── ingress
│   ├── identity
│   ├── key vault references
│   └── PostgreSQL connectivity
│
└── cosmos-crud
    ├── image
    ├── ingress
    ├── identity
    └── Cosmos DB connectivity
```

For example:

```hcl
module "django_todo" {
  source = "../../modules/containerapps"

  name = "ca-django-todo"

  container_image = var.todo_container_image

  environment_id = module.containerapps.environment_id

  target_port = 8000

  ingress_external_enabled = false
}
```

And:

```hcl
module "cosmos_crud" {
  source = "../../modules/containerapps"

  name = "ca-cosmos-crud"

  container_image = var.cosmos_crud_container_image

  environment_id = module.containerapps.environment_id

  target_port = 8000

  ingress_external_enabled = false
}
```

The Container Apps themselves should **not be publicly exposed**.

Application Gateway should be the public entry point.

---

# 4. Application Gateway routing

The Application Gateway becomes:

```text
Application Gateway
│
├── Frontend
│   └── Public IP
│
├── Listener
│   └── HTTPS :443
│
├── Backend Pool
│   ├── django-todo
│   └── cosmos-crud
│
├── Routing Rules
│   │
│   ├── /tasks/*
│   │      └── django-todo
│   │
│   └── /cosmos_crud/*
│          └── cosmos-crud
│
└── Health Probes
    ├── /tasks/health/
    └── /cosmos_crud/health/
```

I strongly recommend adding dedicated Django health endpoints.

For example:

```text
/tasks/health/
/cosmos_crud/health/
```

Application Gateway can then determine whether each Container App is healthy.

---

# 5. Important Django consideration: `/tasks`

There is one thing I would decide **before modifying Terraform**.

If your Django application currently expects:

```text
/
```

but Application Gateway sends:

```text
/tasks/
```

Django may need configuration for the URL prefix.

You have two choices.

### Option A — Application Gateway strips `/tasks`

Request:

```text
/tasks/login/
```

Application Gateway sends:

```text
/login/
```

to Django.

This is probably the easiest approach if your existing Django application isn't designed for a prefix.

### Option B — Django knows it is running under `/tasks`

Configure:

```python
FORCE_SCRIPT_NAME = "/tasks"
```

and potentially:

```python
STATIC_URL = "/tasks/static/"
```

depending on how your application is structured.

I would initially use **Option A** to minimize changes to your existing `Django_todo_app`.

Your Todo application currently uses Django/uvicorn and exposes the application on port 8000, so this maps naturally to Container Apps. ([GitHub][4])

---

# 6. PostgreSQL architecture

Your Todo application already expects PostgreSQL for dev/UAT/prod. ([GitHub][4])

The target becomes:

```text
Django Todo
     |
     | 5432
     |
     v
PostgreSQL Flexible Server
     |
     └── Private networking
```

I recommend:

```text
VNet
│
├── Application Gateway subnet
│
├── Container Apps subnet
│
├── PostgreSQL delegated subnet
│
└── Private Endpoint subnet
```

For PostgreSQL Flexible Server, Azure supports private connectivity/VNet integration, and private DNS is important for resolving the database privately. ([Microsoft Learn][5])

Your existing repository already accounts for PostgreSQL as a separate module. ([GitHub][1])

---

# 7. Cosmos DB architecture

The second application becomes:

```text
Cosmos CRUD Container App
          |
          |
          v
     Private Endpoint
          |
          v
       Cosmos DB
```

I would also disable public network access for Cosmos DB.

Your existing architecture already uses private endpoints for Cosmos DB. ([GitHub][1])

The Cosmos application should have its **own managed identity**.

For example:

```text
mi-django-todo
        |
        +--> Key Vault
        +--> ACR

mi-cosmos-crud
        |
        +--> Cosmos DB
        +--> ACR
```

This is better than giving both applications one broad identity.

---

# 8. Key Vault design

This is one of the most important changes.

You said:

> I like to use Azure Key Vault to store all credentials for Django_todo_app.

I agree.

The Todo Container App should retrieve secrets from Key Vault rather than Terraform putting secret values directly into the Container App.

Azure Container Apps supports Key Vault secret references using managed identities, and the identity can be granted the **Key Vault Secrets User** RBAC role. ([Microsoft Learn][6])

Architecture:

```text
                     Azure Key Vault
                           |
             +-------------+-------------+
             |             |             |
             v             v             v
         SECRET_KEY   POSTGRES_PASSWORD  SMTP_PASSWORD
             |
             |
             v
       Managed Identity
             |
             v
       Django Container App
```

Potential secrets:

```text
django-secret-key
postgres-admin-password
email-host-password
```

Potential configuration values:

```text
POSTGRES_DB
POSTGRES_USER
DB_HOST
DB_PORT
DJANGO_SETTINGS_MODULE
DEBUG
ALLOWED_HOSTS
```

Not everything needs to be a secret.

For example:

```text
DB_HOST
DB_PORT
POSTGRES_DB
```

are configuration values rather than credentials.

---

# 9. Use Managed Identity for ACR

Do **not** put:

```text
ACR_USERNAME
ACR_PASSWORD
```

inside Terraform.

Instead:

```text
Container App
      |
      | Managed Identity
      |
      v
Azure Container Registry
      |
      └── AcrPull
```

Azure explicitly supports using managed identity for Container Apps to pull private images from ACR. Microsoft recommends user-assigned managed identities when possible. ([Microsoft Learn][7])

So I would create:

```text
module "identities"

    ├── todo_identity
    └── cosmos_identity
```

and assign:

```text
todo_identity
    ├── AcrPull
    └── Key Vault Secrets User

cosmos_identity
    ├── AcrPull
    └── Cosmos DB data-plane role
```

---

# 10. Your biggest issue: ACR vs Terraform

This is the important part of your question.

You correctly identified the problem:

```text
Terraform creates ACR
       |
       v
Container App needs image
       |
       v
But image doesn't exist yet
```

I **do not recommend trying to make Terraform build Docker images**.

Instead use a two-phase deployment.

## Recommended architecture

```text
                 Terraform
                    |
                    v
          ┌───────────────────┐
          │ Foundation Layer  │
          └───────────────────┘
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
       ACR       Key Vault    Database
        |
        v
     Terraform
     completes
        |
        v
      CI/CD
        |
        +------------------+
        |                  |
        v                  v
 Docker build          Docker build
 Django Todo            Cosmos CRUD
        |                  |
        +--------+---------+
                 |
                 v
                ACR
                 |
                 v
          image:tag / digest
                 |
                 v
          Terraform
          Workload Layer
                 |
        +--------+--------+
        |                 |
        v                 v
   Container App 1   Container App 2
```

This is much cleaner.

---

# 11. Phase 1 — Foundation

Terraform creates everything required before applications.

```text
terraform apply foundation
```

Creates:

```text
Resource Group
VNet
Subnets
NSGs
Application Gateway
Public IP
Container Apps Environment
ACR
Key Vault
PostgreSQL
Cosmos DB
Private DNS
Private Endpoints
Managed Identities
Log Analytics
```

But **don't create the real Container Apps yet**.

At this point you have:

```text
ACR
    |
    +-- empty
```

---

# 12. Phase 2 — Build Docker images

Your CI/CD pipeline checks out:

```text
https://github.com/jksonar/Django_todo_app
```

and builds:

```bash
docker build \
  -t <acr>.azurecr.io/django-todo:<git-sha> .
```

Then:

```bash
docker push \
  <acr>.azurecr.io/django-todo:<git-sha>
```

For the second application:

```bash
docker build \
  -t <acr>.azurecr.io/cosmos-crud:<git-sha> .
```

and:

```bash
docker push \
  <acr>.azurecr.io/cosmos-crud:<git-sha>
```

I recommend using immutable tags:

```text
django-todo:8f2c9e1
cosmos-crud:8f2c9e1
```

rather than:

```text
latest
```

Even better, eventually deploy using image digests.

---

# 13. Phase 3 — Deploy Container Apps

Now Terraform receives:

```hcl
todo_container_image = "myacr.azurecr.io/django-todo:8f2c9e1"

cosmos_container_image = "myacr.azurecr.io/cosmos-crud:8f2c9e1"
```

Then:

```bash
terraform apply
```

creates:

```text
Container Apps Environment
        |
        +-------------------------+
        |                         |
        v                         v
django-todo                 cosmos-crud
        |                         |
        v                         v
PostgreSQL                    Cosmos DB
```

The Terraform provider supports Container App registry configuration using managed identity, so the Container App can pull from ACR without embedding registry credentials. ([Terraform Registry][8])

---

# 14. I recommend TWO Terraform states

Rather than trying to solve everything inside one Terraform state, I'd strongly recommend:

```text
Terraform
│
├── foundation
│
└── workloads
```

For example:

```text
environments/
└── dev/
    │
    ├── foundation/
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── workloads/
        ├── backend.tf
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

Then:

```text
foundation.tfstate
       |
       v
ACR + VNet + KV + DB + Cosmos + identities
```

and:

```text
workloads.tfstate
       |
       v
Container Apps + Application Gateway routing
```

This gives you a very clean lifecycle.

---

# 15. But there is an even better CI/CD model

I would actually use **three pipeline stages**.

```text
Stage 1
Terraform Foundation
       |
       v
Stage 2
Docker Build + Push
       |
       v
Stage 3
Terraform Workloads
```

Example:

```text
             Git Push
                |
                v
       ┌─────────────────┐
       │ Terraform Init  │
       └────────┬────────┘
                |
                v
       ┌─────────────────┐
       │ Terraform Apply │
       │   Foundation    │
       └────────┬────────┘
                |
                v
       ┌─────────────────┐
       │ Docker Build    │
       │ Docker Push     │
       └────────┬────────┘
                |
                v
       ┌─────────────────┐
       │ Terraform Apply │
       │    Workloads    │
       └────────┬────────┘
                |
                v
       ┌─────────────────┐
       │ Health Checks   │
       └─────────────────┘
```

---

# 16. Don't put Docker build inside Terraform

You could technically use things like:

```hcl
null_resource
local-exec
```

to run:

```bash
docker build
docker push
```

but I strongly recommend **not doing this**.

Terraform's responsibility:

```text
Infrastructure
```

CI/CD's responsibility:

```text
Application artifact
```

So:

```text
Terraform
  ├── Azure VNet
  ├── Azure ACR
  ├── PostgreSQL
  ├── Cosmos DB
  ├── Key Vault
  ├── Container Apps
  └── Application Gateway

CI/CD
  ├── checkout
  ├── test
  ├── docker build
  ├── docker scan
  ├── docker push
  └── terraform workload deployment
```

This separation will save you many problems later.

---

# 17. ACR bootstrap problem

There is another issue.

If ACR is private:

```text
Container Apps
      |
      v
Private ACR
```

your CI/CD runner needs a path into the Azure VNet to push images.

Your current repository intentionally leaves ACR public in dev and notes that private ACR requires Premium. ([GitHub][1])

You have two choices.

### Development

Use:

```text
ACR public access
```

and:

```text
docker push
```

from your CI/CD runner.

This is easiest.

### Production

Use:

```text
ACR Premium
       |
       v
Private Endpoint
       |
       v
VNet
```

and run your CI/CD build agent somewhere with VNet access.

For example:

```text
Azure DevOps self-hosted agent
       |
       v
VNet
       |
       v
Private ACR
```

or:

```text
self-hosted GitLab Runner
       |
       v
VNet
       |
       v
Private ACR
```

---

# 18. Key Vault secret population

I would also change the existing approach slightly.

Your repository currently has a script that populates Key Vault after Terraform apply. ([GitHub][1])

Instead, eventually I'd make secret management explicit:

```text
Bootstrap
   |
   v
Key Vault
   |
   +-- django-secret-key
   +-- postgres-password
   +-- email-password
```

Then Container App references:

```text
keyVaultSecretId
```

rather than:

```text
value = var.secret
```

The Azure Container Apps Terraform resource supports Key Vault-backed secret references directly. ([Terraform Registry][8])

---

# 19. Recommended module responsibilities

I'd define the modules like this.

### `network`

```text
VNet
Application Gateway subnet
Container Apps subnet
PostgreSQL subnet
Private Endpoint subnet
```

### `nsg`

```text
Application Gateway NSG
Container Apps NSG
Private Endpoint NSG
PostgreSQL NSG
```

### `containerregistry`

```text
ACR
ACR SKU
ACR network access
```

### `identities`

```text
todo managed identity
cosmos CRUD managed identity
Application Gateway identity
```

### `keyvault`

```text
Key Vault
RBAC
Secret definitions/references
```

### `postgresql`

```text
PostgreSQL Flexible Server
Database
Private DNS
Networking
```

### `database`

```text
Cosmos Account
Database
Containers
Networking
```

### `containerapps`

```text
Container Apps Environment

Container App:
    django-todo

Container App:
    cosmos-crud
```

### `appgateway`

```text
Public IP
WAF
Frontend
HTTPS listener
Backend pools
Health probes
Path rules
```

### `privateendpoints`

```text
ACR PE
Key Vault PE
Cosmos PE
Private DNS zones
VNet links
```

### `monitoring`

```text
Log Analytics
Diagnostic settings
Application Insights
```

---

# 20. Recommended final network

```text
                           INTERNET
                              |
                              v
                   +---------------------+
                   | Application Gateway  |
                   |       WAF v2         |
                   +----------+----------+
                              |
                    +---------+---------+
                    |                   |
               /tasks/*          /cosmos_crud/*
                    |                   |
                    v                   v
          +----------------+   +----------------+
          | Container App  |   | Container App  |
          | Django Todo    |   | Cosmos CRUD    |
          +-------+--------+   +--------+-------+
                  |                     |
                  |                     |
                  v                     v
          +---------------+      +-------------+
          | PostgreSQL    |      | Cosmos DB   |
          | Flexible      |      |             |
          +---------------+      +-------------+

                  Container Apps Environment
                           |
             +-------------+-------------+
             |                           |
             v                           v
        +----------+                 +-------+
        | Key Vault|                 |  ACR  |
        +----------+                 +-------+
             ^                           ^
             |                           |
             +------ Managed Identity ---+
```

---

# 21. Environment structure

I would keep:

```text
dev
staging
prod
```

but each should have independent resources.

For example:

```text
DEV

ag-dev
cae-dev
ca-django-todo-dev
ca-cosmos-crud-dev
acr-dev
kv-dev
postgres-dev
cosmos-dev
```

Staging:

```text
ag-staging
cae-staging
ca-django-todo-staging
ca-cosmos-crud-staging
acr-staging
kv-staging
postgres-staging
cosmos-staging
```

Production:

```text
ag-prod
cae-prod
ca-django-todo-prod
ca-cosmos-crud-prod
acr-prod
kv-prod
postgres-prod
cosmos-prod
```

---

# 22. Terraform variables

I'd introduce something like:

```hcl
variable "todo_container_image" {
  type        = string
  description = "Django Todo container image"
}

variable "cosmos_crud_container_image" {
  type        = string
  description = "Cosmos CRUD container image"
}

variable "todo_container_port" {
  type    = number
  default = 8000
}

variable "cosmos_crud_container_port" {
  type    = number
  default = 8000
}
```

Then:

```hcl
todo_container_image = "myacr.azurecr.io/django-todo:8f2c9e1"

cosmos_crud_container_image = "myacr.azurecr.io/cosmos-crud:8f2c9e1"
```

---

# 23. Image naming

I'd use:

```text
<acr>.azurecr.io/
    django-todo:<git-sha>

<acr>.azurecr.io/
    cosmos-crud:<git-sha>
```

Example:

```text
mycompanydev.azurecr.io/django-todo:a81f9c2

mycompanydev.azurecr.io/cosmos-crud:a81f9c2
```

Don't use only:

```text
latest
```

because you lose easy rollback.

With immutable tags:

```text
v1
v2
v3
```

you can easily roll back:

```text
v3
 |
 X

v2
 |
 v
Container App
```

---

# 24. Deployment lifecycle

Your complete deployment should eventually look like this:

```text
Developer
    |
    v
GitHub
    |
    v
CI/CD
    |
    +--------------------------+
    |                          |
    v                          v
Terraform                 Application
Foundation                  Build
    |                          |
    v                          v
Azure Infrastructure       Docker Images
                               |
                               v
                              ACR
                               |
                               v
                         Terraform
                          Workloads
                               |
                  +------------+------------+
                  |                         |
                  v                         v
             Django Todo              Cosmos CRUD
                  |                         |
                  v                         v
             PostgreSQL                 Cosmos DB
```

---

# 25. Implementation phases I recommend

Don't modify everything at once.

## Phase 1 — Refactor current Container App

Change:

```text
1 Container App
```

to:

```text
2 Container Apps
```

with variables for:

```text
todo_image
cosmos_crud_image
```

---

## Phase 2 — Application Gateway routing

Implement:

```text
/tasks/*
```

and:

```text
/cosmos_crud/*
```

with two backend pools and health probes.

---

## Phase 3 — PostgreSQL

Make sure:

```text
Django Todo
      |
      v
PostgreSQL Flexible Server
```

works entirely through private networking.

---

## Phase 4 — Cosmos CRUD

Add:

```text
Cosmos CRUD
      |
      v
Cosmos DB
```

with its own identity and permissions.

---

## Phase 5 — Key Vault

Move:

```text
SECRET_KEY
POSTGRES_PASSWORD
EMAIL_HOST_PASSWORD
```

to Key Vault.

Then:

```text
Container App Managed Identity
              |
              v
          Key Vault
```

Azure's native Container Apps Key Vault integration is preferable to having your application itself call Key Vault just to retrieve ordinary application secrets. ([Microsoft Learn][6])

---

## Phase 6 — ACR bootstrap

Split deployment:

```text
terraform foundation
        ↓
ACR exists
        ↓
docker build
        ↓
docker push
        ↓
terraform workloads
```

This is the solution I recommend for your ACR/image dependency.

---

## Phase 7 — CI/CD

Finally automate:

```text
Terraform foundation
       ↓
Build Todo
       ↓
Build Cosmos CRUD
       ↓
Push ACR
       ↓
Terraform workloads
       ↓
Application Gateway
       ↓
Smoke tests
```

---

# 26. One important change to your existing architecture

Your current README says that after the first Terraform apply you push the real image to ACR and then re-apply Terraform. ([GitHub][1])

I would **remove that manual process**.

Instead, make the repository work like:

```text
FIRST DEPLOYMENT

Terraform Foundation
        ↓
ACR created
        ↓
CI/CD builds images
        ↓
Images pushed
        ↓
Terraform Workloads
        ↓
Applications live
```

And subsequent deployment:

```text
CODE CHANGE
    ↓
Docker build
    ↓
ACR
    ↓
Terraform workload update
    ↓
New Container App revision
    ↓
Health check
    ↓
Traffic
```

This gives you a much more production-ready architecture.

---

# 27. Final recommended repository design

I would aim for this:

```text
terraform_Architecture_Azure_Container_Apps/
│
├── environments/
│   ├── dev/
│   │   ├── foundation/
│   │   └── workloads/
│   │
│   ├── staging/
│   │   ├── foundation/
│   │   └── workloads/
│   │
│   └── prod/
│       ├── foundation/
│       └── workloads/
│
├── modules/
│   ├── network/
│   ├── nsg/
│   ├── appgateway/
│   ├── containerapps/
│   ├── containerregistry/
│   ├── identities/
│   ├── keyvault/
│   ├── postgresql/
│   ├── database/
│   ├── privateendpoints/
│   └── monitoring/
│
├── scripts/
│   ├── build-todo.sh
│   ├── build-cosmos-crud.sh
│   └── deploy.sh
│
└── README.md
```

### The key design decision

**Don't make Terraform responsible for building the Docker images.**

Use:

```text
Terraform → Azure infrastructure
CI/CD     → Docker build/push
Terraform → Container App deployment
```

That solves your **"ACR must exist before Container App, but image must exist before Container App"** problem cleanly.

Your existing repository is already quite close to this architecture, so I would **extend it rather than start over**. The current code already has the major modules and environment structure needed for the transition. ([GitHub][1])

If you want to proceed with implementation, the next useful step is to take your **actual Terraform repository files** and modify them module-by-module. If you upload the repository as a ZIP, I can inspect the current `main.tf`, `modules/containerapps`, `modules/appgateway`, `modules/keyvault`, `modules/postgresql`, and environment files and produce the **exact Terraform file changes**, including the two-stage ACR/image deployment.

[1]: https://github.com/jksonar/terraform_Architecture_Azure_Container_Apps "GitHub - jksonar/terraform_Architecture_Azure_Container_Apps: Architecture best practices for Azure Container Apps · GitHub"
[2]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway.html?utm_source=chatgpt.com "azurerm_application_gateway | Resources | hashicorp/azurerm | Terraform | Terraform Registry"
[3]: https://github.com/jksonar/terraform_Architecture_Azure_Container_Apps/tree/main/modules "terraform_Architecture_Azure_Container_Apps/modules at main · jksonar/terraform_Architecture_Azure_Container_Apps · GitHub"
[4]: https://github.com/jksonar/Django_todo_app "GitHub - jksonar/Django_todo_app · GitHub"
[5]: https://learn.microsoft.com/azure/postgresql/flexible-server/how-to-networking-servers-deployed-public-access-add-private-endpoint?utm_source=chatgpt.com "Add Private Endpoint Connections in Azure Database for PostgreSQL Flexible Server - Azure Database for PostgreSQL | Microsoft Learn"
[6]: https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets?utm_source=chatgpt.com "Manage secrets in Azure Container Apps | Microsoft Learn"
[7]: https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull?utm_source=chatgpt.com "Azure Container Apps image pull from Azure Container Registry with managed identity | Microsoft Learn"
[8]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app?utm_source=chatgpt.com "azurerm_container_app | Resources | hashicorp/azurerm | Terraform | Terraform Registry"

---
Question
if i want to use bash script to build image and push to azure container registry. 

Answer
Yes. In fact, I recommend using a **Bash script for Docker build + ACR push**, while keeping Terraform responsible for Azure infrastructure.

A clean flow would be:

```text
Terraform
   │
   ├── Create ACR
   ├── Create Key Vault
   ├── Create PostgreSQL
   ├── Create Cosmos DB
   ├── Create Container Apps Environment
   └── Create Managed Identities
             │
             ▼
       Bash deployment
             │
       ┌─────┴─────┐
       ▼           ▼
 Django Todo   Cosmos CRUD
       │           │
 docker build  docker build
       │           │
       └─────┬─────┘
             ▼
          ACR push
             │
             ▼
       Terraform Apply
             │
       ┌─────┴─────┐
       ▼           ▼
 /tasks       /cosmos_crud
```

## 1. Recommended Bash script

I would create:

```text
scripts/
└── build-and-push.sh
```

For example:

```bash
#!/usr/bin/env bash

set -euo pipefail

#######################################
# Configuration
#######################################

ACR_NAME="${ACR_NAME:?ACR_NAME is required}"
ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:?ACR_LOGIN_SERVER is required}"

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

TODO_IMAGE="${ACR_LOGIN_SERVER}/django-todo:${IMAGE_TAG}"
COSMOS_IMAGE="${ACR_LOGIN_SERVER}/cosmos-crud:${IMAGE_TAG}"

TODO_REPO="https://github.com/jksonar/Django_todo_app.git"
COSMOS_REPO="https://github.com/jksonar/<YOUR_COSMOS_CRUD_REPO>.git"

WORK_DIR="${WORK_DIR:-$(pwd)/.build}"

#######################################
# Functions
#######################################

log() {
    echo
    echo "========================================"
    echo "$1"
    echo "========================================"
}

#######################################
# Login to Azure
#######################################

log "Azure login"

az login

#######################################
# Login to ACR
#######################################

log "Logging into Azure Container Registry"

az acr login \
    --name "${ACR_NAME}"

#######################################
# Prepare build directory
#######################################

rm -rf "${WORK_DIR}"

mkdir -p "${WORK_DIR}"

#######################################
# Clone Django Todo
#######################################

log "Cloning Django Todo application"

git clone \
    --depth 1 \
    "${TODO_REPO}" \
    "${WORK_DIR}/django-todo"

#######################################
# Build Django Todo image
#######################################

log "Building Django Todo image"

docker build \
    -t "${TODO_IMAGE}" \
    "${WORK_DIR}/django-todo"

#######################################
# Push Django Todo image
#######################################

log "Pushing Django Todo image"

docker push "${TODO_IMAGE}"

#######################################
# Clone Cosmos CRUD
#######################################

log "Cloning Cosmos CRUD application"

git clone \
    --depth 1 \
    "${COSMOS_REPO}" \
    "${WORK_DIR}/cosmos-crud"

#######################################
# Build Cosmos CRUD image
#######################################

log "Building Cosmos CRUD image"

docker build \
    -t "${COSMOS_IMAGE}" \
    "${WORK_DIR}/cosmos-crud"

#######################################
# Push Cosmos CRUD image
#######################################

log "Pushing Cosmos CRUD image"

docker push "${COSMOS_IMAGE}"

#######################################
# Cleanup
#######################################

rm -rf "${WORK_DIR}"

log "Images successfully pushed"

echo "Todo image:"
echo "${TODO_IMAGE}"

echo

echo "Cosmos CRUD image:"
echo "${COSMOS_IMAGE}"
```

---

# 2. But I recommend a slightly different approach

If the Bash script is executed **from your CI/CD repository**, you don't need to clone both repositories every time.

For example:

```text
CI/CD
 |
 +-- checkout terraform repository
 |
 +-- clone Django Todo
 |
 +-- clone Cosmos CRUD
 |
 +-- build images
 |
 +-- push images
 |
 +-- terraform apply
```

Alternatively, if your pipeline already checks out both application repositories, the script can simply accept directories.

For example:

```bash
./scripts/build-and-push.sh \
    ./Django_todo_app \
    ./cosmos_crud
```

Then the script becomes reusable.

---

# 3. Better script design

I would actually create:

```text
scripts/
├── build-and-push.sh
├── build-image.sh
└── deploy.sh
```

### `build-image.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

APP_NAME="$1"
SOURCE_DIR="$2"
ACR_LOGIN_SERVER="$3"
IMAGE_TAG="$4"

IMAGE="${ACR_LOGIN_SERVER}/${APP_NAME}:${IMAGE_TAG}"

echo "Building ${IMAGE}"

docker build \
    -t "${IMAGE}" \
    "${SOURCE_DIR}"

echo "Pushing ${IMAGE}"

docker push "${IMAGE}"

echo "${IMAGE}"
```

Then:

```bash
./scripts/build-image.sh \
    django-todo \
    ./Django_todo_app \
    myacr.azurecr.io \
    8f2c9e1
```

and:

```bash
./scripts/build-image.sh \
    cosmos-crud \
    ./cosmos_crud \
    myacr.azurecr.io \
    8f2c9e1
```

---

# 4. Authentication to ACR

I recommend **not** doing:

```bash
docker login myacr.azurecr.io \
    -u username \
    -p password
```

Instead:

```bash
az login
az acr login --name myacr
```

`az acr login` uses your Azure identity and obtains an ACR authentication token.

For CI/CD, ideally use a **service principal, workload identity federation, or managed identity**, depending on where the pipeline runs.

For example:

```bash
az login \
    --service-principal \
    --username "$AZURE_CLIENT_ID" \
    --password "$AZURE_CLIENT_SECRET" \
    --tenant "$AZURE_TENANT_ID"
```

Then:

```bash
az acr login --name "$ACR_NAME"
```

The CI/CD identity should have:

```text
AcrPush
```

on the registry.

---

# 5. Image tag

I strongly recommend using the Git commit SHA.

For example:

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)
```

Then:

```text
myacr.azurecr.io/django-todo:91c4e72
myacr.azurecr.io/cosmos-crud:91c4e72
```

This gives you traceability:

```text
Git commit
    ↓
91c4e72
    ↓
Docker image
    ↓
Container App revision
```

You can always identify exactly which source code produced the running container.

---

# 6. Pass the image to Terraform

This is the important connection between your Bash script and Terraform.

After pushing:

```text
myacr.azurecr.io/django-todo:91c4e72
myacr.azurecr.io/cosmos-crud:91c4e72
```

run:

```bash
terraform apply \
  -var="todo_container_image=myacr.azurecr.io/django-todo:91c4e72" \
  -var="cosmos_crud_container_image=myacr.azurecr.io/cosmos-crud:91c4e72"
```

Your Terraform variables:

```hcl
variable "todo_container_image" {
  description = "Django Todo container image"
  type        = string
}

variable "cosmos_crud_container_image" {
  description = "Cosmos CRUD container image"
  type        = string
}
```

Then:

```hcl
resource "azurerm_container_app" "django_todo" {
  name                         = "ca-django-todo"
  container_app_environment_id = var.container_app_environment_id

  revision_mode = "Single"

  template {
    container {
      name   = "django-todo"
      image  = var.todo_container_image
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  # ...
}
```

And:

```hcl
resource "azurerm_container_app" "cosmos_crud" {
  name                         = "ca-cosmos-crud"
  container_app_environment_id = var.container_app_environment_id

  revision_mode = "Single"

  template {
    container {
      name   = "cosmos-crud"
      image  = var.cosmos_crud_container_image
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  # ...
}
```

---

# 7. Your complete deployment script

You could make the entire deployment:

```text
deploy.sh
```

like:

```bash
#!/usr/bin/env bash

set -euo pipefail

#######################################
# Configuration
#######################################

ACR_NAME="myacr"
ACR_LOGIN_SERVER="myacr.azurecr.io"

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

TODO_IMAGE="${ACR_LOGIN_SERVER}/django-todo:${IMAGE_TAG}"
COSMOS_IMAGE="${ACR_LOGIN_SERVER}/cosmos-crud:${IMAGE_TAG}"

#######################################
# Azure authentication
#######################################

echo "Logging into Azure..."

az login

echo "Logging into ACR..."

az acr login \
    --name "${ACR_NAME}"

#######################################
# Build Todo
#######################################

echo "Building Django Todo..."

docker build \
    -t "${TODO_IMAGE}" \
    ./Django_todo_app

docker push "${TODO_IMAGE}"

#######################################
# Build Cosmos CRUD
#######################################

echo "Building Cosmos CRUD..."

docker build \
    -t "${COSMOS_IMAGE}" \
    ./cosmos_crud

docker push "${COSMOS_IMAGE}"

#######################################
# Terraform
#######################################

echo "Deploying Container Apps..."

terraform apply \
    -auto-approve \
    -var="todo_container_image=${TODO_IMAGE}" \
    -var="cosmos_crud_container_image=${COSMOS_IMAGE}"

echo
echo "Deployment completed."
echo
echo "Todo:"
echo "${TODO_IMAGE}"
echo
echo "Cosmos CRUD:"
echo "${COSMOS_IMAGE}"
```

---

# 8. One thing I would change from my previous architecture

With this approach, you don't necessarily need two Terraform states.

You can use:

```text
Terraform
    ↓
Create ACR
    ↓
Bash
    ↓
Build + Push
    ↓
Terraform Apply
    ↓
Create/update Container Apps
```

**But there is a catch:** the first Terraform apply cannot create a Container App referencing an image that doesn't exist.

So for the **first deployment**, do:

```bash
terraform apply \
    -target=module.containerregistry
```

or, preferably, have your Terraform configuration explicitly separate foundation and workloads.

Then:

```text
1. terraform apply foundation
2. bash build-and-push.sh
3. terraform apply workloads
```

For subsequent deployments:

```text
1. bash build-and-push.sh
2. terraform apply workloads
```

That is the cleanest lifecycle.

---

# 9. Even better: Let Terraform output ACR information

Instead of hardcoding:

```bash
ACR_NAME="myacr"
ACR_LOGIN_SERVER="myacr.azurecr.io"
```

have Terraform output:

```hcl
output "acr_name" {
  value = module.containerregistry.name
}

output "acr_login_server" {
  value = module.containerregistry.login_server
}
```

Then Bash can do:

```bash
ACR_NAME=$(terraform output -raw acr_name)

ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
```

So:

```text
Terraform
    |
    +--> ACR name
    |
    +--> ACR login server
              |
              v
        Bash script
              |
        docker build
              |
        docker push
```

No duplicated configuration.

---

# 10. What I recommend for your project

Given your existing Terraform repository, I'd implement the deployment as:

```text
                    Git Push
                       |
                       v
              ┌─────────────────┐
              │ Terraform       │
              │ Foundation      │
              └────────┬────────┘
                       |
                       v
                     ACR
                       |
                       v
              ┌─────────────────┐
              │ Bash Script     │
              │                 │
              │ docker build    │
              │ docker push     │
              └────────┬────────┘
                       |
              ┌────────┴────────┐
              |                 |
              v                 v
        django-todo       cosmos-crud
              |                 |
              +--------+--------+
                       |
                       v
                     ACR
                       |
                       v
              Terraform Workload
                       |
             +---------+---------+
             |                   |
             v                   v
        Container App       Container App
        /tasks              /cosmos_crud
             |                   |
             v                   v
       PostgreSQL             Cosmos DB
```

And **Key Vault remains completely separate from the image build process**:

```text
                  Key Vault
                     |
                     | Managed Identity
                     |
                     v
              Django Todo
                     |
                     v
                PostgreSQL
```

This gives you a clean separation:

| Component           | Responsibility                      |
| ------------------- | ----------------------------------- |
| Terraform           | Azure infrastructure                |
| Bash                | Docker build + ACR push             |
| ACR                 | Container images                    |
| Container Apps      | Run containers                      |
| Application Gateway | `/tasks` and `/cosmos_crud` routing |
| Key Vault           | Django credentials/secrets          |
| Managed Identity    | Passwordless Azure authentication   |
| PostgreSQL          | Todo application DB                 |
| Cosmos DB           | CRUD application DB                 |
| CI/CD               | Orchestrate everything              |

**For your specific repository, I would next modify the existing Terraform so the first deployment is `foundation → Bash build/push → workload`, and then create the exact `build-and-push.sh`, `deploy.sh`, ACR outputs, Terraform variables, and Container App configuration around your current module structure.**

Question
i will not clone both repository because both will use this same repository like /Django_todo_app is.

Answer 
Exactly — if **both Django applications are directories inside the same Terraform repository**, you should not clone either application repository.

For example, your repository can be:

```text
terraform_Architecture_Azure_Container_Apps/
│
├── Django_todo_app/
│   ├── manage.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── ...
│
├── cosmos_crud/
│   ├── manage.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── ...
│
├── modules/
│   ├── containerapps/
│   ├── appgateway/
│   ├── containerregistry/
│   ├── keyvault/
│   ├── postgresql/
│   ├── cosmosdb/
│   └── ...
│
├── environments/
│   └── dev/
│
└── scripts/
    └── build-and-push.sh
```

Then your Bash script can simply use the local directories.

### `scripts/build-and-push.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

ACR_NAME="${ACR_NAME:?ACR_NAME is required}"

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

ACR_LOGIN_SERVER=$(az acr show \
    --name "$ACR_NAME" \
    --query loginServer \
    --output tsv)

TODO_IMAGE="${ACR_LOGIN_SERVER}/django-todo:${IMAGE_TAG}"
COSMOS_IMAGE="${ACR_LOGIN_SERVER}/cosmos-crud:${IMAGE_TAG}"

echo "=========================================="
echo "ACR:        ${ACR_LOGIN_SERVER}"
echo "Image Tag:  ${IMAGE_TAG}"
echo "=========================================="

echo "Logging into ACR..."

az acr login \
    --name "$ACR_NAME"

echo "=========================================="
echo "Building Django Todo"
echo "=========================================="

docker build \
    --tag "$TODO_IMAGE" \
    ./Django_todo_app

echo "Pushing ${TODO_IMAGE}"

docker push "$TODO_IMAGE"

echo "=========================================="
echo "Building Cosmos CRUD"
echo "=========================================="

docker build \
    --tag "$COSMOS_IMAGE" \
    ./cosmos_crud

echo "Pushing ${COSMOS_IMAGE}"

docker push "$COSMOS_IMAGE"

echo
echo "=========================================="
echo "Images pushed successfully"
echo "=========================================="
echo
echo "TODO_IMAGE=${TODO_IMAGE}"
echo "COSMOS_IMAGE=${COSMOS_IMAGE}"
```

Then run it from the repository root:

```bash
export ACR_NAME="myacrdev"

./scripts/build-and-push.sh
```

It will do:

```text
terraform_Architecture_Azure_Container_Apps/
│
├── Django_todo_app/
│       │
│       └── Dockerfile
│             ↓
│       docker build
│             ↓
│       myacrdev.azurecr.io/django-todo:<git-sha>
│             ↓
│       docker push
│
└── cosmos_crud/
        │
        └── Dockerfile
              ↓
        docker build
              ↓
        myacrdev.azurecr.io/cosmos-crud:<git-sha>
              ↓
        docker push
```

## I would make one more improvement

Since **the application code is inside the same repository**, your Git commit SHA is an excellent image tag.

For example:

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)
```

If commit is:

```text
a81f9c2
```

you get:

```text
myacrdev.azurecr.io/django-todo:a81f9c2
myacrdev.azurecr.io/cosmos-crud:a81f9c2
```

That gives you a very clean relationship:

```text
Git commit
    │
    ├── Django Todo Docker image
    │
    └── Cosmos CRUD Docker image
```

## Then Terraform gets the images

Your deployment can be:

```bash
# 1. Create Azure infrastructure including ACR
terraform apply

# 2. Build and push both applications
./scripts/build-and-push.sh

# 3. Deploy/update Container Apps
terraform apply \
  -var="todo_container_image=${TODO_IMAGE}" \
  -var="cosmos_crud_container_image=${COSMOS_IMAGE}"
```

However, I would **not make the first `terraform apply` try to create the Container Apps** because the images don't exist yet.

Instead:

```text
                    terraform apply
                         │
                         ▼
              ┌─────────────────────┐
              │ Azure Infrastructure │
              │                     │
              │ ACR                 │
              │ VNet                │
              │ App Gateway         │
              │ Key Vault           │
              │ PostgreSQL          │
              │ Cosmos DB           │
              │ Container App Env   │
              └──────────┬──────────┘
                         │
                         ▼
                  build-and-push.sh
                         │
                ┌────────┴────────┐
                ▼                 ▼
          Django Todo        Cosmos CRUD
                │                 │
                └────────┬────────┘
                         ▼
                        ACR
                         │
                         ▼
                  terraform apply
                         │
                ┌────────┴────────┐
                ▼                 ▼
          Container App      Container App
          /tasks             /cosmos_crud
```

This is especially clean because **your Terraform repository becomes the application repository as well**.

I would therefore change the plan from my previous answer to use:

```text
Django_todo_app/
cosmos_crud/
modules/
environments/
scripts/
```

with **no `git clone` inside the Bash script**.
