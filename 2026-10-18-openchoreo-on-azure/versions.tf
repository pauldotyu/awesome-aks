terraform {
  required_version = ">= 1.10.0"

  required_providers {
    # Pin to the same provider generations the most recent examples in this
    # repo use (see 2026-08-08-follow-the-brick-road and 2026-07-14-gpu-profiling)
    # so we do not blindly upgrade or rewrite unrelated examples.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.1"
    }

    # Imperative cluster steps (Gateway API CRDs, applying cert-manager/ESO
    # manifests, the OpenChoreo control-plane install, and DNS A-records once the
    # LoadBalancer IP is known). Matches the null_resource/local-exec pattern
    # used in 2023-10-19-build-ai-day-london, using the newer terraform_data
    # type.
    #
    # NOTE: the Kubernetes provider is deliberately NOT used. It needs a live
    # cluster connection at plan time, but the AKS cluster is created by this
    # same apply, so every kubernetes_* resource would fail to plan on a fresh
    # run. The kubectl + local-exec pattern below avoids that chicken-and-egg.
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}
