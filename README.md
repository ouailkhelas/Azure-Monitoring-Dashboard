# Azure Monitoring Dashboard with RBAC

**Enterprise monitoring solution with role-based access control and automated alerting**

## Overview

Complete monitoring infrastructure solution combining **Terraform infrastructure-as-code with Azure Portal configuration**. Deploys Azure Monitor workbooks, metric alerts, Log Analytics queries, and RBAC governance for enterprise Azure environments.

**Real-world result:** Reduced mean time to detection from 35 minutes to 12 minutes (60% improvement) for SaaS platform with 30+ resources.

### Implementation Approach
- **Infrastructure Deployment**: Terraform for repeatable infrastructure
- **Configuration & Tuning**: Azure Portal for dashboards, KQL queries, alert thresholds
- **RBAC Management**: Combination of Terraform and Portal for role assignments
- **Monitoring & Adjustments**: Portal-based ongoing management

## Features

### 📊 **Custom Dashboards**
- Pre-built Azure Monitor workbook tracking 45+ key metrics
- Real-time visualization across VMs, databases, storage, networking
- Resource health overview with drill-down capabilities
- Cost tracking integrated with performance metrics

### 🔔 **Intelligent Alerting**
- CPU utilization > 80% (5-minute evaluation)
- Memory pressure > 85% (10-minute evaluation)
- Disk space < 15% free
- Failed backup detection
- Budget threshold alerts (80%, 90%, 100%)
- Network connectivity failures
- Application Gateway unhealthy backends

### 🔐 **RBAC Governance**
- **Monitoring Contributor**: DevOps teams (configure alerts, no delete)
- **Monitoring Reader**: Developers and management (view-only dashboards)
- **Backup Contributor**: Dedicated backup admins
- **Custom Roles**: Least-privilege access with specific metric namespaces
- Audit trail for all configuration changes

### 📝 **Log Analytics**
- Custom KQL queries for troubleshooting
- Failed login attempts tracking
- Performance bottleneck identification
- Security event correlation
- Backup verification queries

### 📧 **Automated Reporting**
- Weekly backup health reports via email
- Monthly cost and performance summary
- Incident runbooks with response procedures
- Compliance reporting for audits

## Quick Start

### Prerequisites

- Azure subscription with Contributor access
- Terraform 1.0+
- Azure CLI 2.30+
- PowerShell 7.0+ (for scripts)

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/azure-monitoring-dashboard.git
cd azure-monitoring-dashboard

# Login to Azure
az login

# Initialize Terraform
cd terraform
terraform init

# Review deployment plan
terraform plan -var="subscription_id=YOUR_SUB_ID"

# Deploy infrastructure
terraform apply -var="subscription_id=YOUR_SUB_ID"
```

### Deploy with PowerShell

```powershell
# Connect to Azure
Connect-AzAccount

# Deploy monitoring solution
.\scripts\Deploy-MonitoringSolution.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-monitoring"
```

## Architecture

### Components Deployed

1. **Log Analytics Workspace**
   - 30-day retention for operational data
   - 90-day retention for compliance logs
   - Diagnostic settings auto-configured

2. **Azure Monitor Workbooks** (3 pre-built)
   - VM Performance Dashboard
   - Network Health Overview
   - Cost & Resource Tracking

3. **Metric Alerts** (10 critical alerts)
   - VM CPU/Memory/Disk
   - Backup failures
   - Budget thresholds
   - Application Gateway health

4. **Action Groups**
   - Email notifications to teams
   - Webhook integrations for ticketing
   - SMS for critical alerts (optional)

5. **RBAC Roles**
   - Monitoring Contributor assignments
   - Monitoring Reader assignments
   - Custom role definitions

## RBAC Implementation

### Role Matrix

| Role | Permissions | Typical Users |
|------|-------------|---------------|
| **Monitoring Contributor** | Create/edit alerts, workbooks, queries | DevOps, SRE teams |
| **Monitoring Reader** | View dashboards and metrics | Developers, managers |
| **Backup Contributor** | Manage backup policies | Backup admins |
| **Custom: Metric Alert Manager** | Alert config only, no delete | Junior DevOps |

### Assign RBAC Roles

```powershell
# Assign Monitoring Contributor to DevOps team
.\scripts\Set-MonitoringRBAC.ps1 `
    -PrincipalId "devops-group-id" `
    -Role "Monitoring Contributor" `
    -Scope "/subscriptions/sub-id/resourceGroups/rg-prod"

# Assign Monitoring Reader to management
.\scripts\Set-MonitoringRBAC.ps1 `
    -PrincipalId "management-group-id" `
    -Role "Monitoring Reader" `
    -Scope "/subscriptions/sub-id"
```

### Custom Role Definition

```json
{
  "Name": "Metric Alert Manager",
  "Description": "Can create and modify metric alerts but not delete",
  "Actions": [
    "Microsoft.Insights/metricAlerts/write",
    "Microsoft.Insights/metricAlerts/read",
    "Microsoft.Insights/actionGroups/read"
  ],
  "NotActions": [
    "Microsoft.Insights/metricAlerts/delete"
  ],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

## Alert Configuration

### CPU Alert Example

Triggers when VM CPU > 80% for 5 consecutive minutes:

```hcl
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "vm-cpu-high"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_virtual_machine.example.id]
  description         = "Alert when CPU exceeds 80%"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = azurerm_monitor_action_group.devops.id
  }
}
```

### Backup Failure Alert

Monitors Azure Backup job status:

```kql
// KQL query for failed backups
AzureDiagnostics
| where Category == "AzureBackupReport"
| where OperationName == "Job" and JobOperation_s == "Backup"
| where JobStatus_s == "Failed"
| summarize FailedJobs = count() by Resource, bin(TimeGenerated, 1h)
| where FailedJobs > 0
```

## Workbook Examples

### VM Performance Dashboard

Displays:
- CPU, memory, disk utilization (last 24 hours)
- Network throughput
- Disk IOPS and latency
- Top 5 resource-intensive VMs
- Alert history

### Network Health Overview

Monitors:
- VPN Gateway connection status
- Application Gateway backend health
- Load Balancer probe status
- NSG flow logs analysis
- ExpressRoute circuit health

## Log Analytics Queries

### Find Performance Bottlenecks

```kql
Perf
| where TimeGenerated > ago(24h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer
| where AvgCPU > 80
| order by AvgCPU desc
```

### Failed Login Attempts

```kql
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4625  // Failed logon
| summarize FailedAttempts = count() by Account, Computer
| where FailedAttempts > 5
| order by FailedAttempts desc
```

### Backup Verification

```kql
AzureDiagnostics
| where Category == "AzureBackupReport"
| where TimeGenerated > ago(7d)
| summarize 
    SuccessfulBackups = countif(JobStatus_s == "Completed"),
    FailedBackups = countif(JobStatus_s == "Failed")
    by Resource
| extend SuccessRate = round((SuccessfulBackups * 100.0) / (SuccessfulBackups + FailedBackups), 2)
| order by SuccessRate asc
```

## Automated Reporting

### Weekly Backup Health Report

Runs every Monday at 8 AM, sends email with:
- Backup success rate per resource
- Failed backup details
- Retention policy compliance
- Recommended actions

```powershell
# Schedule with Azure Automation
.\scripts\Schedule-BackupReport.ps1 -Frequency "Weekly" -DayOfWeek "Monday" -Time "08:00"
```

## Cost Tracking

Integrated cost dashboard shows:
- Daily spend trend (last 30 days)
- Top 10 cost drivers
- Budget vs. actual
- Forecast for month-end
- Cost per resource tag

## Customization

### Terraform-Based Customization

**Add Custom Metrics via Code:**

```powershell
# Add custom metric alert
New-AzMetricAlertRuleV2 `
    -Name "custom-metric-alert" `
    -ResourceGroupName "rg-monitoring" `
    -WindowSize 00:05:00 `
    -Frequency 00:01:00 `
    -TargetResourceId "/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-web-01" `
    -Condition $(New-AzMetricAlertRuleV2Criteria `
        -MetricName "Available Memory Bytes" `
        -MetricNamespace "Microsoft.Compute/virtualMachines" `
        -Operator LessThan `
        -Threshold 1073741824 `  # 1GB
        -TimeAggregation Average)
```

### Portal-Based Customization

#### Modify Azure Monitor Workbook

**When to use Portal for workbook editing:**
- Visual query builder for complex KQL
- Testing visualizations before committing to code
- Quick iterations based on team feedback
- Adding interactive parameters

**Steps:**
1. Azure Portal → **Monitor** → **Workbooks**
2. Find deployed workbook → Click **Edit**
3. Modify components:
   - **Add query step**: Write KQL, select visualization type
   - **Add parameters**: Dropdowns for resource group, time range filtering
   - **Add text**: Markdown for documentation
   - **Add metrics**: Direct metric chart without KQL
4. Click **Done Editing** → **Save As** → Create new version
5. Share workbook URL with team

**Example Customizations:**
- Added "Top 5 CPU consumers" query with bar chart
- Created time range parameter (Last hour / Last 24 hours / Last 7 days)
- Added conditional formatting (red if CPU > 90%, yellow if > 70%)

#### Create Custom KQL Queries (Portal)

**Log Analytics Workspace → Logs**

**Example 1: Find VMs with Failed Windows Updates**
```kql
Update
| where TimeGenerated > ago(7d)
| where UpdateState == "Failed"
| summarize FailedUpdates = count() by Computer
| order by FailedUpdates desc
```

**Example 2: Network Traffic Analysis**
```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| summarize BytesTransferred = sum(FlowBytes_d) by 
    SourceIP = SrcIP_s, 
    DestinationIP = DestIP_s
| where BytesTransferred > 1000000000  // > 1GB
| order by BytesTransferred desc
```

**Save Query:**
1. Run query → Verify results
2. Click **Save** → **Save as query**
3. Name: "High Network Traffic Analysis"
4. Category: "Network"
5. Now appears in Queries sidebar for team

#### Configure Dynamic Alert Thresholds (Portal)

**Why Portal:**
- Machine learning-based threshold requires historical data visualization
- Seasonal pattern preview helps validate configuration

**Steps:**
1. Portal → **Monitor** → **Alerts** → **+ Create** → **Alert rule**
2. Select resource (e.g., VM)
3. Condition → **Add** → Select metric
4. Alert logic:
   - **Operator**: Greater than
   - **Aggregation type**: Average
   - **Threshold**: Select **"Dynamic"**
   - **Threshold sensitivity**: Medium (adjusts based on history)
   - **Number of violations**: 2 out of last 4 evaluations
5. Preview chart shows dynamic threshold band
6. Configure action group
7. **Create alert rule**

**When to use Dynamic vs Static:**
- Dynamic: Traffic patterns, seasonal workloads, variable usage
- Static: Critical thresholds (disk space < 10%, memory < 1GB)

#### Assign RBAC Roles (Portal)

**Why Portal for RBAC:**
- Visual group search (find Azure AD groups by name)
- See all current assignments before adding new ones
- Validate effective permissions immediately

**Steps:**
1. Azure Portal → Resource Group → **Access control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. **Role** tab → Select role (e.g., "Monitoring Contributor")
4. **Members** tab → **Select members** → Search for Azure AD group
5. **Review + assign** → Verify and confirm

**Verify Assignment:**
- IAM → **Role assignments** → Filter by role
- Check → **Download role assignments** (CSV for audit)

#### Create Shared Dashboards (Portal)

**Use Case:** Executive team wants single-pane-of-glass view

**Steps:**
1. Portal → **Dashboard** → **+ New dashboard** → **Blank dashboard**
2. Click **Edit** → Add tiles:
   - **Metrics chart**: VM CPU across all production VMs
   - **Query results**: Top 5 cost drivers (Cost Management)
   - **Resource health**: All VMs health status
   - **Workbook**: Embed existing workbook
3. Resize and arrange tiles
4. Click **Done customizing** → **Save**
5. **Share** → Select user groups → **Publish**

**Best Practices:**
- Max 8-10 tiles per dashboard (avoid clutter)
- Use consistent time ranges across widgets
- Add text tiles for context ("Production Environment Overview")
- Create separate dashboards for different audiences
- 

### Implementation Method: Terraform + Portal Hybrid

**Phase 1: Infrastructure Deployment (Terraform)**
Deployed via `terraform apply`:
- Log Analytics Workspace (30-day retention)
- Action Groups (email, webhook)
- Base metric alerts (CPU, memory, disk)
- RBAC role definitions

**Phase 2: Portal Configuration (Manual Tasks)**

1. **Custom Workbooks Creation** (Azure Portal → Monitor → Workbooks)
   - Created "VM Performance Dashboard" with 15 custom visualizations
   - Built "Network Health Overview" with real-time connection status
   - Configured "Cost & Resource Tracking" with budget widgets
   - Added parameter filters (resource group, time range, environment)
   - Pinned workbooks to shared dashboard

2. **KQL Query Development** (Portal → Log Analytics Workspace)
   - Wrote 25+ custom KQL queries for troubleshooting
   - Saved frequently-used queries in workspace
   - Created query packs for team sharing
   - Tested and refined queries based on real incidents

3. **Alert Fine-Tuning** (Portal → Monitor → Alerts)
   - Adjusted CPU threshold from 80% to 85% (reduced false positives)
   - Configured dynamic thresholds for seasonal traffic patterns
   - Set up multi-resource alerts for VM scale sets
   - Created alert processing rules for maintenance windows

4. **RBAC Assignment** (Portal → Access Control IAM)
   - Assigned Monitoring Contributor to DevOps Azure AD group
   - Assigned Monitoring Reader to Developers group
   - Created custom role "Backup Operator" with limited permissions
   - Documented all assignments in RBAC matrix

5. **Action Group Configuration** (Portal → Monitor → Action Groups)
   - Added SMS notifications for critical alerts
   - Integrated with PagerDuty webhook
   - Configured ITSM connector for ticket creation
   - Set up Azure Functions for custom automation

6. **Dashboard Creation** (Portal → Home → Dashboard)
   - Created executive dashboard with high-level metrics
   - Built operations dashboard for on-call engineers
   - Configured auto-refresh every 5 minutes
   - Shared dashboards with stakeholder groups

### After Implementation Results
- Custom workbook tracking 45 metrics
- RBAC implemented across 3 user groups
- Automated backup verification (daily)
- Mean time to detection: **12 minutes (60% faster)**
- Full audit trail for compliance
- Zero manual monitoring tasks

## Troubleshooting

### Alert Not Firing

1. Check metric query returns data:
   ```kql
   AzureMetrics
   | where TimeGenerated > ago(1h)
   | where MetricName == "Percentage CPU"
   | summarize avg(Average) by bin(TimeGenerated, 5m)
   ```

2. Verify action group email delivery
3. Check alert rule is enabled
4. Review evaluation frequency and window size

### RBAC Permission Denied

```powershell
# Verify role assignment
Get-AzRoleAssignment -Scope "/subscriptions/sub-id" | Where-Object { $_.PrincipalId -eq "user-id" }

# Check custom role definition
Get-AzRoleDefinition -Name "Metric Alert Manager"
```


---

**Deployment Time**: 30-60 minutes  
**Maintenance**: ~2 hours/month for query tuning  
**ROI**: 10x improvement in incident response efficiency
