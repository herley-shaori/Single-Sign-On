# SSO — Terraform (AWS + Azure)

Scaffolding Terraform untuk mengelola **AWS IAM Identity Center** dan **Azure Entra ID** dengan pemisahan environment `dev` dan `prod`.

> Status saat ini: **scaffolding** (provider + variables + placeholder). Resource SSO asli ditambahkan menyusul di `main.tf` masing-masing folder env.

---

## Struktur

```
sso/
├── .gitignore
├── README.md
└── terraform/
    ├── apply.sh                # ./apply.sh <aws|azure> <dev|prod>
    ├── destroy.sh              # ./destroy.sh <aws|azure> <dev|prod>
    ├── aws/
    │   ├── dev/
    │   │   ├── versions.tf
    │   │   ├── providers.tf
    │   │   ├── variables.tf
    │   │   ├── terraform.tfvars
    │   │   ├── main.tf
    │   │   └── outputs.tf
    │   └── prod/   (struktur sama)
    └── azure/
        ├── dev/    (struktur sama)
        └── prod/   (struktur sama)
```

State Terraform: **local** (file `terraform.tfstate` ada di tiap folder env).

---

## Cara pakai (singkat)

```bash
cd terraform
./apply.sh   aws   dev      # init + validate + plan + apply
./apply.sh   azure prod
./destroy.sh aws   dev
./destroy.sh azure prod     # akan minta ketik 'destroy prod' untuk konfirmasi
```

---

## Setup credentials di laptop

### 1. AWS — via AWS IAM Identity Center (SSO)

Pakai `aws configure sso` (tidak perlu access key statis).

```bash
aws configure sso
```

Isi prompt-nya seperti berikut (sesuaikan dengan org-mu):

| Field | Contoh |
|---|---|
| SSO session name | `my-org` |
| SSO start URL | `https://<org>.awsapps.com/start` |
| SSO region | `ap-southeast-3` (atau region SSO yang dipakai org) |
| SSO registration scopes | `sso:account:access` (default) |
| CLI default client Region | `ap-southeast-3` |
| CLI default output format | `json` |
| **CLI profile name** | `sso-dev`  ← **harus cocok** dengan `aws_profile` di `terraform.tfvars` |

Ulangi untuk profile `sso-prod` (pilih akun PROD pas prompt account selection).

Login & verifikasi:

```bash
aws sso login --profile sso-dev
aws sts get-caller-identity --profile sso-dev

aws sso login --profile sso-prod
aws sts get-caller-identity --profile sso-prod
```

Setelah ini, `./apply.sh aws dev` langsung jalan karena provider AWS membaca profile dari `terraform.tfvars`.

> Mau pakai nama profile lain? Edit `terraform/aws/{dev,prod}/terraform.tfvars` di field `aws_profile`.

---

### 2. Azure — via Service Principal (env vars, BUKAN file)

**Aturan keras: nilai `appId` / `password` / `tenant` TIDAK BOLEH ditulis di file `.tf` / `.tfvars` / file lain yang di-commit.**

Set sebagai environment variable di shell-mu. Contoh, masukkan ke `~/.zshrc.local` (file yang **tidak** di-commit) atau pakai password manager / `direnv` dengan `.envrc` yang juga di-ignore:

```bash
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

Verifikasi dengan Azure CLI (login sekali untuk dapat subscription_id):

```bash
az login --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant   "$ARM_TENANT_ID"

az account show
az account list --output table
# Set subscription aktif (kalau punya >1):
az account set --subscription "$ARM_SUBSCRIPTION_ID"
```

Provider `azuread` & `azurerm` otomatis membaca semua `ARM_*` env vars di atas. Script `apply.sh` & `destroy.sh` akan **menolak jalan** kalau salah satu env var Azure belum di-set.

> Subscription ID tidak ada di JSON SP yang kamu punya. Ambil dengan `az account list --output table` setelah `az login`.

---

## Hardening / catatan

- `.terraform.lock.hcl` **sengaja di-commit** (kunci versi provider).
- File `*.tfstate` selalu di-ignore. Local state ada di laptopmu — back up sendiri kalau perlu.
- Pindah ke remote state (S3 / Azure Storage) bisa kapan saja: tinggal tambah block `backend` di `versions.tf`.
- Region AWS default `ap-southeast-3` (Jakarta) — region ini **opt-in**, pastikan sudah di-enable di akun (Console → Account → AWS Regions).
