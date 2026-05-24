# SSO — Terraform (AWS + Azure)

Terraform configuration for AWS IAM Identity Center and Azure Entra ID,
split by environment (`dev`, `prod`) and with a tenant-level `shared`
folder for Azure resources that are not per-environment.

> Current status: the `aws/` folders are scaffolding only (provider +
> variables + placeholder `main.tf`). The Azure work is live:
> `azure/dev/` provisions a sample blob storage; `azure/shared/` manages
> Azure AD users, groups and Enterprise Application SSO assignments.

---

## Layout

```
sso/
├── .gitignore
├── README.md
└── terraform/
    ├── apply.sh                # ./apply.sh   <aws|azure> <dev|prod|shared>
    ├── destroy.sh              # ./destroy.sh <aws|azure> <dev|prod|shared>
    ├── aws/
    │   ├── dev/                # scaffolding only
    │   └── prod/               # scaffolding only
    └── azure/
        ├── dev/                # sample blob storage
        ├── prod/               # scaffolding only
        └── shared/             # users, groups, SSO assignments (tenant-wide)
```

Terraform state is **local** (`terraform.tfstate` lives inside each leaf
folder).

---

## Usage

```bash
cd terraform

./apply.sh   aws   dev          # init + validate + plan + apply
./apply.sh   azure shared
./destroy.sh azure dev
./destroy.sh azure prod         # will prompt for the string 'destroy prod'
```

Adding or modifying Azure users: edit
`terraform/azure/shared/users.json`, then run
`./apply.sh azure shared`.

Adding a new Azure security group: append its display name to
`local.managed_groups` in `terraform/azure/shared/main.tf`. Every group
listed there is automatically created in Azure AD and assigned to the SSO
Enterprise Application target, so its members get provisioned to AWS via
SCIM.

---

## Credential setup on this laptop

### 1. AWS — via the `pribadi` profile

Both environments (`dev` and `prod`) use the same AWS CLI profile,
**`pribadi`**, which is already configured locally
(see `~/.aws/credentials` / `~/.aws/config`).

Verify:

```bash
aws sts get-caller-identity --profile pribadi
```

To use a different profile, change the `aws_profile` value in:

- `terraform/aws/dev/terraform.tfvars`
- `terraform/aws/prod/terraform.tfvars`

To switch to SSO instead, run `aws configure sso`, give it a profile
name, then update `aws_profile` in the tfvars file accordingly.

---

### 2. Azure — via Service Principal (env vars only, NEVER files)

**Hard rule:** the SP's `appId` / `password` / `tenant` MUST NOT be
written to any `.tf` / `.tfvars` file or any file that gets committed.

Export the four variables in your shell every session (or source them
from a file outside this repo, or a password manager, or a `direnv`
`.envrc` that is itself ignored):

```bash
export ARM_CLIENT_ID="<appId from your SP JSON>"
export ARM_CLIENT_SECRET="<password from your SP JSON>"
export ARM_TENANT_ID="<tenant from your SP JSON>"
export ARM_SUBSCRIPTION_ID="<see step below>"
```

The SP JSON does not contain a subscription_id, so fetch it via `az`:

```bash
az login --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant   "$ARM_TENANT_ID"

az account list --output table
# pick the SubscriptionId you want and export it as ARM_SUBSCRIPTION_ID
```

Sanity check the env vars are set:

```bash
env | grep '^ARM_' | sed 's/=.*$/=***SET***/'
# should print four lines
```

Run:

```bash
cd terraform
./apply.sh azure shared
```

If any ARM_* env var is missing, the script refuses to run and prints a
clear message instead of silently failing.

---

### Required Microsoft Graph permissions for the SP

`azure/shared` needs the SP to have these Microsoft Graph **Application**
permissions, with admin consent granted:

| Permission                          | Used for                                       |
|-------------------------------------|------------------------------------------------|
| `Application.Read.All`              | reading the target Enterprise App SP           |
| `User.ReadWrite.All`                | creating users                                 |
| `Group.ReadWrite.All`               | creating groups and adding members             |
| `AppRoleAssignment.ReadWrite.All`   | assigning groups to the Enterprise App         |

Grant via Azure Portal (App registrations → API permissions →
Add → Microsoft Graph → Application permissions → Grant admin consent),
or via `az ad app permission add` + `az ad app permission admin-consent`.

---

## Hardening notes

- **Never** paste `export ARM_CLIENT_SECRET=...` into a shell whose
  history is recorded as-is. Either prefix the command with a space
  (`HIST_IGNORE_SPACE` in zsh), or source it from a non-tracked file, or
  use a password manager / `direnv`.
- **Rotate** the SP `appId` / `password` if they were ever shared in
  chat, screenshots, or third-party services — even if no tracked file
  in this repo contains them.
- To move from local state to a remote backend, add a `backend "s3"` or
  `backend "azurerm"` block to the relevant `versions.tf`, then run
  `terraform init -migrate-state`.
- AWS region default is `ap-southeast-3` (Jakarta), which is an
  opt-in region — make sure it is enabled in your account
  (Console → Account → AWS Regions).
