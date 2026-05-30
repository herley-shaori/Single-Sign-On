# SSO — Terraform (AWS + Azure + GCP)

Terraform configuration that wires up identity across three clouds with
**Azure AD as the single source of truth**:

- **Azure AD (Microsoft Entra ID)** — users + security groups, source identity
- **AWS IAM Identity Center** — receives users/groups via Azure SCIM, then maps them to permission sets
- **GCP** — project-scoped IAM bindings, referencing the same identities

Per cloud: split by environment (`dev`, `prod`) with a tenant-level
`shared` folder for resources that are not per-environment.

---

## Layout

```
sso/
├── .gitignore
├── README.md
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
    │   └── shared/             # users (driven by users.json) + security groups + SSO app role assignments
    └── gcp/
        └── shared/             # project-level IAM bindings for the 'developers' role mapping
```

Terraform state is **local** (`terraform.tfstate` lives inside each leaf
folder).

---

## What is configured today

### Azure AD (`terraform/azure/shared`)

- **Users**: `alice`, `bob`, `charlie` — all under `@catatancloud.dev`. Driven by `users.json`; every user has `given_name` + `surname` populated (required by SCIM provisioning to AWS).
- **Security groups**: `developers`, `data_scientists` (mail-disabled).
- **Memberships**: alice → `data_scientists`, bob → `developers`. charlie has no group.
- **Initial passwords**: random per user, exposed as a sensitive map output (`user_initial_passwords`).
- **SSO assignment**: each managed group is assigned to the AWS IAM Identity Center enterprise app's `User` app role, so SCIM provisions users + group membership to AWS.

### AWS IAM Identity Center (`terraform/aws/shared`)

- **Permission sets**:
  - `developers` — `AmazonEC2FullAccess` attached
  - `data_scientists` — `AmazonS3FullAccess` attached
  - 8-hour session duration each
- **Account assignments**: both permission sets assigned to the SCIM-provisioned groups of the same name, scoped to the AWS account the configured profile resolves to (`var.target_account_ids` overrides).
- Identity Center instance + identity store are discovered via data sources (no hardcoded ARNs).

### Azure dev (`terraform/azure/dev`)

- Sample resource group + StorageV2 storage account + private blob container in `Southeast Asia`. Smoke test that SP credentials (ARM_* env vars) and the `azurerm` provider work end-to-end.

### GCP (`terraform/gcp/shared`)

- **IAM binding**: `roles/storage.admin` granted at project `terraform-access-497602` to the members of `local.developers_emails` (currently `damian@catatancloud.dev` and `bob@catatancloud.dev`).
- **No user resources**: GCP terraform does NOT create users. The bindings sit inert in the project IAM policy until a matching Google identity exists; activation happens automatically once the user appears in Google (via SCIM or manual create).

---

## Single source of truth pattern

Azure AD is the authoritative directory:

```
Azure AD users + groups
        │
        ├── SCIM (configured)        ──►  AWS IAM Identity Center
        │                                    └─ permission sets activate per group
        │
        └── SCIM (NOT configured yet) ──►  Google Workspace
                                             └─ would activate the IAM bindings already in GCP
```

- Adding a user in `users.json` (and `terraform apply azure shared`) → user lands in Azure AD → SCIM syncs to AWS within ~40 min → AWS permission set assignment activates.
- Removing a user from `users.json` → user destroyed in Azure AD → SCIM tombstones in AWS → all SSO access cuts off.
- **For Google**: setup of an Azure AD Enterprise App "Google Cloud / G Suite Connector by Microsoft" with provisioning enabled is required for users to appear in Google Workspace automatically. Until that is wired up, no one (Damian or Bob) can actually log in to GCP even though their IAM bindings exist.

---

## Usage

```bash
cd terraform

# AWS - uses the 'pribadi' AWS CLI profile
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

- Add or modify an Azure AD user: edit `terraform/azure/shared/users.json`, then `./apply.sh azure shared`.
- Add a new Azure security group: append it to `local.managed_groups` in `terraform/azure/shared/main.tf`. Every group there is auto-created in Azure AD and SSO-assigned to AWS.
- Add an AWS permission set: append an entry to `local.permission_sets` in `terraform/aws/shared/main.tf`. Each entry can target multiple managed policies and multiple groups.
- Add a developer to the GCP `developers` role: append the email to `local.developers_emails` in `terraform/gcp/shared/main.tf`.

---

## Credential setup on this laptop

### 1. AWS — via the `pribadi` profile

All AWS environments use the AWS CLI profile **`pribadi`**, configured
locally in `~/.aws/credentials` / `~/.aws/config`.

```bash
aws sts get-caller-identity --profile pribadi
```

To switch profiles, edit `aws_profile` in `terraform/aws/<env>/terraform.tfvars`.

### 2. Azure — Service Principal via env vars

**Hard rule:** SP `appId` / `password` / `tenant` MUST NOT be written to
any `.tf` / `.tfvars` / any tracked file.

```bash
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

Subscription ID is not in the SP JSON — fetch it:

```bash
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" -t "$ARM_TENANT_ID"
az account list --output table
```

`apply.sh` / `destroy.sh` refuse to run for `azure` if any ARM_* var is
missing.

### 3. GCP — service account JSON file (git-ignored)

The SA JSON lives at `terraform/gcp/shared/sa.json`. Multiple
`.gitignore` patterns (e.g. `**/sa.json`, `**/service-account.json`,
`**/*-credentials.json`) make it impossible to add accidentally via
`git add -A`.

`apply.sh` / `destroy.sh` refuse to run for `gcp` if `sa.json` is
missing in the target folder.

To rotate: replace the file in-place. To switch to ADC: set the
provider's `credentials` field to omit `file(...)`, then run
`gcloud auth application-default login --scopes='...admin.directory.user'`
signed in as a Workspace super admin.

---

## Required permissions (one-time setup per identity)

### Azure SP (Microsoft Graph application permissions, admin-consented)

| Permission                          | Used for                                  |
|-------------------------------------|-------------------------------------------|
| `Application.Read.All`              | reading the target Enterprise App SP      |
| `User.ReadWrite.All`                | creating users                            |
| `Group.ReadWrite.All`               | creating groups and adding members        |
| `AppRoleAssignment.ReadWrite.All`   | assigning groups to the Enterprise App    |

### GCP SA

- **Project IAM Admin** (or **Owner**) on `terraform-access-497602` — to manage IAM bindings.
- **Workspace Domain-Wide Delegation** for the SA's client_id with scopes `https://www.googleapis.com/auth/admin.directory.user` (and `.group` / `.group.member` if you later add Workspace groups). Configured in Workspace Admin Console → Security → API controls → Domain-wide delegation.
- **APIs enabled** in the SA's project: `admin.googleapis.com`, `cloudresourcemanager.googleapis.com`.
- **Workspace super admin email** to impersonate (set in `terraform/gcp/shared/terraform.tfvars` as `impersonated_user_email`).

### AWS CLI

- The `pribadi` profile must point to an account that has Identity
  Center admin access (the management or delegated admin account).

---

## Hardening notes

- **Never** paste `export ARM_CLIENT_SECRET=...` into a shell whose
  history is recorded. Either prefix with a space (`HIST_IGNORE_SPACE`
  in zsh), source from a non-tracked file, or use a password manager /
  `direnv`.
- **Rotate** SP / SA credentials if they were ever shared in chat,
  screenshots, or third-party services — even if no tracked file in
  this repo contains them.
- **Consider Org Policy `iam.allowedPolicyMemberDomains`** on the GCP
  `catatancloud.dev` organization — restricts IAM bindings to the
  tenant's own domains, so a typo in an email principal cannot
  accidentally grant access to a stranger.
- To move from local state to a remote backend, add a `backend` block
  to the relevant `versions.tf`, then run
  `terraform init -migrate-state`.
- AWS region default is `ap-southeast-3` (Jakarta), an opt-in region —
  enable it per account.
- `.terraform.lock.hcl` is intentionally committed so provider versions
  stay reproducible across applies.

---

## Branch / workflow

- Default branch: `master`. No remote set; commits live locally.
- Commit messages are descriptive English; no Anthropic / Claude / AI
  attribution trailers.
- Every commit run is preceded by a `git diff --cached | grep` scan for
  known-bad strings (private keys, SP secrets, generated passwords) so
  nothing sensitive lands in history.
</content>
</invoke>