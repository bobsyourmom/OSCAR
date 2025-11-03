#!/bin/bash

# ============================================================================
# Deploy Logic Apps for Security Copilot Report Ingestion
# ============================================================================
# This script creates Logic Apps that automatically ingest KQL query results
# from Sentinel into the custom ComplianceReports_CL table.
#
# Each Logic App:
# 1. Runs on a schedule (daily)
# 2. Executes a KQL query against Sentinel
# 3. Transforms results to match table schema
# 4. Ingests via HTTP Data Collector API
# ============================================================================

# Configuration
SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
LOCATION="eastus"
WORKSPACE_NAME="sentinel"

echo "=========================================="
echo "Deploying Logic Apps for Report Ingestion"
echo "=========================================="

az account set --subscription "$SUBSCRIPTION_ID"

# Get Workspace ID and Key
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query primarySharedKey -o tsv)

echo "Workspace ID: $WORKSPACE_ID"
echo ""

# ============================================================================
# Deploy Logic App for Failed Authentication Report
# ============================================================================
echo "Deploying Logic App: FailedAuthenticationReport-Ingestion..."

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-failedauth-template.json \
  --parameters \
    logicAppName="FailedAuth-To-CustomTable" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    location="$LOCATION"

echo "✓ FailedAuthenticationReport Logic App deployed"

# ============================================================================
# Deploy Logic App for Malware Detections Report
# ============================================================================
echo "Deploying Logic App: MalwareDetectionsReport-Ingestion..."

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-malware-template.json \
  --parameters \
    logicAppName="Malware-To-CustomTable" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    location="$LOCATION"

echo "✓ MalwareDetectionsReport Logic App deployed"

# ============================================================================
# Deploy Logic App for Admin Activity Report
# ============================================================================
echo "Deploying Logic App: AdminActivityReport-Ingestion..."

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-adminactivity-template.json \
  --parameters \
    logicAppName="AdminActivity-To-CustomTable" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    location="$LOCATION"

echo "✓ AdminActivityReport Logic App deployed"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Logic Apps created:"
echo "1. FailedAuth-To-CustomTable"
echo "2. Malware-To-CustomTable"
echo "3. AdminActivity-To-CustomTable"
echo ""
echo "These Logic Apps run daily at 8 AM and ingest results to ComplianceReports_CL"
echo ""
echo "View Logic Apps:"
echo "az logic workflow list --resource-group $RESOURCE_GROUP -o table"
