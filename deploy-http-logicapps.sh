#!/bin/bash

set -e

SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
LOCATION="eastus"
WORKSPACE_NAME="sentinel"

echo "==========================================="
echo "Deploying Pure HTTP Logic Apps"
echo "==========================================="

az account set --subscription "$SUBSCRIPTION_ID"

WORKSPACE_ID="810f0ce0-1e5b-495b-844f-ac41e7225a92"
WORKSPACE_KEY=$(cat /tmp/logic-app-config.env | grep WORKSPACE_KEY | cut -d'=' -f2)
WORKSPACE_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"

echo "Workspace ID: $WORKSPACE_ID"
echo ""

# Deploy FailedAuth Logic App
echo "1. Deploying FailedAuth-HTTP..."

KQL1='let timeRange = 24h; SigninLogs | where TimeGenerated > ago(timeRange) | where ResultType != 0 | summarize FailedAttempts = count(), FirstAttempt = min(TimeGenerated), LastAttempt = max(TimeGenerated) by UserPrincipalName | where FailedAttempts >= 5 | extend Severity = case(FailedAttempts >= 20, "Critical", FailedAttempts >= 10, "High", "Medium"), FindingType = "Failed Authentication", RemediationRequired = iff(FailedAttempts >= 10, "Yes", "Review")'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-pure-http.json \
  --parameters \
    logicAppName="FailedAuth-HTTP" \
    kqlQuery="$KQL1" \
    reportName="FailedAuthenticationReport" \
    reportType="Identity" \
    controlID="AC-7|CIS-5.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="identity" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    location="$LOCATION"

PRINCIPAL_ID=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name logicapp-pure-http --query properties.outputs.principalId.value -o tsv)

echo "✓ FailedAuth-HTTP deployed"
echo "  Principal ID: $PRINCIPAL_ID"

# Grant Log Analytics Reader role
echo "  Granting Log Analytics Reader role..."
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Log Analytics Reader" \
  --scope "$WORKSPACE_RESOURCE_ID" \
  --output none 2>/dev/null || echo "  (Role may already exist)"

echo ""
echo "==========================================="
echo "Deployment Complete!"
echo "==========================================="
echo ""
echo "Test the Logic App:"
echo "  az rest --method POST --url \"https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Logic/workflows/FailedAuth-HTTP/triggers/Recurrence/run?api-version=2016-06-01\""
echo ""
