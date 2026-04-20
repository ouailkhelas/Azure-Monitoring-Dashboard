variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name for monitoring resources"
  type        = string
  default     = "rg-monitoring-prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "log_retention_days" {
  description = "Log Analytics retention period in days"
  type        = number
  default     = 30
}

variable "devops_email" {
  description = "Email address for DevOps team notifications"
  type        = string
}

variable "management_email" {
  description = "Email address for management notifications"
  type        = string
}

variable "devops_group_id" {
  description = "Azure AD Group ID for DevOps team"
  type        = string
}

variable "dev_group_id" {
  description = "Azure AD Group ID for Developers"
  type        = string
}

variable "monitored_vm_ids" {
  description = "List of VM Resource IDs to monitor"
  type        = list(string)
  default     = []
}

variable "monthly_budget" {
  description = "Monthly budget threshold in USD"
  type        = number
  default     = 5000
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
