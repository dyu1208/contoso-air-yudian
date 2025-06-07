#!/bin/bash

# Contoso Air - AKS Monitoring Script
# This script provides monitoring and management commands for the deployed application

set -e

NAMESPACE="default"
APP_NAME="contoso-air"

echo "🔍 Contoso Air AKS Monitoring Dashboard"
echo "========================================"

# Function to check if kubectl is configured
check_kubectl() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "❌ kubectl is not configured or cluster is not accessible"
        echo "Run: az aks get-credentials --resource-group rg-contoso-air-aks --name aks-contoso-air"
        exit 1
    fi
}

# Function to show pod status
show_pods() {
    echo "📦 Pod Status:"
    kubectl get pods -l app=$APP_NAME -o wide
    echo ""
}

# Function to show service status
show_services() {
    echo "🌐 Service Status:"
    kubectl get services -l app=$APP_NAME
    echo ""
}

# Function to show ingress status
show_ingress() {
    echo "🚪 Ingress Status:"
    kubectl get ingress
    echo ""
}

# Function to show deployment status
show_deployment() {
    echo "🚀 Deployment Status:"
    kubectl get deployment $APP_NAME
    echo ""
}

# Function to show logs
show_logs() {
    echo "📋 Recent Logs (last 50 lines):"
    kubectl logs -l app=$APP_NAME --tail=50
    echo ""
}

# Function to show resource usage
show_resources() {
    echo "💾 Resource Usage:"
    kubectl top pods -l app=$APP_NAME 2>/dev/null || echo "Metrics server not available"
    echo ""
}

# Function to get external IP
get_external_ip() {
    echo "🌍 External Access:"
    EXTERNAL_IP=$(kubectl get svc ${APP_NAME}-service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" 2>/dev/null)
    if [ -z "$EXTERNAL_IP" ]; then
        echo "External IP not yet assigned. Checking service status..."
        kubectl get svc ${APP_NAME}-service
    else
        echo "Application URL: http://$EXTERNAL_IP"
    fi
    echo ""
}

# Function to scale deployment
scale_deployment() {
    local replicas=$1
    if [ -z "$replicas" ]; then
        echo "Usage: $0 scale <number_of_replicas>"
        exit 1
    fi
    echo "⚖️ Scaling deployment to $replicas replicas..."
    kubectl scale deployment $APP_NAME --replicas=$replicas
    echo ""
}

# Function to restart deployment
restart_deployment() {
    echo "🔄 Restarting deployment..."
    kubectl rollout restart deployment/$APP_NAME
    echo "Waiting for rollout to complete..."
    kubectl rollout status deployment/$APP_NAME
    echo ""
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status     - Show overall application status"
    echo "  pods       - Show pod status"
    echo "  services   - Show service status"
    echo "  ingress    - Show ingress status"
    echo "  logs       - Show recent application logs"
    echo "  resources  - Show resource usage"
    echo "  ip         - Get external IP address"
    echo "  scale <n>  - Scale deployment to n replicas"
    echo "  restart    - Restart deployment"
    echo "  help       - Show this help message"
    echo ""
}

# Main logic
check_kubectl

case "${1:-status}" in
    "status")
        show_deployment
        show_pods
        show_services
        get_external_ip
        ;;
    "pods")
        show_pods
        ;;
    "services")
        show_services
        ;;
    "ingress")
        show_ingress
        ;;
    "logs")
        show_logs
        ;;
    "resources")
        show_resources
        ;;
    "ip")
        get_external_ip
        ;;
    "scale")
        scale_deployment $2
        ;;
    "restart")
        restart_deployment
        ;;
    "help")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
