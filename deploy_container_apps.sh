#!/bin/bash
# deploy_container_apps.sh
# Script para desplegar todas las Container Apps

set -e

# Cargar configuración
source "$(dirname "$0")/azure-deployment-config.env"

echo "=========================================="
echo "Deploying Container Apps"
echo "Environment: $CONTAINER_APP_ENV"
echo "Resource Group: $SPOKE_RESOURCE_GROUP"
echo "=========================================="

# Obtener ID del Managed Identity para Key Vault
echo ""
echo "Setting up Managed Identity for Key Vault access..."
IDENTITY_NAME="id-certmgr-prd-usc"

# Crear Managed Identity si no existe
if ! az identity show --name $IDENTITY_NAME --resource-group $SPOKE_RESOURCE_GROUP &>/dev/null; then
  echo "Creating Managed Identity..."
  az identity create \
    --name $IDENTITY_NAME \
    --resource-group $SPOKE_RESOURCE_GROUP \
    --location $SPOKE_LOCATION \
    --subscription $AZURE_SUBSCRIPTION_ID
fi

IDENTITY_ID=$(az identity show --name $IDENTITY_NAME --resource-group $SPOKE_RESOURCE_GROUP --query id -o tsv)
IDENTITY_CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $SPOKE_RESOURCE_GROUP --query clientId -o tsv)

echo "✅ Managed Identity: $IDENTITY_NAME"

# Dar permisos al Managed Identity para acceder a Key Vault (usando RBAC)
echo "Granting Key Vault access to Managed Identity..."
IDENTITY_PRINCIPAL_ID=$(az identity show --name $IDENTITY_NAME --resource-group $SPOKE_RESOURCE_GROUP --query principalId -o tsv)

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id $IDENTITY_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$HUB_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$HUB_KEY_VAULT \
  --output none 2>/dev/null || echo "Role already assigned"

echo "✅ Key Vault access granted"

# Dar permisos al Managed Identity para acceder a ACR
echo "Granting ACR pull access to Managed Identity..."
ACR_ID=$(az acr show --name $ACR_NAME --subscription $AZURE_SUBSCRIPTION_ID --query id -o tsv)
az role assignment create \
  --assignee $IDENTITY_CLIENT_ID \
  --role "AcrPull" \
  --scope $ACR_ID \
  --output none 2>/dev/null || echo "Role already assigned"

echo "✅ ACR pull access granted"

# Obtener secretos del Key Vault
echo ""
echo "Retrieving secrets from Key Vault..."
POSTGRES_CONN_STR=$(az keyvault secret show --vault-name $HUB_KEY_VAULT --name postgres-connection-string --query value -o tsv)
REDIS_CONN_STR=$(az keyvault secret show --vault-name $HUB_KEY_VAULT --name redis-connection-string --query value -o tsv)
JWT_SECRET=$(az keyvault secret show --vault-name $HUB_KEY_VAULT --name jwt-secret-key --query value -o tsv)
ENCRYPTION_KEY=$(az keyvault secret show --vault-name $HUB_KEY_VAULT --name data-encryption-key --query value -o tsv)

echo "✅ Secrets retrieved"

# 1. Desplegar Backend API
echo ""
echo "================================================"
echo "1/4 Deploying Backend API..."
echo "================================================"
az containerapp create \
  --name ca-certmgr-backend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --image ${ACR_LOGIN_SERVER}/certmgr-backend:latest \
  --target-port 8000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-identity $IDENTITY_ID \
  --user-assigned $IDENTITY_ID \
  --env-vars \
    "DATABASE_URL=secretref:postgres-conn" \
    "REDIS_URL=secretref:redis-conn" \
    "SECRET_KEY=secretref:jwt-secret" \
    "ENCRYPTION_KEY=secretref:encryption-key" \
    "ENVIRONMENT=production" \
    "LOG_LEVEL=INFO" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=${HUB_APP_INSIGHTS_KEY}" \
  --secrets \
    postgres-conn="$POSTGRES_CONN_STR" \
    redis-conn="$REDIS_CONN_STR" \
    jwt-secret="$JWT_SECRET" \
    encryption-key="$ENCRYPTION_KEY" \
  --tags Team=NetOps Environment=Production Application=CertificateManager Component=Backend

echo "✅ Backend API deployed"

# Obtener URL del backend
BACKEND_URL=$(az containerapp show --name ca-certmgr-backend-prd --resource-group $SPOKE_RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
echo "   Backend URL: https://$BACKEND_URL"

# 2. Desplegar Celery Worker
echo ""
echo "================================================"
echo "2/4 Deploying Celery Worker..."
echo "================================================"
az containerapp create \
  --name ca-certmgr-worker-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --image ${ACR_LOGIN_SERVER}/certmgr-worker:latest \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-identity $IDENTITY_ID \
  --user-assigned $IDENTITY_ID \
  --env-vars \
    "DATABASE_URL=secretref:postgres-conn" \
    "REDIS_URL=secretref:redis-conn" \
    "SECRET_KEY=secretref:jwt-secret" \
    "ENCRYPTION_KEY=secretref:encryption-key" \
    "ENVIRONMENT=production" \
    "LOG_LEVEL=INFO" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=${HUB_APP_INSIGHTS_KEY}" \
  --secrets \
    postgres-conn="$POSTGRES_CONN_STR" \
    redis-conn="$REDIS_CONN_STR" \
    jwt-secret="$JWT_SECRET" \
    encryption-key="$ENCRYPTION_KEY" \
  --tags Team=NetOps Environment=Production Application=CertificateManager Component=Worker

echo "✅ Celery Worker deployed"

# 3. Desplegar Celery Beat
echo ""
echo "================================================"
echo "3/4 Deploying Celery Beat..."
echo "================================================"
az containerapp create \
  --name ca-certmgr-beat-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --image ${ACR_LOGIN_SERVER}/certmgr-beat:latest \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-identity $IDENTITY_ID \
  --user-assigned $IDENTITY_ID \
  --env-vars \
    "DATABASE_URL=secretref:postgres-conn" \
    "REDIS_URL=secretref:redis-conn" \
    "ENVIRONMENT=production" \
    "LOG_LEVEL=INFO" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=${HUB_APP_INSIGHTS_KEY}" \
  --secrets \
    postgres-conn="$POSTGRES_CONN_STR" \
    redis-conn="$REDIS_CONN_STR" \
  --tags Team=NetOps Environment=Production Application=CertificateManager Component=Beat

echo "✅ Celery Beat deployed"

# 4. Desplegar Frontend
echo ""
echo "================================================"
echo "4/4 Deploying Frontend..."
echo "================================================"
az containerapp create \
  --name ca-certmgr-frontend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --image ${ACR_LOGIN_SERVER}/certmgr-frontend:latest \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-identity $IDENTITY_ID \
  --user-assigned $IDENTITY_ID \
  --env-vars \
    "VITE_API_URL=https://$BACKEND_URL" \
  --tags Team=NetOps Environment=Production Application=CertificateManager Component=Frontend

echo "✅ Frontend deployed"

# Obtener URL del frontend
FRONTEND_URL=$(az containerapp show --name ca-certmgr-frontend-prd --resource-group $SPOKE_RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "=========================================="
echo "✅ All Container Apps deployed successfully!"
echo "=========================================="
echo ""
echo "Application URLs:"
echo "  Frontend:  https://$FRONTEND_URL"
echo "  Backend:   https://$BACKEND_URL"
echo ""
echo "Next steps:"
echo "  1. Run database migrations"
echo "  2. Create initial admin user"
echo "  3. Test the application"
