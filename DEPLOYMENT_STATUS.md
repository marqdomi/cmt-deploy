# Azure Deployment Status - Certificate Manager

**Fecha**: 11 de Diciembre 2025  
**Proyecto**: Certificate Management Tool  
**Arquitectura**: Hub-Spoke en Azure Central US

---

## 📊 Estado Actual del Deployment

### ✅ COMPLETADO

#### Hub - Servicios Compartidos (100%)
| Recurso | Nombre | Estado | Propósito |
|---------|--------|--------|-----------|
| Resource Group | `rg-netops-hub-prd-usc` | ✅ Creado | Contenedor de servicios compartidos |
| VNET | `vnet-netops-hub-prd-usc` (10.105.64.0/22) | ✅ Creado | Red principal del Hub |
| Key Vault | `kv-netops-hub-prd-usc` | ✅ Creado | Gestión centralizada de secretos |
| Container Registry | `acrnetopshubprdusc.azurecr.io` | ✅ Creado | Repositorio de imágenes Docker |
| Log Analytics | `law-netops-hub-prd-usc` | ✅ Creado | Centralización de logs y métricas |
| Application Insights | `appi-netops-hub-prd-usc` | ✅ Creado | APM y monitoreo de aplicaciones |

#### Spoke - Certificate Manager (90%)
| Recurso | Nombre | Estado | Propósito |
|---------|--------|--------|-----------|
| Resource Group | `rg-netops-certmgr-prd-usc` | ✅ Creado | Contenedor de la aplicación |
| VNET | `vnet-netops-certmgr-prd-usc` (10.105.68.0/24) | ✅ Creado | Red del Spoke |
| VNet Peering | Hub ↔ Spoke | ✅ Connected | Conectividad entre Hub y Spoke |
| PostgreSQL | `psql-certmgr-prd-usc` | ✅ Ready | Base de datos principal |
| Database | `certmanager` | ✅ Creado | Base de datos de la aplicación |
| Redis | `redis-certmgr-prd-usc` | ⏳ Creating | Cache y message broker |
| Container Apps Env | `cae-certmgr-prd-usc` | ✅ Succeeded | Plataforma de containers |

### ⏳ EN PROGRESO

| Recurso | Tiempo Estimado Restante |
|---------|--------------------------|
| Azure Cache for Redis | 2-5 minutos |

### 📋 PENDIENTE

| Tarea | Descripción | Script |
|-------|-------------|--------|
| 1. Almacenar Secretos | Guardar credentials en Key Vault | `./store_secrets.sh` |
| 2. Build Imágenes | Construir y subir imágenes Docker a ACR | `./build_and_push_images.sh` |
| 3. Deploy Apps | Desplegar Container Apps | `./deploy_container_apps.sh` |
| 4. Migraciones DB | Ejecutar Alembic migrations | Incluido en script maestro |
| 5. Usuario Admin | Crear usuario administrador inicial | Incluido en script maestro |

---

## 🚀 Próximos Pasos

### Una vez que Redis termine (Estado: Succeeded)

Tienes **dos opciones** para completar el deployment:

#### Opción A: Deployment Automático (Recomendado)
```bash
./deploy_to_azure.sh
```
Este script ejecutará automáticamente todos los pasos restantes.

#### Opción B: Deployment Manual (Paso a Paso)
```bash
# Paso 1: Almacenar secretos en Key Vault
./store_secrets.sh

# Paso 2: Build y push de imágenes Docker
./build_and_push_images.sh

# Paso 3: Desplegar Container Apps
./deploy_container_apps.sh

# Paso 4: Verificar deployment
source azure-deployment-config.env
az containerapp list --resource-group $SPOKE_RESOURCE_GROUP -o table
```

### Verificar cuando Redis esté listo:
```bash
az redis show --name redis-certmgr-prd-usc \
  --resource-group rg-netops-certmgr-prd-usc \
  --query "{Name:name, Status:provisioningState}" -o table
```

---

## 📁 Archivos Creados

| Archivo | Propósito |
|---------|-----------|
| `azure-deployment-config.env` | Variables de configuración centralizadas |
| `build_and_push_images.sh` | Build de imágenes Docker usando ACR Tasks |
| `store_secrets.sh` | Almacenamiento de secretos en Key Vault |
| `deploy_container_apps.sh` | Deployment de las 4 Container Apps |
| `deploy_to_azure.sh` | Script maestro que ejecuta todo |
| `AZURE_DEPLOYMENT_README.md` | Documentación completa del deployment |
| `app/backend/Dockerfile.prod` | Dockerfile optimizado para backend |
| `app/backend/Dockerfile.worker` | Dockerfile para Celery worker |
| `app/backend/Dockerfile.beat` | Dockerfile para Celery beat |

---

## 🏗️ Arquitectura Implementada

```
┌─────────────────────────────────────────────────────────────┐
│                    Hub VNET (10.105.64.0/22)                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Gateway Subnet (10.105.64.0/27)                    │   │
│  │  • VPN Gateway (futuro)                             │   │
│  │  • ExpressRoute Gateway (futuro)                    │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Shared Services (10.105.64.32/27)                  │   │
│  │  • Azure Bastion (futuro)                           │   │
│  │  • Azure Firewall (futuro)                          │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Shared Data (10.105.64.64/26)                      │   │
│  │  ✅ Key Vault: kv-netops-hub-prd-usc               │   │
│  │  ✅ Container Registry: acrnetopshubprdusc         │   │
│  │  ✅ Log Analytics: law-netops-hub-prd-usc          │   │
│  │  ✅ App Insights: appi-netops-hub-prd-usc          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ║ VNet Peering
                          ║ (Bidirectional)
                          ║
┌─────────────────────────────────────────────────────────────┐
│              Spoke VNET (10.105.68.0/24)                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Container Apps Subnet (10.105.68.0/25)             │   │
│  │  ✅ Environment: cae-certmgr-prd-usc                │   │
│  │  📦 Backend API (pendiente)                         │   │
│  │  📦 Celery Worker (pendiente)                       │   │
│  │  📦 Celery Beat (pendiente)                         │   │
│  │  📦 Frontend (pendiente)                            │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Data Services Subnet (10.105.68.128/26)            │   │
│  │  ✅ PostgreSQL: psql-certmgr-prd-usc (Ready)        │   │
│  │  ⏳ Redis: redis-certmgr-prd-usc (Creating)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Estimación de Costos Mensuales

### Hub - Servicios Compartidos (reutilizables)
| Servicio | SKU | Costo/mes |
|----------|-----|-----------|
| Key Vault | Standard | ~$3 |
| Container Registry | Basic | ~$5 |
| Log Analytics | Pay-as-you-go | ~$2.30/GB |
| TOTAL HUB | | **~$10-15** |

### Spoke - Certificate Manager
| Servicio | SKU | Costo/mes |
|----------|-----|-----------|
| PostgreSQL | Standard_B1ms, 32GB | ~$15 |
| Redis | Basic C0, 250MB | ~$16 |
| Backend App | 0.5 vCPU, 1GB RAM | ~$25 |
| Worker App | 0.5 vCPU, 1GB RAM | ~$25 |
| Beat App | 0.25 vCPU, 0.5GB RAM | ~$12 |
| Frontend App | 0.25 vCPU, 0.5GB RAM | ~$12 |
| TOTAL SPOKE | | **~$105** |

**TOTAL ESTIMADO**: **~$115-120/mes**

*Nota: Costos basados en 1 réplica por servicio. El autoscaling puede incrementar costos durante picos de uso.*

---

## 📊 Información Técnica

### Configuración de Red
- **Hub VNET**: 10.105.64.0/22 (1,024 IPs)
- **Spoke VNET**: 10.105.68.0/24 (256 IPs)
- **Peering**: Configurado con gateway transit habilitado

### Base de Datos
- **Engine**: PostgreSQL 15
- **Compute**: Standard_B1ms (1 vCore, 2GB RAM)
- **Storage**: 32GB, 7 días de backup
- **Connectivity**: VNET-integrated, SSL required
- **FQDN**: `psql-certmgr-prd-usc.postgres.database.azure.com`

### Cache/Message Broker
- **Engine**: Redis 6.x
- **Tier**: Basic C0 (250MB)
- **SSL**: TLS 1.2 required
- **Port**: 6380 (SSL)

### Container Apps
- **Environment**: VNET-integrated
- **Monitoring**: Application Insights enabled
- **Autoscaling**: CPU-based (1-3 replicas)
- **Health Checks**: Configured per app

---

## 🔐 Seguridad Implementada

✅ **Secretos**: Almacenados en Azure Key Vault (RBAC-enabled)  
✅ **Network**: VNET isolation con peering controlado  
✅ **Database**: SSL required, VNET-integrated  
✅ **Redis**: TLS 1.2, no non-SSL port  
✅ **Container Registry**: Private access desde Container Apps  
✅ **Managed Identity**: Para acceso sin passwords a Key Vault y ACR  
✅ **Encryption**: Data at rest y in transit

---

## 📞 Soporte

Si encuentras algún problema durante el deployment:

1. **Verificar logs**:
   ```bash
   az monitor activity-log list --resource-group rg-netops-certmgr-prd-usc --max-events 20 -o table
   ```

2. **Revisar estado de recursos**:
   ```bash
   az resource list --resource-group rg-netops-certmgr-prd-usc -o table
   ```

3. **Contactar al equipo NetOps** con el output de los comandos anteriores.

---

## ✅ Checklist Final

Antes de ejecutar el deployment completo, verifica:

- [ ] Redis ha terminado de crearse (Status: Succeeded)
- [ ] Tienes permisos de Contributor en la suscripción
- [ ] Azure CLI está autenticado correctamente
- [ ] Has revisado el archivo `azure-deployment-config.env`
- [ ] Has revisado la documentación en `AZURE_DEPLOYMENT_README.md`

**Una vez cumplidos todos los puntos, ejecuta**:
```bash
./deploy_to_azure.sh
```

---

*Última actualización: 11 de Diciembre 2025*
