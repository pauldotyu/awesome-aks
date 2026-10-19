# Private AKS with API Server VNet Integration & Jumpbox

This demo deploys a secure, private Azure Kubernetes Service (AKS) cluster utilizing the **API Server VNet Integration** feature. This approach allows the AKS API server to be reachable within the virtual network without requiring a public IP or a traditional private endpoint setup.

To provide a management path into the private cluster, the deployment includes a Windows 11 jumpbox and Azure Bastion for secure, browser-based RDP access.

## Key Features

- **Private AKS Cluster**: No public API server endpoint.
- **API Server VNet Integration**: The API server is integrated directly into a dedicated subnet in the VNet.
- **Windows 11 Jumpbox**: A dedicated VM for running `kubectl` and managing the cluster.
- **Azure Bastion**: Secure RDP access to the jumpbox without exposing public IPs.
- **Modern Networking**: Azure CNI Overlay with Cilium for high-performance networking and security.
- **Security**: AAD RBAC enabled for cluster access control.

## Architecture

The infrastructure is deployed into a single VNet with the following subnet segmentation:

| Subnet | Purpose |
|----------|---------|
| `AzureBastionSubnet` | Hosts the Azure Bastion service. |
| `KubeApiServerSubnet` | Dedicated subnet for the AKS API Server VNet Integration. |
| `JumpBoxSubnet` | Hosts the Windows 11 management VM. |
| `NodesSubnet` | Hosts the AKS worker nodes. |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- An active Azure subscription with necessary permissions.

## Deployment

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Apply the configuration**:

   ```bash
   terraform apply
   ```

## How to Use

1. **Access the Jumpbox**:
   - Navigate to the **Azure Bastion** resource in the Azure Portal.
   - Connect to the Windows 11 VM via RDP using the browser.
2. **Manage the Cluster**:
   - Use the jumpbox to run `az aks get-credentials` and `kubectl` commands to manage your private cluster.
