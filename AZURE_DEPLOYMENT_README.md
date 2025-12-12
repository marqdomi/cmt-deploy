# Certificate Manager - Azure Deployment Guide

## Resumen de la Arquitectura

Esta solución utiliza un modelo **Hub-Spoke** en Azure para proporcionar una plataforma escalable y reutilizable para múltiples aplicaciones del equipo NetOps.

### Topología de Red

```
Hub VNET (10.105.64.0/22)
├─ Gateway Subnet (10.105.64.0/27) - Para VPN/ExpressRoute futuro
├─ Shared Services (10.105.64.32/27) - Bastion, Firewall (futuro)
└─ Shared Data (10.105.64.64/26) - Key Vault, Container Registry

Spoke VNET (10.105.68.0/24) - Certificate Manager
├─ Container Apps (10.105.68.0/25) - Aplicaciones containerizadas
└─ Data Services (10.105.68.128/26) - PostgreSQL, Redis

Peering: Hub ↔ Spoke (Bidireccional, Connected)
```

### Componentes Desplegados

#### Hub (Servicios Compartidos)
- **Resource Group**: `rg-netops-hub-prd-usc`
- **Azure Key Vault**: `kv-netops-hub-prd-usc` - Gestión centralizada de secretos
- **Container Registry**: `acrnetopshubprdusc.azurecr.io` - Repositorio de imágenes Docker
- **Log Analytics**: `law-netops-hub-prd-usc` - Centralización de logs
- **Application Insights**: `appi-netops-hub-prd-usc` - Monitoreo de aplicaciones

#### Spoke (Certificate Manager)
- **Resource Group**: `rg-netops-certmgr-prd-usc`
- **PostgreSQL Flexible Server**: `psql-certmgr-prd-usc` - Base de datos principal
- **Azure Cache for Redis**: `redis-certmgr-prd-usc` - Cache y message broker
- **Container Apps Environment**: `cae-certmgr-prd-usc` - Plataforma de containers
- **Container Apps**:
  - `ca-certmgr-backend-prd` - FastAPI REST API
  - `ca-certmgr-worker-prd` - Celery workers para tareas asíncronas
  - `ca-certmgr-beat-prd` - Celery Beat para tareas programadas
  - `ca-certmgr-frontend-prd` - React SPA

## Prerequisites

1. **Azure CLI** instalado y autenticado
   ```bash
   az login
   az account set --subscription "Solera-Prod-Core_Infrastructure"
   ```

2. **Permisos necesarios**:
   - Contributor en la suscripción
   - User Access Administrator (para asignar roles a Managed Identity)

3. **Variables de entorno** (opcional):
   El archivo `azure-deployment-config.env` contiene todas las configuraciones necesarias.

## Proceso de Deployment

### Opción 1: Deployment Automático (Recomendado)

Ejecuta el script maestro que realizará todos los pasos automáticamente:

```bash
cd /Users/marco.dominguez/Projects/Version\ funcional/cmt-deploy
./deploy_to_azure.sh
```

Este script ejecutará en orden:
1. Build y push de imágenes Docker a ACR
2. Almacenamiento de secretos en Key Vault
3. Deployment de Container Apps
4. Migraciones de base de datos
5. Creación de usuario admin inicial

### Opción 2: Deployment Manual (Paso a Paso)

#### Paso 1: Build y Push de Imágenes

```bash
./build_and_push_images.sh
```

Este proceso usa **Azure Container Registry Tasks** para construir las imágenes directamente en la nube (no requiere Docker local):
- `certmgr-backend:latest`
- `certmgr-worker:latest`
- `certmgr-beat:latest`
- `certmgr-frontend:latest`

Tiempo estimado: 10-15 minutos

#### Paso 2: Almacenar Secretos en Key Vault

**IMPORTANTE**: Espera a que Redis termine de aprovisionarse antes de ejecutar este paso.

Verifica el estado de Redis:
```bash
az redis show --name redis-certmgr-prd-usc \
  --resource-group rg-netops-certmgr-prd-usc \
  --query "{Name:name, Status:provisioningState}" -o table
```

Una vez que el estado sea `Succeeded`, ejecuta:

```bash
./store_secrets.sh
```

Este script almacenará en Key Vault:
- Connection string de PostgreSQL
- Connection string de Redis
- JWT secret key
- Encryption key para datos sensibles
- Application Insights key
- Password inicial del admin

#### Paso 3: Desplegar Container Apps

```bash
./deploy_container_apps.sh
```

Este script:
1. Crea un Managed Identity para las Container Apps
2. Otorga permisos para acceder a Key Vault y ACR
3. Despliega las 4 Container Apps con sus configuraciones
4. Configura autoscaling y health checks

Tiempo estimado: 10-15 minutos

#### Paso 4: Migraciones de Base de Datos

```bash
# Cargar configuración
source azure-deployment-config.env

# Ejecutar migraciones
az containerapp exec \
  --name ca-certmgr-backend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --command "/bin/sh -c 'cd /app && alembic upgrade head'"

# Crear usuario admin inicial
az containerapp exec \
  --name ca-certmgr-backend-prd \
  --resource-group $SPOKE_RESOURCE_GROUP \
  --subscription $AZURE_SUBSCRIPTION_ID \
  --command "/bin/sh -c 'cd /app && python create_initial_users.py'"
```

## Verificación del Deployment

### Obtener URLs de la Aplicación

```bash
# Frontend
az containerapp show --name ca-certmgr-frontend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --query properties.configuration.ingress.fqdn -o tsv

# Backend API
az containerapp show --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --query properties.configuration.ingress.fqdn -o tsv
```

### Verificar Salud de los Servicios

```bash
# Listar todas las Container Apps
az containerapp list \
  --resource-group rg-netops-certmgr-prd-usc \
  --query "[].{Name:name, Status:properties.runningStatus, Replicas:properties.runningStatus}" \
  -o table

# Ver logs del backend
az containerapp logs show \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --follow
```

### Pruebas Básicas

```bash
# Obtener backend URL
BACKEND_URL=$(az containerapp show --name ca-certmgr-backend-prd --resource-group rg-netops-certmgr-prd-usc --query properties.configuration.ingress.fqdn -o tsv)

# Health check
curl https://$BACKEND_URL/healthz

# API docs
echo "Swagger UI: https://$BACKEND_URL/docs"
```

## Credenciales Iniciales

**Username**: `admin`  
**Password**: `Admin2025!InitialPass`

⚠️ **IMPORTANTE**: Cambia la contraseña del admin inmediatamente después del primer login.

## Monitoreo y Troubleshooting

### Application Insights

Accede al portal de Azure y navega a `appi-netops-hub-prd-usc` para:
- Ver métricas de rendimiento
- Analizar logs de aplicación
- Configurar alertas

### Logs en Tiempo Real

```bash
# Backend
az containerapp logs show --name ca-certmgr-backend-prd --resource-group rg-netops-certmgr-prd-usc --follow

# Worker
az containerapp logs show --name ca-certmgr-worker-prd --resource-group rg-netops-certmgr-prd-usc --follow

# Beat
az containerapp logs show --name ca-certmgr-beat-prd --resource-group rg-netops-certmgr-prd-usc --follow
```

### Conectar a PostgreSQL

```bash
# Obtener connection string
az keyvault secret show --vault-name kv-netops-hub-prd-usc --name postgres-connection-string --query value -o tsv

# O usar psql directamente
POSTGRES_PASS=$(az keyvault secret show --vault-name kv-netops-hub-prd-usc --name postgres-connection-string --query value -o tsv | cut -d'@' -f1 | cut -d':' -f3)
psql "host=psql-certmgr-prd-usc.postgres.database.azure.com port=5432 dbname=certmanager user=certmgradmin password=$POSTGRES_PASS sslmode=require"
```

## Actualización de la Aplicación

Para actualizar a una nueva versión:

```bash
# 1. Build nueva versión de imágenes
./build_and_push_images.sh v1.1.0

# 2. Actualizar Container Apps
az containerapp update \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --image acrnetopshubprdusc.azurecr.io/certmgr-backend:v1.1.0

# Repetir para worker, beat y frontend
```

## Scaling

### Manual Scaling

```bash
# Escalar backend
az containerapp update \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --min-replicas 2 \
  --max-replicas 5
```

### Auto-scaling (ya configurado)

Las Container Apps están configuradas con:
- **Backend**: 1-3 réplicas (CPU-based autoscaling)
- **Worker**: 1-3 réplicas
- **Beat**: 1 réplica fija (scheduler)
- **Frontend**: 1-3 réplicas

## Costos Estimados

### Servicios Hub (compartidos entre apps)
- Key Vault: ~$3/mes
- Container Registry (Basic): ~$5/mes
- Log Analytics: ~$2.30/GB + ~$0.10/GB retention
- Application Insights: Incluido en Log Analytics

### Servicios Spoke (Certificate Manager)
- PostgreSQL (Standard_B1ms): ~$15/mes
- Redis (Basic C0): ~$16/mes
- Container Apps:
  - Backend (0.5 vCPU, 1GB): ~$25/mes (1 réplica)
  - Worker (0.5 vCPU, 1GB): ~$25/mes (1 réplica)
  - Beat (0.25 vCPU, 0.5GB): ~$12/mes
  - Frontend (0.25 vCPU, 0.5GB): ~$12/mes

**Total estimado**: ~$115/mes (sin incluir egress y storage)

## Próximos Pasos

1. **Configurar VPN Gateway** en Hub para conectividad con on-premises
2. **Implementar Azure Firewall** para seguridad centralizada
3. **Configurar Custom Domain** para la aplicación
4. **Implementar Azure Front Door** para CDN y WAF
5. **Configurar Backup automático** de PostgreSQL
6. **Implementar Azure Monitor Alerts** para notificaciones

## Soporte

Para problemas o preguntas:
1. Revisar logs en Application Insights
2. Verificar Container Apps logs
3. Contactar al equipo NetOps

## Referencias

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Hub-Spoke Network Topology](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
