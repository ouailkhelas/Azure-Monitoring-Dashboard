# Azure Monitoring Dashboard - Main Terraform Configuration
# Deploys Log Analytics, Alerts, Workbooks, and RBAC

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group
resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Monitoring"
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-${var.location}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  
  tags = azurerm_resource_group.monitoring.tags
}

# Action Group for DevOps Team
resource "azurerm_monitor_action_group" "devops" {
  name                = "ag-devops-team"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "devops"
  
  email_receiver {
    name          = "DevOps Team"
    email_address = var.devops_email
  }
  
  tags = azurerm_resource_group.monitoring.tags
}

# Action Group for Management
resource "azurerm_monitor_action_group" "management" {
  name                = "ag-management"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "mgmt"
  
  email_receiver {
    name          = "Management Team"
    email_address = var.management_email
  }
  
  tags = azurerm_resource_group.monitoring.tags
}

# VM CPU Alert
resource "azurerm_monitor_metric_alert" "vm_cpu_high" {
  name                = "alert-vm-cpu-high"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [var.monitored_vm_ids[0]]  # Example: first VM
  description         = "Alert when VM CPU exceeds 80% for 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.devops.id
  }
  
  tags = azurerm_resource_group.monitoring.tags
}

# VM Memory Alert
resource "azurerm_monitor_metric_alert" "vm_memory_high" {
  name                = "alert-vm-memory-high"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [var.monitored_vm_ids[0]]
  description         = "Alert when VM available memory is low"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT10M"
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824  # 1GB
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.devops.id
  }
  
  tags = azurerm_resource_group.monitoring.tags
}

# Budget Alert
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-monthly-threshold"
  subscription_id = var.subscription_id
  
  amount     = var.monthly_budget
  time_grain = "Monthly"
  
  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }
  
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"
    
    contact_emails = [
      var.devops_email,
      var.management_email
    ]
  }
  
  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"
    
    contact_emails = [
      var.management_email
    ]
  }
}

# RBAC: Monitoring Contributor for DevOps Group
resource "azurerm_role_assignment" "devops_monitoring_contributor" {
  scope                = azurerm_resource_group.monitoring.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = var.devops_group_id
}

# RBAC: Monitoring Reader for Developers
resource "azurerm_role_assignment" "dev_monitoring_reader" {
  scope                = azurerm_resource_group.monitoring.id
  role_definition_name = "Monitoring Reader"
  principal_id         = var.dev_group_id
}

# Custom Role Definition: Metric Alert Manager
resource "azurerm_role_definition" "metric_alert_manager" {
  name        = "Metric Alert Manager"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Can create and modify metric alerts but not delete"
  
  permissions {
    actions = [
      "Microsoft.Insights/metricAlerts/write",
      "Microsoft.Insights/metricAlerts/read",
      "Microsoft.Insights/actionGroups/read",
      "Microsoft.Insights/actionGroups/write"
    ]
    
    not_actions = [
      "Microsoft.Insights/metricAlerts/delete",
      "Microsoft.Insights/actionGroups/delete"
    ]
  }
  
  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

# Log Analytics Saved Queries
resource "azurerm_log_analytics_saved_search" "failed_backups" {
  name                       = "Failed Backups"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "Backup"
  display_name               = "Failed Backup Jobs (Last 24h)"
  
  query = <<QUERY
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Category == "AzureBackupReport"
| where OperationName == "Job" and JobOperation_s == "Backup"
| where JobStatus_s == "Failed"
| project TimeGenerated, Resource, JobStatus_s, JobFailureCode_s
| order by TimeGenerated desc
QUERY
}

resource "azurerm_log_analytics_saved_search" "high_cpu_vms" {
  name                       = "High CPU VMs"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "Performance"
  display_name               = "VMs with High CPU Usage"
  
  query = <<QUERY
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer
| where AvgCPU > 80
| order by AvgCPU desc
QUERY
}

resource "azurerm_log_analytics_saved_search" "failed_logins" {
  name                       = "Failed Logins"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "Security"
  display_name               = "Failed Login Attempts (Last Hour)"
  
  query = <<QUERY
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4625
| summarize FailedAttempts = count() by Account, Computer
| where FailedAttempts > 5
| order by FailedAttempts desc
QUERY
}

# Outputs
output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "Log Analytics Workspace Resource ID"
}

output "log_analytics_workspace_key" {
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
  description = "Log Analytics Workspace Primary Key"
}

output "devops_action_group_id" {
  value       = azurerm_monitor_action_group.devops.id
  description = "DevOps Action Group ID"
}

output "monitoring_resource_group" {
  value       = azurerm_resource_group.monitoring.name
  description = "Monitoring Resource Group Name"
}
