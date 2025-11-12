# AKS Automatic with Azure Verified Modules (AVM)

This repository contains an example of deploying an AKS Automatic cluster using Azure Verified Modules (AVM). AKS Automatic simplifies the management of Kubernetes clusters by automating tasks such as scaling, updates, and maintenance. AVM provides pre-validated and secure infrastructure modules that can be used to deploy resources in Azure. Combining these two technologies allows for a streamlined and secure deployment of AKS Automatic clusters at enterprise scale.

## Prerequisites

- An Azure subscription
- Azure CLI
- Terraform CLI
- kubectl CLI

## Deployment Steps

1. **Clone the Repository**: Start by cloning this repository to your local machine.

   ```bash
   git clone ...
   cd 2025-11-06-aks-automatic-with-avm
   ```

2. **Configure Azure CLI**: Log in to your Azure account using the Azure CLI.

   ```bash
   az login
   ```

3. **Initialize Terraform**: Navigate to the directory containing the Terraform configuration files and initialize Terraform.

   ```bash
   terraform init
   ```

4. **Review and Modify Variables**: Review the `variables.tf` file and modify any variables as needed for your deployment.

5. **Plan the Deployment**: Run the Terraform plan command to see the resources that will be created.

   ```bash
   terraform plan
   ```

6. **Apply the Configuration**: Apply the Terraform configuration to deploy the AKS Automatic cluster.

   ```bash
   terraform apply
   ```

   When prompted, type `yes` to confirm the deployment.

7. **Verify the Deployment**: Once the deployment is complete, connect to the AKS Automatic cluster to verify that it is running correctly.

   ```bash
   az aks get-credentials --resource-group $rg_name --name $aks_name
   ```

You can then use `kubectl` to interact with your cluster.

## Cleanup

To delete the resources created by this deployment, run the following command:

```bash
terraform destroy
```

This will remove all resources defined in the Terraform configuration.

## Additional Resources

- [AKS Automatic Documentation](https://learn.microsoft.com/azure/aks/intro-aks-automatic)
- [Azure Verified Modules (AVM) Documentation](https://learn.microsoft.com/community/content/azure-verified-modules)
