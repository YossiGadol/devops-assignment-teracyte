terraform {
  # optional() defaults in object types and cross-variable validation need >= 1.9.
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.x creates containers through Azure Resource Manager (storage_account_id), so apply works
      # with shared keys disabled and the public endpoint closed.
      version = "~> 4.0"
    }
  }

  # No backend block on purpose: CI and reviewers run `terraform init -backend=false`.
  # Production adds a remote azurerm backend at init time (-backend-config); see
  # tasks/cloud-infrastructure/EVIDENCE.md, "Credentials, shared state and locking".
}
