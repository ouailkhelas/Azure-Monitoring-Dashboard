# RBAC Matrix - Azure Monitoring Solution

This document defines role-based access control (RBAC) for the Azure monitoring infrastructure.

## Built-in Roles Used

### 1. Monitoring Contributor

**Scope**: Resource Group or Subscription level  
**Typical Users**: DevOps Engineers, SRE Teams  
**Purpose**: Full management of monitoring resources (alerts, workbooks, action groups)

**Permissions**:
- ✅ Create/edit/delete metric alerts
- ✅ Create/edit/delete log alerts
- ✅ Create/edit Azure Monitor workbooks
- ✅ Configure action groups
- ✅ View all monitoring data
- ✅ Configure diagnostic settings
- ❌ Cannot delete Log Analytics workspace
- ❌ Cannot modify RBAC permissions

**Azure Actions**:
```
Microsoft.Insights/alertRules/*
Microsoft.Insights/metricAlerts/*
Microsoft.Insights/workbooks/*
Microsoft.Insights/actionGroups/*
Microsoft.Insights/diagnosticSettings/*
Microsoft.OperationalInsights/workspaces/query/read
```

**Assignment Example**:
```bash
az role assignment create \
  --assignee-object-id "devops-group-id" \
  --role "Monitoring Contributor" \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-monitoring"
```

---

### 2. Monitoring Reader

**Scope**: Resource Group or Subscription level  
**Typical Users**: Developers, Product Managers, Business Stakeholders  
**Purpose**: View-only access to dashboards and metrics

**Permissions**:
- ✅ View all monitoring dashboards
- ✅ View metric data
- ✅ View alerts and their history
- ✅ View Log Analytics queries
- ❌ Cannot create or modify alerts
- ❌ Cannot edit workbooks
- ❌ Cannot configure action groups

**Azure Actions**:
```
Microsoft.Insights/alertRules/read
Microsoft.Insights/metricAlerts/read
Microsoft.Insights/workbooks/read
Microsoft.Insights/metrics/read
Microsoft.OperationalInsights/workspaces/query/read
```

**Assignment Example**:
```bash
az role assignment create \
  --assignee-object-id "dev-group-id" \
  --role "Monitoring Reader" \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-prod"
```

---

### 3. Backup Contributor

**Scope**: Recovery Services Vault  
**Typical Users**: Backup Administrators  
**Purpose**: Manage backup operations without full infrastructure access

**Permissions**:
- ✅ Configure backup policies
- ✅ Trigger on-demand backups
- ✅ Restore from backups
- ✅ View backup jobs
- ❌ Cannot delete vault
- ❌ Cannot modify RBAC

**Azure Actions**:
```
Microsoft.RecoveryServices/Vaults/backupFabrics/protectionContainers/protectedItems/backup/action
Microsoft.RecoveryServices/Vaults/backupPolicies/*
Microsoft.RecoveryServices/Vaults/backupJobs/read
```

**Assignment Example**:
```bash
az role assignment create \
  --assignee-object-id "backup-admin-id" \
  --role "Backup Contributor" \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/vault-prod"
```

---

### 4. Backup Operator

**Scope**: Recovery Services Vault  
**Typical Users**: Junior Backup Admins, Support Staff  
**Purpose**: Execute backups and restores without policy modification

**Permissions**:
- ✅ Trigger backups
- ✅ Perform restores
- ✅ View backup status
- ❌ Cannot modify policies
- ❌ Cannot disable backups

**Azure Actions**:
```
Microsoft.RecoveryServices/Vaults/backupFabrics/protectionContainers/protectedItems/backup/action
Microsoft.RecoveryServices/Vaults/backupFabrics/protectionContainers/protectedItems/recoveryPoints/restore/action
Microsoft.RecoveryServices/Vaults/backupJobs/read
```

---

## Custom Roles Defined

### 5. Metric Alert Manager (Custom)

**Purpose**: Junior DevOps can create alerts but not delete critical ones  
**Why Custom**: Built-in roles allow both create AND delete

**Definition**:
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

**Create Custom Role**:
```bash
az role definition create --role-definition metric-alert-manager.json
```

**Assignment**:
```bash
az role assignment create \
  --assignee-object-id "junior-devops-id" \
  --role "Metric Alert Manager" \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-monitoring"
```

---

### 6. Log Analytics Query Author (Custom)

**Purpose**: Data analysts can write queries but not modify workspace  
**Why Custom**: Monitoring Reader is too restrictive, Contributor is too broad

**Definition**:
```json
{
  "Name": "Log Analytics Query Author",
  "Description": "Can write and save queries but not modify workspace",
  "Actions": [
    "Microsoft.OperationalInsights/workspaces/query/read",
    "Microsoft.OperationalInsights/workspaces/query/*/read",
    "Microsoft.OperationalInsights/workspaces/savedSearches/write"
  ],
  "NotActions": [
    "Microsoft.OperationalInsights/workspaces/write",
    "Microsoft.OperationalInsights/workspaces/delete"
  ],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

---

## RBAC Assignment Matrix

| User Group | Resource Scope | Role | Justification |
|------------|----------------|------|---------------|
| DevOps Team | Monitoring RG | Monitoring Contributor | Need to create/edit alerts and dashboards |
| DevOps Team | Production VMs | Reader | View VM configs for context in alerts |
| Developers | Monitoring RG | Monitoring Reader | View metrics and dashboards only |
| Management | Subscription | Reader | High-level overview access |
| Backup Admins | Backup Vault | Backup Contributor | Full backup management |
| Support Staff | Backup Vault | Backup Operator | Execute backup/restore only |
| Junior DevOps | Monitoring RG | Metric Alert Manager (custom) | Create alerts without delete risk |
| Data Analysts | Log Analytics | Log Analytics Query Author (custom) | Write queries, not modify workspace |

---

## Audit Trail

All RBAC changes are logged in Azure Activity Log:

```kql
AzureActivity
| where TimeGenerated > ago(30d)
| where OperationNameValue == "Microsoft.Authorization/roleAssignments/write"
| project TimeGenerated, Caller, OperationNameValue, ResourceId
| order by TimeGenerated desc
```

**Review quarterly**:
1. Verify all assignments still needed
2. Remove inactive users
3. Validate least-privilege principle

---

## Separation of Duties

**Principle**: No single person should have end-to-end control over critical operations.

| Operation | Required Roles | Ensures |
|-----------|----------------|---------|
| Create Alert + Approve Budget | Monitoring Contributor + Owner | DevOps can't unilaterally increase spend |
| Modify Backup + Delete Vault | Backup Contributor + Owner | Backup admin can't accidentally destroy vault |
| View Logs + Export Data | Monitoring Reader + Storage Blob Contributor | Separate read from write permissions |

---

## Emergency Break-Glass Procedure

**Scenario**: Critical alert misconfiguration blocking prod deployment

**Process**:
1. Request temporary Owner access via PIM (Privileged Identity Management)
2. Max duration: 8 hours
3. Approval required from 2 managers
4. All actions logged and reviewed post-incident
5. Access auto-revokes after time limit

**PIM Configuration**:
```bash
az ad pim activation create \
  --role "Owner" \
  --scope "/subscriptions/{sub-id}" \
  --justification "Critical alert blocking deployment - INC-2024-001" \
  --duration "PT8H"
```

---

## Testing RBAC

### Verify Monitoring Contributor

```bash
# Login as DevOps user
az login --username devops@company.com

# Should succeed
az monitor metrics alert create \
  --name test-alert \
  --resource-group rg-monitoring \
  --scopes /subscriptions/.../virtualMachines/vm-test \
  --condition "avg Percentage CPU > 90"

# Should fail
az group delete --name rg-monitoring --yes
```

### Verify Monitoring Reader

```bash
# Login as developer
az login --username dev@company.com

# Should succeed
az monitor metrics list \
  --resource /subscriptions/.../virtualMachines/vm-prod

# Should fail
az monitor metrics alert create \
  --name unauthorized-alert \
  --resource-group rg-monitoring
```

---

## Best Practices

1. **Least Privilege**: Start with Reader, add permissions as needed
2. **Group-Based**: Assign roles to Azure AD groups, not individual users
3. **Scoped**: Use resource group scope instead of subscription when possible
4. **Custom Roles**: Only create when built-in roles don't fit
5. **Regular Reviews**: Quarterly access reviews to remove stale assignments
6. **Documentation**: Keep this matrix updated with all custom roles
7. **Testing**: Verify permissions in dev before applying to prod

---

## Related Resources

- [Azure Built-in Roles Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Create Custom Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
- [RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)