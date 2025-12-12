# ✅ Deployment Completado - Certificate Manager v2.5

**Fecha de Deployment:** 12 de Diciembre, 2025  
**Estado:** ✅ Completado Exitosamente

---

## 🎯 URLs de Acceso

### Frontend (Aplicación Web)
```
https://ca-certmgr-frontend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io
```

### Backend API (Swagger Docs)
```
https://ca-certmgr-backend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io/docs
```

### Backend Health Check
```
https://ca-certmgr-backend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io
```

---

## 🔐 Usuarios Creados

Los siguientes usuarios fueron creados automáticamente:

| Usuario  | Rol       | Password       |
|----------|-----------|----------------|
| admin    | admin     | R0undt0w3r!    |
| operator | operator  | R0undt0w3r!    |
| viewer   | viewer    | R0undt0w3r!    |

> ⚠️ **IMPORTANTE:** Cambiar las contraseñas después del primer login.

---

## 📦 Componentes Desplegados

### Container Apps

| Componente | Estado | Recursos | Escalado |
|------------|--------|----------|----------|
| **Backend API** | ✅ Running | 0.5 vCPU, 1GB RAM | 1-3 replicas |
| **Celery Worker** | ✅ Running | 0.5 vCPU, 1GB RAM | 1-3 replicas |
| **Celery Beat** | ✅ Running | 0.25 vCPU, 0.5GB RAM | 1 replica (fijo) |
| **Frontend** | ✅ Running | 0.25 vCPU, 0.5GB RAM | 1-3 replicas |

### Infraestructura

| Recurso | Estado | Detalles |
|---------|--------|----------|
| **PostgreSQL Flexible Server** | ✅ Ready | `psql-netops-certmgr-prd-usc.postgres.database.azure.com` |
| **Azure Cache for Redis** | ✅ Running | `redis-netops-certmgr-prd-usc.redis.cache.windows.net:6380` |
| **Key Vault** | ✅ Active | `kv-netops-certmgr-prd-usc` |
| **Container Registry** | ✅ Active | `acrnetopshubprdusc.azurecr.io` |
| **Application Insights** | ✅ Active | Instrumentation Key configurado |
| **VNet Peering** | ✅ Connected | `vnet-netops-certmgr-prd-usc` ↔ Hub VNet |

---

## 🔧 Configuración Completada

### ✅ Migraciones de Base de Datos
Todas las migraciones de Alembic fueron aplicadas exitosamente:
- ✅ Esquema inicial (v2.5)
- ✅ Tablas de cache de perfiles (Fase 3 - DEPRECADO)
- ✅ Campos VIP en ssl_profile_vips_cache (Fase 3 - DEPRECADO)
- ✅ Device facts fields
- ✅ Cluster key y is_primary_preferred
- ✅ Discovery tables
- ✅ CSR generator enhancements
- ✅ Renewal tracking y audit log

### ✅ Secrets Almacenados en Key Vault
- `postgres-connection-string` - Conexión PostgreSQL con SSL
- `redis-connection-string` - Conexión Redis con SSL
- `jwt-secret-key` - Clave para JWT tokens
- `data-encryption-key` - Clave para encriptación de datos sensibles
- `appinsights-instrumentation-key` - Application Insights
- `admin-initial-password` - Password inicial de administrador

### ✅ Managed Identity Configurado
- **Identity Name:** `id-certmgr-prd-usc`
- **Client ID:** `5555f7d7-6aaf-4308-8623-d48e809ac9c9`
- **Roles Asignados:**
  - ✅ Key Vault Secrets User (lectura de secretos)
  - ✅ AcrPull (pull de imágenes desde ACR)

### ✅ Imágenes Docker Construidas
Todas las imágenes fueron construidas usando Azure ACR Tasks (cloud-based build):

```
acrnetopshubprdusc.azurecr.io/certmgr-backend:latest
  └─ Digest: sha256:19179a...
  └─ Build Time: 78 segundos

acrnetopshubprdusc.azurecr.io/certmgr-worker:latest
  └─ Digest: sha256:c86a7e...
  └─ Build Time: ~80 segundos

acrnetopshubprdusc.azurecr.io/certmgr-beat:latest
  └─ Digest: sha256:3da859...
  └─ Build Time: 103 segundos

acrnetopshubprdusc.azurecr.io/certmgr-frontend:latest
  └─ Digest: sha256:ea1f10...
  └─ Build Time: 73 segundos
  └─ Bundle Size: ~1.7MB
```

---

## 🚀 Próximos Pasos

### 1. Acceso Inicial
```bash
# Abrir el frontend
open "https://ca-certmgr-frontend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io"

# Login con usuario admin
Usuario: admin
Password: Admin2025!InitialPass
```

### 2. Cambiar Contraseñas
Inmediatamente después del primer login, cambiar las contraseñas de todos los usuarios desde el panel de administración.

### 3. Configurar Dispositivos F5
- Ir a la sección de **Devices** en el frontend
- Importar el inventario de dispositivos F5
- Configurar las credenciales de acceso

### 4. Verificar Workers
```bash
# Ver logs del Celery Worker
az containerapp logs show \
  --name ca-certmgr-worker-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --tail 50

# Ver logs del Celery Beat (scheduler)
az containerapp logs show \
  --name ca-certmgr-beat-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --tail 50
```

### 5. Monitoreo y Observabilidad
- **Application Insights:** Portal Azure → Application Insights → `appi-netops-certmgr-prd-usc`
- **Container Apps Metrics:** Portal Azure → Container Apps → Metrics
- **Logs en tiempo real:**
  ```bash
  az containerapp logs show \
    --name ca-certmgr-backend-prd \
    --resource-group rg-netops-certmgr-prd-usc \
    --follow
  ```

---

## 🔍 Health Checks

### Backend API
```bash
curl https://ca-certmgr-backend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io
# Esperado: {"message":"Certificate Management Tool V2 - Backend is running!"}
```

### Swagger Documentation
```
https://ca-certmgr-backend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io/docs
```

### Frontend
```bash
curl -I https://ca-certmgr-frontend-prd.wonderfulsand-7d6f91a8.centralus.azurecontainerapps.io
# Esperado: HTTP/2 200
```

---

## 📊 Costos Estimados (Mensual)

| Recurso | Tier/SKU | Costo Estimado |
|---------|----------|----------------|
| PostgreSQL Flexible | Burstable B1ms | ~$15-20 USD |
| Redis Cache | Basic C1 (1GB) | ~$45 USD |
| Container Apps | Consumption | ~$30-50 USD (depende del uso) |
| Key Vault | Standard | ~$3 USD + transacciones |
| Application Insights | 5GB incluidos | ~$5-10 USD (depende del volumen) |
| Container Registry | Basic | ~$5 USD |
| VNet & Peering | - | ~$5 USD |
| **TOTAL ESTIMADO** | | **~$110-140 USD/mes** |

> 💡 **Nota:** Los Container Apps escalan automáticamente a 0 cuando no hay tráfico, reduciendo costos.

---

## 🛠️ Comandos Útiles

### Ver todos los Container Apps
```bash
az containerapp list \
  --resource-group rg-netops-certmgr-prd-usc \
  --query "[].{Name:name, Status:properties.runningStatus}" \
  -o table
```

### Reiniciar un Container App
```bash
az containerapp revision restart \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --revision $(az containerapp show --name ca-certmgr-backend-prd --resource-group rg-netops-certmgr-prd-usc --query properties.latestRevisionName -o tsv)
```

### Escalar manualmente
```bash
az containerapp update \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --min-replicas 2 \
  --max-replicas 5
```

### Acceder a un container (debug)
```bash
az containerapp exec \
  --name ca-certmgr-backend-prd \
  --resource-group rg-netops-certmgr-prd-usc \
  --command /bin/bash
```

---

## 📝 Notas Importantes

### Seguridad
- ✅ Todas las conexiones usan TLS/SSL (PostgreSQL, Redis, HTTPS)
- ✅ Managed Identity para autenticación sin contraseñas
- ✅ Key Vault para almacenamiento seguro de secretos
- ✅ RBAC configurado correctamente
- ✅ VNet peering para comunicación privada con recursos existentes
- ⚠️ **TODO:** Cambiar contraseñas de usuarios después del primer login

### Monitoreo
- ✅ Application Insights configurado para telemetría
- ✅ Logs centralizados en Azure Monitor
- ✅ Health checks configurados en todos los containers
- ✅ Auto-scaling basado en CPU/memoria/requests

### Backup y Disaster Recovery
- PostgreSQL: Backup automático habilitado (7 días retención)
- Redis: Persistencia RDB configurada
- Container Images: Almacenadas en ACR con Geo-replication opcional

### Deprecación (Fase 3)
Las siguientes tablas están marcadas como DEPRECADAS y serán removidas en una futura versión:
- `ssl_profiles_cache`
- `ssl_profile_vips_cache`
- Ver `FASE3_DEPRECATION.md` para más detalles

---

## 🎉 Deployment Exitoso

El deployment de **Certificate Manager v2.5** ha sido completado exitosamente en Azure Container Apps con toda la infraestructura en producción.

**Environment:** Production  
**Region:** Central US  
**Resource Group:** rg-netops-certmgr-prd-usc  
**Deployment Date:** 2025-12-12

---

## 📞 Soporte y Contacto

Para problemas o preguntas:
1. Revisar los logs en Application Insights
2. Consultar la documentación en `/app/backend/README.md`
3. Contactar al equipo de desarrollo
