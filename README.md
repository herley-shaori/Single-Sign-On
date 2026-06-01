# SSO — Terraform (Okta source → AWS + Azure + GCP)

Terraform configuration that wires up identity across clouds with
**Okta as the single source of truth**:

- **Okta** — users + groups, the authoritative source identity (`terraform/okta/shared`)
- **AWS IAM Identity Center** — receives users/groups from Okta (SCIM), then maps them to permission sets
- **Azure AD (Microsoft Entra ID)** — receives users/groups from Okta (downstream target)
- **Google Workspace / GCP** — receives users/groups from Okta (SCIM); GCP project IAM bindings reference those identities

> **Migration note:** Azure AD was previously the source of truth. It is being
> repositioned as a downstream **target** of Okta. The target-side modules
> (`terraform/aws`, `terraform/azure`, `terraform/gcp`) are left as-is for now;
> wiring them to consume Okta is follow-up work.

Layout: by provider, split by environment (`dev`, `prod`) with a tenant-level
`shared` folder for resources that are not per-environment.

---

## Layout

```
sso/
├── .gitignore
├── README.md
├── LICENSE
└── terraform/
    ├── apply.sh                # ./apply.sh   <aws|azure|gcp|okta> <dev|prod|shared>
    ├── destroy.sh              # ./destroy.sh <aws|azure|gcp|okta> <dev|prod|shared>
    ├── okta/
    │   └── shared/             # SOURCE OF TRUTH: users + groups (Okta management API)
    ├── aws/
    │   ├── dev/                # scaffolding only
    │   ├── prod/               # scaffolding only
    │   └── shared/             # IAM Identity Center: permission sets + group assignments
    ├── azure/
    │   ├── dev/                # sample blob storage smoke test
    │   ├── prod/               # scaffolding only
    │   └── shared/             # (legacy source; being repositioned as an Okta target)
    └── gcp/
        └── shared/             # project-level IAM bindings for the 'developers' role mapping
```

Terraform state is **local** (`terraform.tfstate` lives inside each leaf
folder).

---

## What is configured

### Okta — source of truth (`terraform/okta/shared`)

The authoritative directory. Users and groups are defined here and provisioned
**outward** to the downstream targets (AWS, Azure/Entra, GCP) through Okta's
provisioning integrations. The target modules consume these identities; they
do not define them.

- **Provider auth:** OAuth 2.0 service app with the `private_key_jwt` grant
  (no static API token). The org enforces **DPoP**; the `okta/okta` provider
  (v4.20+) handles the DPoP proof + nonce automatically.
- **Resource patterns** (commented examples in `main.tf`): `okta_user`
  (`first_name` + `last_name` + `login`/`email`, required by SCIM),
  `okta_group`, `okta_group_memberships`, and `okta_app_group_assignment` to
  put a group in scope for a downstream cloud's provisioning app.
- **Contract with targets** (keep stable so targets never depend on Okta
  internals): AWS keys off group **name**, GCP keys off user **email**, every
  user carries login/email + first/last name.

Credentials are never committed — see the [Okta credential setup](#4-okta--oauth-service-app-private_key_jwt-git-ignored-pem).

### Azure AD (`terraform/azure/shared`) — legacy source, repositioning as a target

Users, security groups, memberships and SSO assignments are defined
**directly as terraform resources** in `main.tf` (there is no external
`users.json`). The file ships with a live `developers` Microsoft 365
group plus commented examples for the other object types, ready to adapt.

Resource patterns:

- **User**: `azuread_user` with `given_name` + `surname` populated (required by SCIM provisioning to AWS) and a random initial password (`random_password`).
- **Security group**: `azuread_group` (security-enabled, mail-disabled).
- **Microsoft 365 (Unified) group**: `azuread_group` with `mail_enabled = true` + `types = ["Unified"]` — carries an email attribute.
- **Membership**: `azuread_group_member`.
- **SSO / provisioning assignment**: `azuread_app_role_assignment` to a target Enterprise Application, so its provisioning engine syncs the group + members to the downstream cloud. Two targets are wired up via data sources (no hardcoded SP object IDs):
  - **AWS IAM Identity Center** — assigned with its `User` app role (`var.enterprise_app_client_id`).
  - **Google Cloud / G Suite Connector by Microsoft** — assigned with its `Default Organization` app role (`var.gcp_provisioning_app_client_id`), provisioning the members into Google Workspace.

**Custom-domain email for a Unified group** is a manual post-step (Graph
cannot write group proxyAddresses; only Exchange Online can). Use the
helper:

```bash
terraform/azure/shared/set-group-email.sh <group-name> <email> [admin-upn]
# e.g. ./set-group-email.sh developers developers@yourdomain.tld
```

It opens an Exchange Online sign-in and runs `Set-UnifiedGroup
-PrimarySmtpAddress`. The change persists and is not terraform drift, but
must be re-run if the group is destroyed and recreated.

### AWS IAM Identity Center (`terraform/aws/shared`)

- **Permission sets**:
  - `developers` — `AmazonEC2FullAccess` attached
  - `data_scientists` — `AmazonS3FullAccess` attached
  - 8-hour session duration each
- **Account assignments**: both permission sets assigned to the SCIM-provisioned groups of the same name, scoped to the AWS account the configured profile resolves to. Override the target accounts via `var.target_account_ids` for multi-account setups.
- Identity Center instance + identity store are discovered via data sources (no hardcoded ARNs).

### Azure dev (`terraform/azure/dev`)

- Sample resource group + StorageV2 storage account + private blob container in `Southeast Asia`. Smoke test that SP credentials (ARM_* env vars) and the `azurerm` provider work end-to-end.

### GCP (`terraform/gcp/shared`)

- **IAM binding**: `roles/storage.admin` granted at the target GCP project (set via `var.gcp_project_id`) to every email in `var.developers_emails`.
- **No identity resources**: GCP terraform does NOT create Google users or groups — those come from Azure via the Google Workspace connector (SCIM). This module only manages *authorization* (project IAM bindings), referencing identities by email.
- The bindings sit inert in the project IAM policy until a matching Google identity exists; activation happens automatically once the identity is provisioned into Google Workspace.
- Keep `var.developers_emails` aligned with the membership of the Azure source group so the authorization list does not drift from the source of truth.

---

## Single source of truth pattern

Okta is the authoritative directory:

```
Okta users + groups   (terraform/okta/shared)
        │
        ├── SCIM / app assignment ──►  AWS IAM Identity Center
        │                                  └─ permission sets activate per assigned group
        │
        ├── SCIM / app assignment ──►  Azure AD (Entra)   [target wiring = follow-up]
        │
        └── SCIM / app assignment ──►  Google Workspace (users + groups)
                                           └─ identities then satisfy the IAM bindings in GCP
```

- Define a user/group in `terraform/okta/shared/main.tf` → `./apply.sh okta shared` → it lands in Okta → Okta provisions to each cloud whose app the group is assigned to (typically within minutes to ~40 min).
- Remove the resource → destroyed in Okta → Okta deprovisions (tombstones) downstream → access cuts off.
- A group only reaches a given cloud once it is assigned to that cloud's provisioning app in Okta (`okta_app_group_assignment`). An unassigned group is intentionally absent downstream.
- **Provisioning is one-directional** (Okta → downstream). Do not create or edit users/groups directly in AWS / Azure / Google: such objects are drift and may be overwritten or left orphaned. Identities created outside this flow (e.g. a native Google super-admin used for setup) are the only sanctioned exceptions.

---

## First-time setup

`*.tfvars` files are operator-specific and **git-ignored**. Templates are
tracked as `*.tfvars.example`. To set up a fresh checkout:

```bash
# AWS
cp terraform/aws/dev/terraform.tfvars.example    terraform/aws/dev/terraform.tfvars
cp terraform/aws/prod/terraform.tfvars.example   terraform/aws/prod/terraform.tfvars
cp terraform/aws/shared/terraform.tfvars.example terraform/aws/shared/terraform.tfvars

# Azure
cp terraform/azure/dev/terraform.tfvars.example    terraform/azure/dev/terraform.tfvars
cp terraform/azure/prod/terraform.tfvars.example   terraform/azure/prod/terraform.tfvars
cp terraform/azure/shared/terraform.tfvars.example terraform/azure/shared/terraform.tfvars

# GCP
cp terraform/gcp/shared/terraform.tfvars.example   terraform/gcp/shared/terraform.tfvars
# Plus drop your Google Workspace service account JSON at:
#   terraform/gcp/shared/sa.json
# (the file is git-ignored by multiple defense-in-depth patterns)

# Okta (source of truth)
cp terraform/okta/shared/terraform.tfvars.example  terraform/okta/shared/terraform.tfvars
# Plus drop the OAuth service-app private key (PEM, PKCS#8) at:
#   terraform/okta/shared/okta_api_key.pem
# (git-ignored by **/okta_api_key.pem, *.pem, *.key)
```

Then fill in the placeholders inside each copied file with your own values.

---

## Usage

```bash
cd terraform

# Okta (source of truth) - requires terraform/okta/shared/okta_api_key.pem
./apply.sh okta shared

# AWS - uses the AWS CLI profile from your tfvars
./apply.sh aws shared
./apply.sh aws dev

# Azure - requires ARM_* env vars (see Credentials section)
./apply.sh azure shared
./apply.sh azure dev

# GCP - requires terraform/gcp/shared/sa.json (the SA file is git-ignored)
./apply.sh gcp shared

# Destroy mirrors apply. Prod prompts for the literal 'destroy prod':
./destroy.sh azure prod
```

**Common workflows:**

- Add or modify a user / group / membership in the **source of truth**: edit `terraform/okta/shared/main.tf` (uncomment and adapt the example resources), then `./apply.sh okta shared`. Downstream clouds pick it up via provisioning.
- Add an AWS permission set: append an entry to `local.permission_sets` in `terraform/aws/shared/main.tf`. Each entry can target multiple managed policies and multiple groups.
- Add a developer to the GCP `developers` role: append the email to `developers_emails` in your local `terraform/gcp/shared/terraform.tfvars`.

---

## Credential setup

### 1. AWS — via a CLI profile

All AWS environments use an AWS CLI profile, configured locally in
`~/.aws/credentials` / `~/.aws/config`. The profile name lives in
each `aws_profile` entry inside `terraform/aws/<env>/terraform.tfvars`.

```bash
aws sts get-caller-identity --profile <your-aws-cli-profile>
```

### 2. Azure — Service Principal via env vars

**Hard rule:** the SP's `appId` / `password` / `tenant` MUST NOT be written
to any `.tf` / `.tfvars` / any tracked file.

```bash
export ARM_CLIENT_ID="<your-sp-appId>"
export ARM_CLIENT_SECRET="<your-sp-password>"
export ARM_TENANT_ID="<your-tenant-id>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
```

Subscription ID is not in the SP JSON — fetch it:

```bash
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" -t "$ARM_TENANT_ID"
az account list --output table
```

`apply.sh` / `destroy.sh` refuse to run for `azure` if any ARM_* var is missing.

### 3. GCP — service account JSON file (git-ignored)

The SA JSON lives at `terraform/gcp/shared/sa.json`. Multiple `.gitignore`
patterns (e.g. `**/sa.json`, `**/service-account.json`,
`**/*-credentials.json`) make it impossible to add accidentally via
`git add -A`.

`apply.sh` / `destroy.sh` refuse to run for `gcp` if `sa.json` is missing in
the target folder.

To rotate: replace the file in-place. To switch to Application Default
Credentials: drop the `credentials` field from the provider block and run
`gcloud auth application-default login --scopes='...admin.directory.user'`
signed in as a Workspace super admin.

### 4. Okta — OAuth service app, private_key_jwt (git-ignored PEM)

The Okta provider authenticates with an **OAuth 2.0 service app** using the
`private_key_jwt` grant — there is no static API token.

1. In Okta Admin, create an **API Services** app. Note its **Client ID** and
   your **org** (e.g. `trial-000000.okta.com` → org_name `trial-000000`,
   base_url `okta.com`).
2. Generate an RSA keypair and register the **public** key (JWK) on the app.
   Keep the **private** key as PEM (PKCS#8). Convert an OpenSSH key with:
   ```bash
   cp ~/.ssh/id_rsa terraform/okta/shared/okta_api_key.pem
   chmod 600 terraform/okta/shared/okta_api_key.pem
   ssh-keygen -p -N "" -m PKCS8 -f terraform/okta/shared/okta_api_key.pem
   ```
   The PEM lands at `terraform/okta/shared/okta_api_key.pem` and is git-ignored
   by `**/okta_api_key.pem`, `*.pem`, `*.key`. **Never commit it**; never inline
   the key into a `.tf`/`.tfvars` file.
3. **Grant API scopes** to the app (Applications → app → *Okta API Scopes*):
   `okta.users.manage` and `okta.groups.manage` (these include read). Without
   the grant, token requests fail with `consent_required`.
4. Non-secret identifiers (`okta_org_name`, `okta_base_url`, `okta_client_id`,
   `okta_scopes`) go in `terraform/okta/shared/terraform.tfvars` (git-ignored).

`apply.sh` / `destroy.sh` refuse to run for `okta` if `okta_api_key.pem` is
missing in the target folder. If your org enforces DPoP, no extra config is
needed — the provider handles the DPoP proof/nonce; otherwise leave the app's
DPoP setting as you wish.

---

## Required permissions (one-time setup per identity)

### Okta service app — granted API scopes

| Scope                  | Used for                                  |
|------------------------|-------------------------------------------|
| `okta.users.manage`    | create / update / deactivate users        |
| `okta.groups.manage`   | create groups, manage memberships         |

(The `.manage` scopes include read. Grant them under Applications → the app →
*Okta API Scopes*.)


### Azure SP — Microsoft Graph application permissions (admin-consented)

| Permission                          | Used for                                  |
|-------------------------------------|-------------------------------------------|
| `Application.Read.All`              | reading the target Enterprise App SP      |
| `User.ReadWrite.All`                | creating users                            |
| `Group.ReadWrite.All`               | creating groups and adding members        |
| `AppRoleAssignment.ReadWrite.All`   | assigning groups to the Enterprise App    |

### GCP SA

- **Project IAM Admin** (or **Owner**) on your target GCP project — to manage IAM bindings.
- **Workspace Domain-Wide Delegation** for the SA's client_id with scopes `https://www.googleapis.com/auth/admin.directory.user` (and `.group` / `.group.member` if you later add Workspace groups). Configured in Workspace Admin Console → Security → API controls → Domain-wide delegation.
- **APIs enabled** in the SA's project: `admin.googleapis.com`, `cloudresourcemanager.googleapis.com`.
- **Workspace super admin email** to impersonate (set in `terraform/gcp/shared/terraform.tfvars` as `impersonated_user_email`).

### AWS CLI

- The profile pointed to by `aws_profile` must resolve to an account that
  has Identity Center admin access (the management or delegated admin
  account).

---

## Hardening notes

- **Never** paste `export ARM_CLIENT_SECRET=...` into a shell whose history is recorded. Either prefix with a space (`HIST_IGNORE_SPACE` in zsh), source from a non-tracked file, or use a password manager / `direnv`.
- **Rotate** SP / SA credentials if they were ever shared in chat, screenshots, or third-party services — even if no tracked file in this repo contains them.
- **Consider Org Policy `iam.allowedPolicyMemberDomains`** on your GCP Organization — restricts IAM bindings to your tenant's own domains, so a typo in an email principal cannot accidentally grant access to a stranger.
- To move from local state to a remote backend, add a `backend` block to the relevant `versions.tf`, then run `terraform init -migrate-state`.
- AWS region default in the example tfvars is `ap-southeast-3` (Jakarta), an opt-in region — enable it per account or switch to a region that is enabled by default.
- `.terraform.lock.hcl` is intentionally committed so provider versions stay reproducible across applies.

---

## Branch / workflow

- Default branch: `master`.
- Commit messages are descriptive English; no AI-tool attribution trailers.
- Every commit run is preceded by a `git diff --cached | grep` scan for
  known-bad strings (private keys, SP secrets, generated passwords) so
  nothing sensitive lands in history.
- All operator-specific values (account IDs, domain names, project IDs,
  profile names, user emails) live only in git-ignored local files. The
  tracked configuration is fully generic and re-usable.
</content>
</invoke>