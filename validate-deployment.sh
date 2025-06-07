#!/bin/bash

# Contoso Air - Deployment Validation Script
# This script validates the deployment and performs health checks

set -e

echo "🔍 Contoso Air Deployment Validation"
echo "====================================="

# Function to validate prerequisites
validate_prerequisites() {
    echo "📋 Validating prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "❌ kubectl is not installed"
        return 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "❌ Cannot connect to Kubernetes cluster"
        echo "Run: az aks get-credentials --resource-group rg-contoso-air-aks --name aks-contoso-air"
        return 1
    fi
    
    echo "✅ Prerequisites validated"
    return 0
}

# Function to validate deployment
validate_deployment() {
    echo "🚀 Validating deployment..."
    
    # Check if deployment exists
    if ! kubectl get deployment contoso-air >/dev/null 2>&1; then
        echo "❌ Deployment 'contoso-air' not found"
        return 1
    fi
    
    # Check deployment status
    READY_REPLICAS=$(kubectl get deployment contoso-air -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment contoso-air -o jsonpath='{.spec.replicas}')
    
    if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
        echo "❌ Deployment not ready: $READY_REPLICAS/$DESIRED_REPLICAS replicas ready"
        return 1
    fi
    
    echo "✅ Deployment validated ($READY_REPLICAS/$DESIRED_REPLICAS replicas ready)"
    return 0
}

# Function to validate pods
validate_pods() {
    echo "📦 Validating pods..."
    
    # Get pod status
    PODS=$(kubectl get pods -l app=contoso-air -o jsonpath='{.items[*].status.phase}')
    
    for pod_status in $PODS; do
        if [ "$pod_status" != "Running" ]; then
            echo "❌ Pod not running: $pod_status"
            kubectl get pods -l app=contoso-air
            return 1
        fi
    done
    
    echo "✅ All pods validated"
    return 0
}

# Function to validate service
validate_service() {
    echo "🌐 Validating service..."
    
    # Check if service exists
    if ! kubectl get service contoso-air-service >/dev/null 2>&1; then
        echo "❌ Service 'contoso-air-service' not found"
        return 1
    fi
    
    # Check if external IP is assigned
    EXTERNAL_IP=$(kubectl get service contoso-air-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$EXTERNAL_IP" ]; then
        echo "⏳ External IP not yet assigned to service"
        return 1
    fi
    
    echo "✅ Service validated (External IP: $EXTERNAL_IP)"
    return 0
}

# Function to validate application health
validate_health() {
    echo "💓 Validating application health..."
    
    # Get service external IP
    EXTERNAL_IP=$(kubectl get service contoso-air-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$EXTERNAL_IP" ]; then
        echo "⏳ Cannot test health - no external IP assigned"
        return 1
    fi
    
    # Test health endpoint
    if curl -f -s "http://$EXTERNAL_IP/health" >/dev/null; then
        echo "✅ Application health check passed"
        return 0
    else
        echo "❌ Application health check failed"
        return 1
    fi
}

# Function to show deployment summary
show_summary() {
    echo ""
    echo "📊 Deployment Summary"
    echo "===================="
    
    # Deployment info
    kubectl get deployment contoso-air
    echo ""
    
    # Pod info
    kubectl get pods -l app=contoso-air -o wide
    echo ""
    
    # Service info
    kubectl get service contoso-air-service
    echo ""
    
    # Get external IP and show access URL
    EXTERNAL_IP=$(kubectl get service contoso-air-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$EXTERNAL_IP" ]; then
        echo "🌍 Application Access:"
        echo "URL: http://$EXTERNAL_IP"
        echo "Health Check: http://$EXTERNAL_IP/health"
    else
        echo "⏳ External IP not yet assigned"
    fi
    echo ""
}

# Function to show troubleshooting info
show_troubleshooting() {
    echo "🔧 Troubleshooting Information"
    echo "============================="
    
    echo "Recent pod events:"
    kubectl get events --field-selector involvedObject.kind=Pod -l app=contoso-air --sort-by='.lastTimestamp' | tail -10
    echo ""
    
    echo "Pod logs (last 20 lines):"
    kubectl logs -l app=contoso-air --tail=20
    echo ""
    
    echo "Pod resource usage:"
    kubectl top pods -l app=contoso-air 2>/dev/null || echo "Metrics server not available"
    echo ""
}

# Main validation logic
main() {
    local exit_code=0
    
    # Run validations
    validate_prerequisites || exit_code=1
    sleep 2
    
    validate_deployment || exit_code=1
    sleep 2
    
    validate_pods || exit_code=1
    sleep 2
    
    validate_service || exit_code=1
    sleep 2
    
    validate_health || exit_code=1
    
    # Show summary
    show_summary
    
    # Show troubleshooting if there were issues
    if [ $exit_code -ne 0 ]; then
        show_troubleshooting
        echo "❌ Validation completed with errors"
    else
        echo "✅ All validations passed successfully!"
    fi
    
    exit $exit_code
}

# Run based on argument
case "${1:-validate}" in
    "validate")
        main
        ;;
    "summary")
        show_summary
        ;;
    "troubleshoot")
        show_troubleshooting
        ;;
    *)
        echo "Usage: $0 [validate|summary|troubleshoot]"
        exit 1
        ;;
esac
