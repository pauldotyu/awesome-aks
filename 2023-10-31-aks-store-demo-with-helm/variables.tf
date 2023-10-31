variable "location" {
  description = "value of azure region"
  type        = string
  default     = "westeurope"
}

variable "ai_location" {
  description = "value of azure region for deploying azure ai service"
  type        = string
  default     = "westeurope"
}

variable "openai_model_name" {
  description = "value of azure openai model name"
  type        = string
  default     = "gpt-35-turbo"
}
variable "openai_model_version" {
  description = "value of azure openai model version"
  type        = string
  default     = "0301"
}

variable "openai_model_capacity" {
  description = "value of azure openai model capacity"
  type        = number
  default     = 120
}

variable "k8s_namespace" {
  description = "value of kubernetes namespace"
  type        = string
  default     = "dev"
}