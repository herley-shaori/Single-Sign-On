# SSO — Terraform (AWS + Azure + GCP)

Terraform configuration that wires up identity across three clouds with
**Azure AD as the single source of truth**:

- **Azure AD (Microsoft Entra ID)** — users + security groups, source identity
- **AWS IAM Identity Center** — receives users/groups via Azure SCIM, then maps them to permission sets
- **Google Workspace** — receives users/groups via the Azure "Google Cloud / G Suite Connector" provisioning app (SCIM-style)
- **GCP** — project-scoped IAM bindings, referencing the same identities

Per cloud: split by environment (`dev`, `prod`) with a tenant-level
`shared` folder for resources that are not per-environment.

---

## Layout

```
sso/
├── .gitignore
├── README.md
├── LICENSE
└── terraform/
    ├── apply.sh                # ./apply.sh   <aws|azure|gcp> <dev|prod|shared>
    ├── destroy.sh              # ./destroy.sh <aws|azure|gcp> <dev|prod|shared>
    ├── aws/
    │   ├── dev/                # scaffolding only
    │   ├── prod/               # scaffolding only
    │   └── shared/             # IAM Identity Center: permission sets + group assignments
    ├── azure/
    │   ├── dev/                # sample blob storage smoke test
    │   ├── prod/               # scaffolding only
    │   └── shared/             # users + security groups + SSO app role assignments (defined directly in main.tf)
    └── gcp/
        └── shared/             # project-level IAM bindings for the 'developers' role mapping
```

Terraform state is **local** (`terraform.tfstate` lives inside each leaf
folder).

---

## What is configured

### Azure AD (`terraform/azure/shared`)

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

Azure AD is the authoritative directory:

```
Azure AD users + groups
        │
        ├── SCIM             ──►  AWS IAM Identity Center
        │                            └─ permission sets activate per assigned group
        │
        └── Google connector ──►  Google Workspace (users + groups)
                                     └─ identities then satisfy the IAM bindings in GCP
```

- Adding a user resource in `terraform/azure/shared/main.tf` (and `terraform apply azure shared`) → user lands in Azure AD → SCIM syncs to AWS within ~40 min → AWS permission set assignment activates.
- Removing the user resource → user destroyed in Azure AD → SCIM tombstones in AWS → all SSO access cuts off.
- **For Google**: provisioning runs through the Azure Enterprise App "Google Cloud / G Suite Connector by Microsoft". A group only syncs once it is assigned to that app (via `azuread_app_role_assignment`); members of an assigned group are created in Google Workspace, which in turn satisfies any matching GCP IAM binding. A group that is not assigned to the connector is intentionally absent from Google.
- **Provisioning is one-directional** (Azure → downstream). Do not create or edit users/groups directly in AWS or Google: such objects are drift and may be overwritten or left orphaned. Identities created outside this flow (e.g. a native Google super-admin used for setup) are the only sanctioned exceptions.

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
```

Then fill in the placeholders inside each copied file with your own values.

---

## Usage

```bash
cd terraform

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

- Add or modify an Azure AD user / group / membership / SSO assignment: edit `terraform/azure/shared/main.tf` directly (uncomment and adapt the example resources), then `./apply.sh azure shared`.
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

---

## Required permissions (one-time setup per identity)

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