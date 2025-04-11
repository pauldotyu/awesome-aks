# Ubuntu Workstation

Terraform script to create an Ubuntu server virtual machine in Azure to be used as a workstation for development and testing. The VM can be configured to include any additional software or services as needed and will be installed at the time of provisioning using cloud-init. This particular virtual machine will include the following software:

- Azure CLI
- Terraform
- Docker Engine
- kubectl
- kit
- cog

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)

## Provisioning resources

1. Clone this repository
1. Change to this directory
1. Login to Azure using the Azure CLI
1. Run `export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)` to set the subscription ID
1. Run `terraform init` to initialize the Terraform configuration
1. Run `terraform apply` to create the resources. This will prompt you to confirm the changes. Type `yes` to proceed.

## Connecting to virtual machine

An Azure Network Security Group (NSG) is created to allow SSH access to the VM only from the IP address of the machine running the script. To authenticate, a new public/private key pair is generated and stored in Azure. The private key pem file is stored in the current directory and is meant to be ephemeral and will be deleted when as resources get deleted but should still be kept secure. 

To SSH into the VM, use the following command:

```bash
ssh -i $(terraform output -raw ssh_private_key) $(terraform output -raw ssh_username)@$(terraform output -raw public_ip)
```

You could also SSH into the VM from VSCode using the [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension. To do this, add the following to your SSH config file:

```text
# ~/.ssh/config
Host <replace_this_with_public_ip>
    HostName <replace_this_with_public_ip>
    User <replace_this_with_ssh_username>
    IdentityFile <replace_this_with_path_to_private_key>
```

Then, you can connect to the VM from VSCode by selecting the host from the Remote - SSH extension.

