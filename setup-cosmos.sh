#!/bin/bash

# Setup Azure Cosmos DB for Contoso Air application
# This script creates the necessary Cosmos DB resources and configures managed identity

set -e

echo "Setting up Azure Cosmos DB for Contoso Air..."

# Generate random identifier
RAND=$RANDOM
echo "Random resource identifier: ${RAND}"

# Set variables
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_RESOURCE_GROUP_NAME="rg-contoso-air-aks"
AZURE_COSMOS_ACCOUNT_NAME="db-contosoair${RAND}"
AZURE_REGION="eastus"

echo "Creating Cosmos DB account: $AZURE_COSMOS_ACCOUNT_NAME"

# Create cosmosdb account
AZURE_COSMOS_ACCOUNT_ID=$(az cosmosdb create \
  --name $AZURE_COSMOS_ACCOUNT_NAME \
  --resource-group $AZURE_RESOURCE_GROUP_NAME \
  --kind MongoDB \
  --server-version 7.0 \
  --query id -o tsv)

echo "Cosmos DB account created with ID: $AZURE_COSMOS_ACCOUNT_ID"

# Create test database
echo "Creating test database..."
az cosmosdb mongodb database create \
  --account-name $AZURE_COSMOS_ACCOUNT_NAME \
  --resource-group $AZURE_RESOURCE_GROUP_NAME \
  --name test

# Create managed identity for Cosmos DB access
echo "Creating managed identity..."
AZURE_COSMOS_IDENTITY_ID=$(az identity create \
  --name db-contosoair${RAND}-id \
  --resource-group $AZURE_RESOURCE_GROUP_NAME \
  --query id -o tsv)

# Get managed identity principal id
AZURE_COSMOS_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --ids $AZURE_COSMOS_IDENTITY_ID \
  --query principalId \
  -o tsv)

# Get managed identity client id
AZURE_COSMOS_CLIENTID=$(az identity show \
  --ids $AZURE_COSMOS_IDENTITY_ID \
  --query clientId \
  -o tsv)

echo "Managed identity created with client ID: $AZURE_COSMOS_CLIENTID"

# Assign role to managed identity
echo "Assigning DocumentDB Account Contributor role..."
az role assignment create \
  --role "DocumentDB Account Contributor" \
  --assignee $AZURE_COSMOS_IDENTITY_PRINCIPAL_ID \
  --scope $AZURE_COSMOS_ACCOUNT_ID

# Set environment variables for kubernetes secrets
export AZURE_COSMOS_LISTCONNECTIONSTRINGURL="https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP_NAME/providers/Microsoft.DocumentDB/databaseAccounts/$AZURE_COSMOS_ACCOUNT_NAME/listConnectionStrings?api-version=2021-04-15"
export AZURE_COSMOS_SCOPE="https://management.azure.com/.default"

echo ""
echo "Cosmos DB setup completed!"
echo ""
echo "Configuration values for Kubernetes secrets:"
echo "AZURE_COSMOS_CLIENTID: $AZURE_COSMOS_CLIENTID"
echo "AZURE_COSMOS_LISTCONNECTIONSTRINGURL: $AZURE_COSMOS_LISTCONNECTIONSTRINGURL"
echo "AZURE_COSMOS_SCOPE: $AZURE_COSMOS_SCOPE"
echo ""

# Base64 encode values for Kubernetes secrets
echo "Base64 encoded values for k8s/secret.yaml:"
echo "AZURE_COSMOS_CLIENTID: $(echo -n "$AZURE_COSMOS_CLIENTID" | base64)"
echo "AZURE_COSMOS_LISTCONNECTIONSTRINGURL: $(echo -n "$AZURE_COSMOS_LISTCONNECTIONSTRINGURL" | base64)"
echo "AZURE_COSMOS_SCOPE: $(echo -n "$AZURE_COSMOS_SCOPE" | base64)"
echo ""

# Save configuration to a file for later use
cat > cosmos-config.txt << EOF
AZURE_COSMOS_ACCOUNT_NAME=$AZURE_COSMOS_ACCOUNT_NAME
AZURE_COSMOS_CLIENTID=$AZURE_COSMOS_CLIENTID
AZURE_COSMOS_LISTCONNECTIONSTRINGURL=$AZURE_COSMOS_LISTCONNECTIONSTRINGURL
AZURE_COSMOS_SCOPE=$AZURE_COSMOS_SCOPE
AZURE_COSMOS_IDENTITY_ID=$AZURE_COSMOS_IDENTITY_ID

# Base64 encoded values
AZURE_COSMOS_CLIENTID_B64=$(echo -n "$AZURE_COSMOS_CLIENTID" | base64)
AZURE_COSMOS_LISTCONNECTIONSTRINGURL_B64=$(echo -n "$AZURE_COSMOS_LISTCONNECTIONSTRINGURL" | base64)
AZURE_COSMOS_SCOPE_B64=$(echo -n "$AZURE_COSMOS_SCOPE" | base64)
EOF

echo "Configuration saved to cosmos-config.txt"
echo ""
echo "Next steps:"
echo "1. Update k8s/secret.yaml with the base64 encoded values above"
echo "2. Update k8s/deployment.yaml to use the managed identity"
echo "3. Deploy the application to AKS"
