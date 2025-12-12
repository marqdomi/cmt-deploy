#!/bin/bash
# build_and_push_images.sh
# Script para construir y subir imágenes Docker usando Azure ACR Tasks

set -e  # Salir si hay errores

# Configuración
ACR_NAME="acrnetopshubprdusc"
SUBSCRIPTION="3299abb4-876d-4894-a305-2a438b0c7cfb"
TAG="${1:-latest}"  # Usar tag proporcionado o 'latest' por defecto

echo "=========================================="
echo "Building images with ACR Tasks"
echo "Registry: $ACR_NAME.azurecr.io"
echo "Tag: $TAG"
echo "=========================================="

# Cambiar al directorio app
cd "$(dirname "$0")/app"

echo ""
echo "1/4 Building Backend API..."
az acr build \
  --registry $ACR_NAME \
  --subscription $SUBSCRIPTION \
  --image certmgr-backend:$TAG \
  --file backend/Dockerfile.prod \
  backend/

echo ""
echo "2/4 Building Celery Worker..."
az acr build \
  --registry $ACR_NAME \
  --subscription $SUBSCRIPTION \
  --image certmgr-worker:$TAG \
  --file backend/Dockerfile.worker \
  backend/

echo ""
echo "3/4 Building Celery Beat..."
az acr build \
  --registry $ACR_NAME \
  --subscription $SUBSCRIPTION \
  --image certmgr-beat:$TAG \
  --file backend/Dockerfile.beat \
  backend/

echo ""
echo "4/4 Building Frontend..."
az acr build \
  --registry $ACR_NAME \
  --subscription $SUBSCRIPTION \
  --image certmgr-frontend:$TAG \
  --file frontend/Dockerfile.prod \
  --build-arg VITE_API_BASE_URL=/api \
  frontend/

echo ""
echo "=========================================="
echo "✅ All images built and pushed successfully!"
echo "=========================================="
echo ""
echo "Images available:"
echo "  - $ACR_NAME.azurecr.io/certmgr-backend:$TAG"
echo "  - $ACR_NAME.azurecr.io/certmgr-worker:$TAG"
echo "  - $ACR_NAME.azurecr.io/certmgr-beat:$TAG"
echo "  - $ACR_NAME.azurecr.io/certmgr-frontend:$TAG"
