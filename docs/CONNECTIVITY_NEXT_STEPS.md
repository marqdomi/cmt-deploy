# CMT Azure - Conectividad a F5s Solera
## Análisis de Opciones y Next Steps

**Fecha**: December 12, 2025  
**Estado**: Pendiente decisión de arquitectura

---

## 📊 Resumen del Estado Actual

### ✅ Lo que está funcionando:

| Componente | Estado | Detalles |
|------------|--------|----------|
| Container Apps Environment | ✅ Running | `cae-certmgr-prd-usc` |
| Backend API | ✅ Running | `ca-certmgr-backend-prd` |
| Celery Worker | ✅ Running | `ca-certmgr-worker-prd` - procesando tareas |
| Redis Cache | ✅ Connected | `redis-certmgr-prd-usc.redis.cache.windows.net` |
| PostgreSQL | ✅ Connected | `psql-certmgr-prd-usc.postgres.database.azure.com` |
| VNet CMT | ✅ Created | `vnet-netops-certmgr-prd-usc` (10.105.68.0/24) |
| vWAN Connection | ✅ Succeeded | `conn-certmgr-prd-usc` → centralus-hub |
| Credenciales F5 | ✅ Configuradas | Dispositivo de prueba con admin/* |

### ❌ El problema identificado:

```
Container Apps (Consumption workload profile)
     │
     │  El tráfico de EGRESS sale por infraestructura managed de Azure
     │  IP de salida: 172.169.204.232 (Azure managed, NO nuestra VNet)
     │
     ▼
   Internet  ──X──►  NO llega a F5s (10.119.8.245)
     │
     │  Las rutas del vWAN NO se aplican al tráfico de egress
     │  porque Container Apps Consumption NO usa UDR/VNet routing
     │
     ▼
   TIMEOUT al conectar a F5 management
```

### Causa raíz:
- Container Apps Environment está configurado con `internal: false`
- Workload profile: `Consumption` (no soporta UDR completo)
- El tráfico de **egress** (salida) usa infraestructura Azure managed
- Las rutas del vWAN/VNet **NO** se aplican al tráfico de salida de los containers

---

## 🔧 Opciones de Solución

### Opción A: Nuevo Container Apps Environment (Internal)

**Descripción**: Crear un nuevo Container Apps Environment con `internal: true` y workload profiles dedicados.

```
┌─────────────────────────────────────────────────────────────────┐
│  Nuevo Environment (Internal + Workload Profiles)               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Workload Profile: Dedicated (D4/D8)                    │   │
│  │  internal: true                                          │   │
│  │  VNet Integration: Full (egress via VNet)               │   │
│  │  UDR Support: ✅ Yes                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  Egress → VNet → vWAN Hub → VPN/ExpressRoute → F5s ✅          │
└─────────────────────────────────────────────────────────────────┘
```

| Aspecto | Detalle |
|---------|---------|
| **Esfuerzo** | Alto (2-4 horas) |
| **Costo adicional** | ~$70-150/mes (Dedicated D4) |
| **Cambios requeridos** | Recrear environment y re-deploy de todas las apps |
| **Downtime** | ~30-60 min durante migración |
| **Beneficios** | Control total de networking, UDR support, mejor seguridad |

**Comandos aproximados**:
```bash
# 1. Crear nuevo environment interno
az containerapp env create \
  --name cae-certmgr-internal-prd-usc \
  --resource-group rg-netops-certmgr-prd-usc \
  --location centralus \
  --infrastructure-subnet-resource-id "/subscriptions/.../snet-aca-certmgr-prd-usc" \
  --internal-only true \
  --enable-workload-profiles

# 2. Agregar workload profile dedicado
az containerapp env workload-profile add \
  --name cae-certmgr-internal-prd-usc \
  --resource-group rg-netops-certmgr-prd-usc \
  --workload-profile-name "Dedicated" \
  --workload-profile-type D4

# 3. Migrar las apps al nuevo environment
# (requiere recrear backend, worker, beat, frontend)
```

---

### Opción B: Azure Firewall + UDR

**Descripción**: Desplegar Azure Firewall en el NetOps Hub y crear User Defined Routes para forzar el tráfico a través del firewall.

```
┌─────────────────────────────────────────────────────────────────┐
│  CMT VNet                                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Route Table (UDR)                                       │   │
│  │  10.119.0.0/16 → Azure Firewall (10.105.64.x)           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  NetOps Hub VNet                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Azure Firewall                                          │   │
│  │  - DNAT/SNAT rules                                       │   │
│  │  - Network rules: Allow 10.119.0.0/16                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               ▼
                    vWAN Hub → VPN → F5s ✅
```

| Aspecto | Detalle |
|---------|---------|
| **Esfuerzo** | Medio-Alto (3-5 horas) |
| **Costo adicional** | ~$900-1,200/mes (Azure Firewall Standard) |
| **Cambios requeridos** | Deploy Firewall, crear UDRs, actualizar NSGs |
| **Downtime** | Mínimo (cambios de routing) |
| **Beneficios** | Logging centralizado, políticas de seguridad, sin recrear apps |

**Nota**: Requiere que el Container Apps Environment soporte UDR, lo cual necesita workload profiles.

---

### Opción C: VM Proxy/Jump Host

**Descripción**: Crear una VM en la VNet que actúe como proxy para las conexiones a los F5s.

```
┌─────────────────────────────────────────────────────────────────┐
│  CMT VNet                                                       │
│                                                                 │
│  ┌──────────────┐         ┌──────────────────────────────┐     │
│  │ Container    │  HTTP   │  VM Proxy (nginx/haproxy)    │     │
│  │ Apps         │ ──────► │  10.105.68.200               │     │
│  │ (Worker)     │ :8443   │  - Reverse proxy to F5s      │     │
│  └──────────────┘         └──────────────┬───────────────┘     │
│                                          │                      │
└──────────────────────────────────────────┼──────────────────────┘
                                           │ HTTPS :443
                                           ▼
                              vWAN → VPN → F5s (10.119.x.x) ✅
```

| Aspecto | Detalle |
|---------|---------|
| **Esfuerzo** | Medio (2-3 horas) |
| **Costo adicional** | ~$15-50/mes (VM B2s o B2ms) |
| **Cambios requeridos** | Deploy VM, configurar proxy, modificar código backend |
| **Downtime** | Ninguno |
| **Beneficios** | Solución rápida, bajo costo, fácil de implementar |

**Implementación**:
```bash
# 1. Crear VM en la subnet de datos
az vm create \
  --name vm-f5proxy-prd-usc \
  --resource-group rg-netops-certmgr-prd-usc \
  --vnet-name vnet-netops-certmgr-prd-usc \
  --subnet snet-data-certmgr-prd-usc \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys

# 2. Instalar nginx como reverse proxy
# 3. Configurar proxy pass a F5s
# 4. Actualizar código del backend para usar el proxy
```

**Cambio en el código** (ejemplo):
```python
# En lugar de conectar directamente al F5:
# f5_host = "10.119.8.245"

# Usar el proxy:
f5_proxy = "10.105.68.200"  # VM en nuestra VNet
f5_host = "10.119.8.245"    # Header X-F5-Target
```

---

### Opción D: Azure API Management (APIM)

**Descripción**: Usar Azure API Management con VNet integration como gateway para las llamadas a F5s.

| Aspecto | Detalle |
|---------|---------|
| **Esfuerzo** | Alto (4-6 horas) |
| **Costo adicional** | ~$150-700/mes (Developer/Basic tier) |
| **Cambios requeridos** | Deploy APIM, crear APIs, modificar backend |
| **Downtime** | Ninguno |
| **Beneficios** | Rate limiting, caching, monitoring, políticas |

---

## 📋 Matriz de Decisión

| Criterio | Opción A (Internal Env) | Opción B (Firewall) | Opción C (VM Proxy) | Opción D (APIM) |
|----------|------------------------|---------------------|---------------------|-----------------|
| **Costo mensual** | $70-150 | $900-1,200 | $15-50 | $150-700 |
| **Tiempo implementación** | 2-4 hrs | 3-5 hrs | 2-3 hrs | 4-6 hrs |
| **Complejidad** | Media | Alta | Baja | Media |
| **Downtime** | 30-60 min | Mínimo | Ninguno | Ninguno |
| **Mantenimiento** | Bajo | Medio | Medio | Bajo |
| **Escalabilidad** | Alta | Alta | Media | Alta |
| **Seguridad** | Alta | Muy Alta | Media | Alta |
| **Cambios en código** | Ninguno | Ninguno | Sí | Sí |

---

## 🎯 Recomendación

### Para producción a largo plazo: **Opción A (Internal Environment)**
- Solución más limpia arquitectónicamente
- Sin componentes adicionales que mantener
- Control total del networking

### Para solución rápida/MVP: **Opción C (VM Proxy)**
- Menor costo
- Implementación más rápida
- Permite validar la conectividad antes de invertir más

### Si ya existe Azure Firewall en el Hub: **Opción B**
- Aprovechar infraestructura existente
- Centralizar políticas de seguridad

---

## 🔍 Información adicional para el equipo de networking

### Recursos actuales:

```yaml
Virtual WAN: core-infra-vwan
Hub: centralus-hub (10.108.8.0/21)
  - VPN Gateway: 4c3207b1a4b14a89a5d5784327bf75a7-centralus-gw
  - ExpressRoute Gateway: 46ce67c14abb4776903661834aca1662-centralus-er-gw
  
Conexiones al Hub:
  - conn-netops-hub-prd-usc (vnet-netops-hub-prd-usc) ✅
  - conn-certmgr-prd-usc (vnet-netops-certmgr-prd-usc) ✅
  
Rutas existentes en el Hub:
  - 10.0.0.0/8 → ExpressRoute (incluye 10.119.x.x)
  - Múltiples rutas específicas para otras redes
```

### Preguntas para el equipo:

1. ¿Existe Azure Firewall en el NetOps Hub que podamos utilizar?
2. ¿Hay políticas de seguridad que requieran inspección del tráfico hacia F5s?
3. ¿Prefieren una solución temporal (VM proxy) mientras se evalúa la arquitectura final?
4. ¿Hay presupuesto disponible para workload profiles dedicados (~$70-150/mes)?

---

## 📞 Contacto

Para discutir estas opciones o proceder con la implementación, contactar al equipo de:
- **Networking**: Para validar rutas y políticas
- **Security**: Para aprobar cambios de arquitectura
- **Platform**: Para presupuesto y recursos

---

*Documento generado: December 12, 2025*
