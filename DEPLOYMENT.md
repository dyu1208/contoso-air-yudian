# Contoso Air - Azure Kubernetes Service Deployment

This guide provides step-by-step instructions for containerizing and deploying the Contoso Air application to Azure Kubernetes Service (AKS).

## Architecture Overview

The deployment includes:
- **Dockerfile**: Multi-stage build with Node.js 22 Alpine base image
- **Kubernetes Manifests**: ConfigMap, Secret, Deployment, Service, and Ingress
- **Azure Container Registry (ACR)**: For storing container images
- **Azure Kubernetes Service (AKS)**: For orchestrating containers
- **NGINX Ingress Controller**: For external access

## Security Features

- **Non-root user**: Container runs as user ID 1001
- **Runtime security**: RuntimeDefault seccomp profile
- **Dropped capabilities**: All Linux capabilities dropped
- **Resource limits**: CPU and memory constraints
- **Health checks**: Liveness, readiness, and startup probes
- **Pod anti-affinity**: Distributes replicas across nodes
- **Managed Identity**: For secure Azure service authentication

## Prerequisites

- Azure CLI (`az`)
- Docker
- kubectl
- Active Azure subscription

## Quick Deployment

Run the automated deployment script:

```bash
./deploy-to-aks.sh
```

This script will:
1. Create Azure resource group
2. Create Azure Container Registry (ACR)
3. Build and push Docker image
4. Create AKS cluster with 3 nodes
5. Install NGINX Ingress Controller
6. Deploy the application
7. Provide access URLs

## Manual Deployment Steps

### 1. Build Docker Image

```bash
# Build the image
docker build -t contoso-air:latest .

# Test locally (optional)
docker run -p 3000:3000 contoso-air:latest
```

### 2. Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="rg-contoso-air-aks"
ACR_NAME="acrcontosoair$(date +%s)"
AKS_CLUSTER="aks-contoso-air"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --node-count 3 \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys
```

### 3. Push Image to ACR

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Tag and push image
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
docker tag contoso-air:latest $ACR_LOGIN_SERVER/contoso-air:latest
docker push $ACR_LOGIN_SERVER/contoso-air:latest
```

### 4. Deploy to AKS

```bash
# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Update deployment image
sed -i "s|image: contoso-air:latest|image: $ACR_LOGIN_SERVER/contoso-air:latest|g" k8s/deployment.yaml

# Deploy application
kubectl apply -f k8s/

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/contoso-air
```

## Configuration

### Environment Variables

Update `k8s/secret.yaml` with your Azure Cosmos DB configuration:

```bash
# Encode your values
echo -n "your-client-id" | base64
echo -n "your-connection-string-url" | base64
echo -n "your-scope" | base64
```

### Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment contoso-air --replicas=5

# Auto-scaling (optional)
kubectl autoscale deployment contoso-air --cpu-percent=70 --min=3 --max=10
```

## Monitoring and Troubleshooting

### View Resources

```bash
# Check pods
kubectl get pods -l app=contoso-air

# Check services
kubectl get services

# Check ingress
kubectl get ingress
```

### View Logs

```bash
# View application logs
kubectl logs -l app=contoso-air

# Follow logs
kubectl logs -f deployment/contoso-air
```

### Debug Issues

```bash
# Describe pod for events
kubectl describe pod <pod-name>

# Execute into container
kubectl exec -it <pod-name> -- sh

# Port forward for local testing
kubectl port-forward service/contoso-air-service 3000:80
```

## Health Checks

The application includes three types of health checks:

- **Startup Probe**: Ensures container starts successfully
- **Liveness Probe**: Restarts container if unhealthy
- **Readiness Probe**: Removes from service if not ready

All probes use the `/health` endpoint that returns:
```json
{
  "status": "healthy",
  "timestamp": "2025-06-07T10:30:00.000Z"
}
```

## Security Considerations

- Container runs as non-root user (UID 1001)
- RuntimeDefault seccomp profile enabled
- All capabilities dropped for minimal attack surface
- Resource limits prevent resource exhaustion
- Pod anti-affinity improves resilience
- Secrets stored in Kubernetes Secret objects

## Performance Optimizations

- **Multi-replica deployment**: 3 replicas by default
- **Resource requests/limits**: Optimized for Node.js application
- **Pod anti-affinity**: Spreads pods across nodes
- **Topology spread constraints**: Even distribution
- **Connection pooling**: Enabled for database connections

## Cleanup

Remove all resources:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Files Structure

```
├── Dockerfile                 # Container image definition
├── .dockerignore             # Docker build exclusions
├── deploy-to-aks.sh          # Automated deployment script
└── k8s/                      # Kubernetes manifests
    ├── configmap.yaml        # Application configuration
    ├── secret.yaml           # Sensitive data
    ├── deployment.yaml       # Pod specification
    ├── service.yaml          # Internal networking
    └── ingress.yaml          # External access
```

## Next Steps

- Set up CI/CD pipeline for automated deployments
- Configure monitoring with Azure Monitor
- Implement backup strategies for persistent data
- Set up alerts and notifications
- Consider using Azure Key Vault for secrets management
