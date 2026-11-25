# infra — Azure storage (Terraform)

Private storage for raw images, masks and model artifacts, with the worksheet's retention policy:

- `<prefix><env>img` account: containers `raw-images` (hot 7 d → cool → delete after 30 d) and `masks` (hot, delete after 30 d).
- `<prefix><env>mdl` account: container `models`. Versioning and soft delete, **no lifecycle policy**.

Validate without credentials:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test          # mocked azurerm provider, checks retention rules and privacy flags
```

Example inputs: [`terraform.tfvars.example`](terraform.tfvars.example). Design, evidence, costs, deployment/cleanup commands, external dependencies and state/credentials: [tasks/cloud-infrastructure/EVIDENCE.md](../tasks/cloud-infrastructure/EVIDENCE.md).
