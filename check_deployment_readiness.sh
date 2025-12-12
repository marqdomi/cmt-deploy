#!/bin/bash
# check_deployment_readiness.sh
# Script para verificar si todos los recursos están listos para el deployment

set -e

echo "=========================================="
echo "Azure Deployment Readiness Check"
echo "Certificate Manager"
echo "=========================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para verificar recurso
check_resource() {
    local name=$1
    local status=$2
    local expected=$3
    
    if [ "$status" = "$expected" ]; then
        echo -e "  ${GREEN}✅${NC} $name: $status"
        return 0
    elif [ "$status" = "Creating" ] || [ "$status" = "Provisioning" ]; then
        echo -e "  ${YELLOW}⏳${NC} $name: $status (aún en progreso)"
        return 1
    else
        echo -e "  ${RED}❌${NC} $name: $status (esperado: $expected)"
        return 1
    fi
}

# Cargar configuración
source "$(dirname "$0")/azure-deployment-config.env"

ALL_READY=true

echo "Verificando servicios del Hub..."
echo "----------------------------------------"

# Key Vault
KV_STATUS=$(az keyvault show --name $HUB_KEY_VAULT --subscription $AZURE_SUBSCRIPTION_ID --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Error")
check_resource "Key Vault ($HUB_KEY_VAULT)" "$KV_STATUS" "Succeeded" || ALL_READY=false

# Container Registry
ACR_STATUS=$(az acr show --name $ACR_NAME --subscription $AZURE_SUBSCRIPTION_ID --query "provisioningState" -o tsv 2>/dev/null || echo "Error")
check_resource "Container Registry ($ACR_NAME)" "$ACR_STATUS" "Succeeded" || ALL_READY=false

# Log Analytics
LA_STATUS=$(az monitor log-analytics workspace show --workspace-name law-netops-hub-prd-usc --resource-group $HUB_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION_ID --query "provisioningState" -o tsv 2>/dev/null || echo "Error")
check_resource "Log Analytics" "$LA_STATUS" "Succeeded" || ALL_READY=false

echo ""
echo "Verificando servicios del Spoke..."
echo "----------------------------------------"

# PostgreSQL
PG_STATUS=$(az postgres flexible-server show --name $POSTGRES_SERVER --resource-group $SPOKE_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION_ID --query "state" -o tsv 2>/dev/null || echo "Error")
check_resource "PostgreSQL ($POSTGRES_SERVER)" "$PG_STATUS" "Ready" || ALL_READY=false

# Redis
REDIS_STATUS=$(az redis show --name $REDIS_NAME --resource-group $SPOKE_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION_ID --query "provisioningState" -o tsv 2>/dev/null || echo "Error")
check_resource "Redis ($REDIS_NAME)" "$REDIS_STATUS" "Succeeded" || ALL_READY=false

# Container Apps Environment
CAE_STATUS=$(az containerapp env show --name $CONTAINER_APP_ENV --resource-group $SPOKE_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION_ID --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Error")
check_resource "Container Apps Environment" "$CAE_STATUS" "Succeeded" || ALL_READY=false

# VNet Peering
PEERING_STATUS=$(az network vnet peering show --name hub-to-certmgr --vnet-name $HUB_VNET --resource-group $HUB_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION_ID --query "peeringState" -o tsv 2>/dev/null || echo "Error")
check_resource "VNet Peering (Hub→Spoke)" "$PEERING_STATUS" "Connected" || ALL_READY=false

echo ""
echo "Verificando base de datos..."
echo "----------------------------------------"

# Database certmanager
DB_EXISTS=$(az postgres flexible-server db show --resource-group $SPOKE_RESOURCE_GROUP --server-name $POSTGRES_SERVER --database-name certmanager --subscription $AZURE_SUBSCRIPTION_ID --query "name" -o tsv 2>/dev/null || echo "")
if [ -n "$DB_EXISTS" ]; then
    echo -e "  ${GREEN}✅${NC} Database 'certmanager' exists"
else
    echo -e "  ${RED}❌${NC} Database 'certmanager' not found"
    ALL_READY=false
fi

echo ""
echo "=========================================="

if [ "$ALL_READY" = true ]; then
    echo -e "${GREEN}✅ All resources are ready!${NC}"
    echo ""
    echo "You can now proceed with deployment:"
    echo "  ./deploy_to_azure.sh"
    echo ""
    echo "Or manually:"
    echo "  1. ./store_secrets.sh"
    echo "  2. ./build_and_push_images.sh"
    echo "  3. ./deploy_container_apps.sh"
    exit 0
else
    echo -e "${YELLOW}⏳ Some resources are still being created${NC}"
    echo ""
    echo "Please wait for all resources to complete provisioning."
    echo "Run this script again to check status:"
    echo "  ./check_deployment_readiness.sh"
    echo ""
    echo "Estimated time remaining:"
    if [ "$REDIS_STATUS" != "Succeeded" ]; then
        echo "  • Redis: 2-5 minutes"
    fi
    exit 1
fi
