variable "location" {
  description = "The Azure region to deploy resources in."
  type        = string
  default     = "brazilsouth"

  validation {
    condition = contains([
      "australiaeast",
      "brazilsouth",
      "canadacentral",
      "centralindia",
      "centralus",
      "eastus",
      "eastus2",
      "francecentral",
      "germanywestcentral",
      "idonesiacentral",
      "italynorth",
      "japaneast",
      "japanwest",
      "koreacentral",
      "koreasouth",
      "malaysiawest",
      "mexicocentral",
      "northcentralus",
      "northeurope",
      "norwayeast",
      "southafricanorth",
      "southcentralus",
      "southeastasia",
      "spaincentral",
      "swedencentral",
      "uawnorth",
      "uksouth",
      "westeurope",
      "westus2",
      "westus3",
    ], lower(var.location))
    error_message = "The location must be one of the supported Azure regions to deploy Azure Managed Lustre File System. Supported regions include: Australia East, Brazil South, Canada Central, Central India, Central US, East US, East US 2, France Central, Germany West Central, Indonesia Central, Italy North, Japan East, Japan West, Korea Central, Korea South, Malaysia West, Mexico Central, North Central US, North Europe, Norway East, South Africa North, South Central US, Southeast Asia, Spain Central, Sweden Central, UAE North, UK South, West Europe, West US 2 and West US 3."
  }
}