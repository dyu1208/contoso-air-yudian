#!/bin/bash

# Contoso Air - Azure Kubernetes Service Deployment Script
# This script builds the container image, pushes it to ACR, and deploys to AKS

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-contoso-air-aks"
AKS_CLUSTER_NAME="aks-contoso-air"
ACR_NAME="acrcontosoair$(date +%s)"  # Unique name with timestamp
LOCATION="eastus"
IMAGE_NAME="contoso-air"
IMAGE_TAG="latest"

echo "🚀 Starting Contoso Air AKS Deployment"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "ACR Name: $ACR_NAME"
echo "Location: $LOCATION"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command_exists az; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

if ! command_exists docker; then
    echo "❌ Docker is not installed. Please install it first."
    exit 1
fi

if ! command_exists kubectl; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

# Login to Azure (if not already logged in)
echo "🔐 Checking Azure login status..."
if ! az account show >/dev/null 2>&1; then
    echo "Please log in to Azure..."
    az login
fi

# Create resource group
echo "📁 Creating resource group..."
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --output table

# Create Azure Container Registry
echo "🏗️ Creating Azure Container Registry..."
az acr create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $ACR_NAME \
    --sku Basic \
    --admin-enabled true \
    --output table

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query loginServer --output tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Login to ACR
echo "🔑 Logging into ACR..."
az acr login --name $ACR_NAME

# Build and push Docker image
echo "🐳 Building Docker image..."
docker build -t $IMAGE_NAME:$IMAGE_TAG .

echo "🏷️ Tagging image for ACR..."
docker tag $IMAGE_NAME:$IMAGE_TAG $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG

echo "📤 Pushing image to ACR..."
docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG

# Create AKS cluster
echo "☸️ Creating AKS cluster..."
az aks create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $AKS_CLUSTER_NAME \
    --node-count 3 \
    --node-vm-size Standard_B2s \
    --enable-addons monitoring \
    --attach-acr $ACR_NAME \
    --generate-ssh-keys \
    --output table

# Get AKS credentials
echo "🔑 Getting AKS credentials..."
az aks get-credentials \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $AKS_CLUSTER_NAME \
    --overwrite-existing

# Install NGINX Ingress Controller
echo "🌐 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for NGINX controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Update deployment image to use ACR
echo "📝 Updating deployment with ACR image..."
sed -i "s|image: contoso-air:latest|image: $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG|g" k8s/deployment.yaml

# Deploy the application
echo "🚀 Deploying Contoso Air to AKS..."
kubectl apply -f k8s/

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/contoso-air

# Get service information
echo "📊 Getting service information..."
kubectl get services
kubectl get pods
kubectl get ingress

# Get external IP
echo "🌍 Getting external IP address..."
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
    echo "Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get svc contoso-air-service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "ACR Name: $ACR_NAME"
echo "Application URL: http://$EXTERNAL_IP"
echo ""
echo "🔧 Useful commands:"
echo "View pods: kubectl get pods"
echo "View services: kubectl get services"
echo "View logs: kubectl logs -l app=contoso-air"
echo "Scale deployment: kubectl scale deployment contoso-air --replicas=5"
echo ""
echo "🧹 Cleanup command:"
echo "az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait"
