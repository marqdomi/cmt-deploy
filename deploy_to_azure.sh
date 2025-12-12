#!/bin/bash
# deploy_to_azure.sh
# Script maestro para desplegar Certificate Manager en Azure

set -e

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Certificate Manager - Azure Deployment"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Build and push Docker images to ACR"
echo "  2. Store secrets in Azure Key Vault"
echo "  3. Deploy Container Apps"
echo "  4. Run database migrations"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Paso 1: Build y push de imágenes
echo ""
echo "=========================================="
echo "Step 1/4: Building and pushing images..."
echo "=========================================="
./build_and_push_images.sh

# Paso 2: Almacenar secretos
echo ""
echo "=========================================="
echo "Step 2/4: Storing secrets in Key Vault..."
echo "=========================================="
./store_secrets.sh

# Paso 3: Desplegar Container Apps
echo ""
echo "=========================================="
echo "Step 3/4: Deploying Container Apps..."
echo "=========================================="
./deploy_container_apps.sh

# Paso 4: Migraciones de base de datos
echo ""
echo "=========================================="
echo "Step 4/4: Running database migrations..."
echo "=========================================="
source azure-deployment-config.env

echo "Running Alembic migrations on backend container..."
az containerapp exec \
  --name ca-certmgr-backend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --command "/bin/sh -c 'cd /app && alembic upgrade head'"

echo "✅ Migrations completed"

# Crear usuario inicial
echo ""
echo "Creating initial admin user..."
az containerapp exec \
  --name ca-certmgr-backend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --command "/bin/sh -c 'cd /app && python create_initial_users.py'"

echo "✅ Initial admin user created"

# Mostrar URLs finales
echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
BACKEND_URL=$(az containerapp show --name ca-certmgr-backend-prd --resource-group $SPOKE_RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
FRONTEND_URL=$(az containerapp show --name ca-certmgr-frontend-prd --resource-group $SPOKE_RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)

echo "Application is now running at:"
echo ""
echo "  🌐 Frontend:  https://$FRONTEND_URL"
echo "  🔧 Backend API: https://$BACKEND_URL"
echo "  📊 Swagger Docs: https://$BACKEND_URL/docs"
echo ""
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: Admin2025!InitialPass"
echo ""
echo "⚠️  IMPORTANT: Change the admin password after first login!"
echo ""
