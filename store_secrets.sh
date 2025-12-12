#!/bin/bash
# store_secrets.sh
# Script para almacenar todos los secretos en Azure Key Vault

set -e

# Configuración
KEY_VAULT_NAME="kv-netops-hub-prd-usc"
SUBSCRIPTION="3299abb4-876d-4894-a305-2a438b0c7cfb"
POSTGRES_SERVER="psql-certmgr-prd-usc"
POSTGRES_USER="certmgradmin"
POSTGRES_PASSWORD="CertMgr2025!Secure#Pass"
POSTGRES_DB="certmanager"
REDIS_NAME="redis-certmgr-prd-usc"
RG_CERTMGR="rg-netops-certmgr-prd-usc"

echo "=========================================="
echo "Storing secrets in Key Vault"
echo "Key Vault: $KEY_VAULT_NAME"
echo "=========================================="

# 1. PostgreSQL Connection String
echo ""
echo "1/6 Storing PostgreSQL connection string..."
POSTGRES_FQDN=$(az postgres flexible-server show --name $POSTGRES_SERVER --resource-group $RG_CERTMGR --subscription $SUBSCRIPTION --query "fullyQualifiedDomainName" -o tsv)
POSTGRES_CONN_STR="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_FQDN}:5432/${POSTGRES_DB}?sslmode=require"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "postgres-connection-string" \
  --value "$POSTGRES_CONN_STR" \
  --output none

echo "✅ PostgreSQL connection string stored"

# 2. Redis Connection String
echo ""
echo "2/6 Waiting for Redis to be ready and getting connection string..."
# Esperar a que Redis esté listo
while true; do
  STATUS=$(az redis show --name $REDIS_NAME --resource-group $RG_CERTMGR --subscription $SUBSCRIPTION --query "provisioningState" -o tsv 2>/dev/null)
  if [ "$STATUS" = "Succeeded" ]; then
    break
  else
    echo "   Redis status: $STATUS - waiting 10 seconds..."
    sleep 10
  fi
done

REDIS_HOST=$(az redis show --name $REDIS_NAME --resource-group $RG_CERTMGR --subscription $SUBSCRIPTION --query "hostName" -o tsv)
REDIS_PORT=$(az redis show --name $REDIS_NAME --resource-group $RG_CERTMGR --subscription $SUBSCRIPTION --query "sslPort" -o tsv)
REDIS_KEY=$(az redis list-keys --name $REDIS_NAME --resource-group $RG_CERTMGR --subscription $SUBSCRIPTION --query "primaryKey" -o tsv)
REDIS_CONN_STR="rediss://:${REDIS_KEY}@${REDIS_HOST}:${REDIS_PORT}/0?ssl_cert_reqs=required"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "redis-connection-string" \
  --value "$REDIS_CONN_STR" \
  --output none

echo "✅ Redis connection string stored"

# 3. Application Insights Key
echo ""
echo "3/6 Storing Application Insights connection string..."
APP_INSIGHTS_KEY="4944bcb5-5096-4db4-b67c-6eea53dcb568"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "appinsights-instrumentation-key" \
  --value "$APP_INSIGHTS_KEY" \
  --output none

echo "✅ Application Insights key stored"

# 4. JWT Secret Key (generar uno nuevo)
echo ""
echo "4/6 Generating and storing JWT secret key..."
JWT_SECRET=$(openssl rand -base64 32)

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "jwt-secret-key" \
  --value "$JWT_SECRET" \
  --output none

echo "✅ JWT secret key stored"

# 5. Encryption Key para datos sensibles
echo ""
echo "5/6 Generating and storing encryption key..."
ENCRYPTION_KEY=$(openssl rand -base64 32)

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "data-encryption-key" \
  --value "$ENCRYPTION_KEY" \
  --output none

echo "✅ Encryption key stored"

# 6. Admin Initial Password
echo ""
echo "6/6 Storing admin initial password..."
ADMIN_PASSWORD="Admin2025!InitialPass"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --subscription $SUBSCRIPTION \
  --name "admin-initial-password" \
  --value "$ADMIN_PASSWORD" \
  --output none

echo "✅ Admin initial password stored"

echo ""
echo "=========================================="
echo "✅ All secrets stored successfully!"
echo "=========================================="
echo ""
echo "Secrets stored:"
echo "  - postgres-connection-string"
echo "  - redis-connection-string"
echo "  - appinsights-instrumentation-key"
echo "  - jwt-secret-key"
echo "  - data-encryption-key"
echo "  - admin-initial-password"
echo ""
echo "To retrieve a secret:"
echo "  az keyvault secret show --vault-name $KEY_VAULT_NAME --name <secret-name> --query value -o tsv"
