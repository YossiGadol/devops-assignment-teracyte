provider "azurerm" {
  features {
    storage {
      # Accounts default to private-endpoint-only. Stop the provider from calling blob/queue/file
      # endpoints during plan/apply, so a runner outside the VNet can still manage them over ARM.
      data_plane_available = false
    }
  }

  # No credentials here. The provider reads them from the environment: `az login` locally, or
  # ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID with ARM_USE_OIDC=true in CI
  # (workload identity federation, no client secret).
  subscription_id = var.subscription_id

  # Shared keys are disabled on the accounts, so any data-plane call must use Entra ID.
  storage_use_azuread = true
}
