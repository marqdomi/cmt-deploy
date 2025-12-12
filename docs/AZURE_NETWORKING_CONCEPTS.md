# Azure Networking Concepts
## Guía para entender VNets, Conectividad y Virtual WAN

---

## 🔷 1. Virtual Network (VNet) - Conceptos Básicos

### ¿Qué es una VNet?
Una **VNet** es una red privada aislada en Azure. Es el equivalente a una LAN tradicional pero en la nube.

```
┌─────────────────────────────────────────────────────────────┐
│  VNet: vnet-netops-certmgr-prd-usc (10.105.68.0/24)         │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │ Subnet ACA              │  │ Subnet Data              │  │
│  │ 10.105.68.0/25          │  │ 10.105.68.128/26         │  │
│  │ ┌───────┐ ┌───────┐     │  │ ┌───────────────────┐    │  │
│  │ │Backend│ │Worker │     │  │ │   PostgreSQL      │    │  │
│  │ └───────┘ └───────┘     │  │ └───────────────────┘    │  │
│  └─────────────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Características clave:
- **Address Space**: Rango de IPs privadas (ej: 10.105.68.0/24 = 256 IPs)
- **Subnets**: Divisiones dentro de la VNet para organizar recursos
- **Isolation**: Por defecto, VNets no pueden comunicarse entre sí
- **Region-bound**: Una VNet existe en una sola región de Azure

---

## 🔶 2. Tipos de Conectividad en Azure

### Tabla Comparativa

| Método | Uso | Latencia | Costo | Complejidad |
|--------|-----|----------|-------|-------------|
| **VNet Peering** | Azure ↔ Azure (misma región) | ~1ms | Bajo | Simple |
| **Global VNet Peering** | Azure ↔ Azure (diferentes regiones) | ~5-50ms | Medio | Simple |
| **VPN Gateway (S2S)** | Azure ↔ On-premises | ~30-100ms | Medio | Moderada |
| **ExpressRoute** | Azure ↔ On-premises (dedicado) | ~5-15ms | Alto | Compleja |
| **Virtual WAN** | Hub centralizado para todas las conexiones | Variable | Alto | Moderada |

---

## 🌐 3. Virtual WAN (vWAN) - Lo que usa Solera

### Arquitectura Hub-and-Spoke

```
                          ┌────────────────────┐
                          │   SOLERA ON-PREM   │
                          │   (F5s, Servers)   │
                          └─────────┬──────────┘
                                    │ VPN/ExpressRoute
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        VIRTUAL WAN: core-infra-vwan                      │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                │
│  │ France Hub    │  │ Central US Hub│  │ West Europe   │                │
│  │ 10.108.0.0/21 │  │ 10.108.8.0/21 │  │ 10.108.32.0/21│  ... más hubs │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘                │
│          │                  │                  │                         │
└──────────┼──────────────────┼──────────────────┼─────────────────────────┘
           │                  │                  │
     ┌─────┴─────┐      ┌─────┴─────┐      ┌─────┴─────┐
     │ VNets FR  │      │ VNets USC │      │ VNets WEU │
     │ (spoke)   │      │ (spoke)   │      │ (spoke)   │
     └───────────┘      └───────────┘      └───────────┘
```

### ¿Por qué Virtual WAN?
1. **Centralización**: Un solo punto de gestión para todas las conexiones
2. **Transitividad**: Todos los spokes pueden comunicarse entre sí automáticamente
3. **Routing automático**: No necesitas configurar rutas manualmente
4. **Escalabilidad**: Soporta cientos de VNets y miles de conexiones VPN

### Tu configuración actual (ACTUALIZADA):

```yaml
Virtual WAN: core-infra-vwan
  └── Hub: centralus-hub (10.108.8.0/21)
        ├── VPN Gateway: 4c3207b1a4b14a89a5d5784327bf75a7-centralus-gw
        │     └── Conexión VPN → Solera On-Prem (F5 Management: 10.119.x.x)
        │
        ├── VNet: core-infrastructure-centralus-vnet1 ✅ Connected
        ├── VNet: apps-crm-prd-vnet1 ✅ Connected
        ├── VNet: apps-rms-prd-vnet1 ✅ Connected
        │   ... (50+ VNets conectadas)
        │
        └── VNet: vnet-netops-hub-prd-usc ✅ CONECTADO (conn-netops-hub-prd-usc)
              │
              └── VNet Peering → vnet-netops-certmgr-prd-usc (CMT App)
                                 └── Container Apps (backend, worker, beat)
```

### Arquitectura implementada:

```
   Solera On-Prem        centralus-hub         NetOps Hub           CMT VNet
   (F5s: 10.119.x.x)    (10.108.8.0/21)     (10.105.64.0/22)    (10.105.68.0/24)
         │                    │                    │                   │
         │      VPN           │    Hub Conn        │   VNet Peering    │
         └────────────────────┼────────────────────┼───────────────────┘
                              │                    │
                              │  ✅ Rutas se       │  ✅ Tráfico fluye
                              │  propagan          │  via Hub
                              │  automáticamente   │
```

---

## 🔗 4. Conectando CMT al Virtual WAN

### Estado Actual (Implementado ✅):

| Componente | Estado | Nota |
|------------|--------|------|
| NetOps Hub VNet | ✅ Conectado | `vnet-netops-hub-prd-usc` conectado a centralus-hub |
| CMT VNet | ✅ Peering | `vnet-netops-certmgr-prd-usc` peered con NetOps Hub |
| Container Apps Environment | ✅ VNet Integration | Usa `snet-aca-certmgr-prd-usc` |
| VPN Gateway (innecesario) | ⏳ Eliminando | Era redundante, se elimina |

### Conexión al Hub implementada:

```bash
# Conexión creada exitosamente
az network vhub connection create \
  --name conn-netops-hub-prd-usc \
  --vhub-name centralus-hub \
  --resource-group Networks-PRD-RG \
  --remote-vnet "/subscriptions/.../vnet-netops-hub-prd-usc" \
  --internet-security true

# Estado: Succeeded
# Propaga rutas a: defaultRouteTable
```

### Resultado implementado:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Central US Hub (10.108.8.0/21) - centralus-hub                              │
│                                                                              │
│  VPN Gateway ──────────────────────────► Solera On-Prem                     │
│       │                                  (F5s: 10.119.x.x)                  │
│       │                                                                      │
│  ┌────┴────────────────────────────────────────────────────────────────┐    │
│  │              Hub Route Table (defaultRouteTable)                     │    │
│  │  10.105.64.0/22 → conn-netops-hub-prd-usc (NetOps Hub)              │    │
│  │  10.105.68.0/24 → via NetOps Hub Peering                            │    │
│  │  10.119.0.0/16  → VPN Gateway → Solera                              │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────┬────────────────────────────────────┘
                                          │ Hub Connection
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  NetOps Hub (10.105.64.0/22) - vnet-netops-hub-prd-usc                       │
│                                                                              │
│  ┌───────────────────┐  ┌───────────────────┐                               │
│  │  Shared Services  │  │  Shared Data      │                               │
│  └───────────────────┘  └───────────────────┘                               │
│                              │                                               │
│  allowGatewayTransit: true   │ VNet Peering (hub-to-certmgr)                │
└──────────────────────────────┼───────────────────────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CMT VNet (10.105.68.0/24) - vnet-netops-certmgr-prd-usc                     │
│                                                                              │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────┐       │
│  │  snet-aca-certmgr-prd-usc   │  │  snet-data-certmgr-prd-usc      │       │
│  │  ┌─────────┐ ┌─────────┐    │  │  ┌──────────────────────────┐   │       │
│  │  │ Backend │ │ Worker  │    │  │  │     PostgreSQL           │   │       │
│  │  └─────────┘ └─────────┘    │  │  └──────────────────────────┘   │       │
│  └─────────────────────────────┘  └─────────────────────────────────┘       │
│                                                                              │
│  → Rutas heredadas: 10.119.x.x accesible via Hub → VPN                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 5. Comparación: VPN Gateway vs Virtual WAN

### Escenario: Conexión a Solera On-Prem

#### Opción A: VPN Gateway Independiente (lo que empezamos)
```
VNet CMT ──► VPN Gateway ──► Internet ──► Solera VPN Device ──► F5s
                │
                └── Costos: ~$140/mes (VpnGw1AZ)
                └── Gestión: Independiente, manual
                └── Routing: Manual (UDRs)
```

**Ventajas:**
- Control total sobre la configuración
- Costo fijo y predecible

**Desventajas:**
- No se integra con otras VNets
- Gestión manual de rutas
- No hay transitividad automática

#### Opción B: Virtual WAN Hub (lo que vamos a usar) ✅
```
VNet CMT ──► Hub ──► VPN Gateway compartido ──► Solera On-Prem ──► F5s
               │
               └── También conecta con: France, WestEurope, etc.
               └── Routing automático
               └── Transitividad entre VNets
```

**Ventajas:**
- Integración con toda la infraestructura de Solera
- Routing automático
- Transitividad (CMT puede hablar con otros recursos en otros spokes)
- Ya está configurado y funcionando

**Desventajas:**
- Costo compartido (pero más eficiente)
- Menos control granular
- Depende del equipo de networking

---

## 🛠️ 6. Container Apps y VNet Integration

### Estado Actual: ✅ VNet Integration Habilitado

El Container Apps Environment **YA tiene VNet integration**:

```yaml
Environment: cae-certmgr-prd-usc
  Location: Central US
  State: Succeeded
  VNet Integration:
    Subnet: snet-aca-certmgr-prd-usc (10.105.68.0/25)
    Internal: false (accesible desde internet Y VNet)
    Static IP: 172.168.236.98
  Infrastructure Resource Group: ME_cae-certmgr-prd-usc_rg-netops-certmgr-prd-usc_centralus
```

### Flujo de tráfico (implementado):

```
Container Apps ──► VNet (10.105.68.x) ──► Peering ──► NetOps Hub ──► vWAN Hub ──► VPN ──► F5s
                           │
                           └── Tráfico privado (no sale a Internet)
                           └── Rutas propagadas desde vWAN
                           └── F5s accesibles en 10.119.x.x
```

### Verificación de conectividad:

```bash
# Desde el Container Apps backend, debería poder alcanzar:
# - NetOps Hub: 10.105.64.x ✅
# - Solera F5s: 10.119.x.x (via VPN)

# Test de conectividad (ejecutar desde el container):
# curl -k https://10.119.x.x:8443/mgmt/tm/sys/version
```

---

## 📋 7. Resumen de Acciones (Actualizado)

| # | Tarea | Estado | Nota |
|---|-------|--------|------|
| 1 | Conectar NetOps Hub al vWAN | ✅ Completado | `conn-netops-hub-prd-usc` |
| 2 | Eliminar VPN Gateway innecesario | ⏳ En proceso | `vpngw-certmgr-prd-usc` |
| 3 | Eliminar GatewaySubnet de CMT VNet | Pendiente | Después de (2) |
| 4 | Eliminar Public IP del gateway | Pendiente | `pip-vpngw-certmgr-prd-usc` |
| 5 | Verificar propagación de rutas | Pendiente | Rutas a 10.119.x.x |
| 6 | Probar conectividad a F5s | Pendiente | curl desde Container Apps |

---

## 🔐 8. Consideraciones de Seguridad

### Network Security Groups (NSG)
Asegúrate de tener reglas que permitan:
- **Outbound**: TCP/443 hacia 10.119.0.0/16 (F5 Management)
- **Inbound**: Respuestas de F5s (stateful, automático)

### Routing
Con la conexión al vWAN:
- Las rutas se propagan automáticamente via `defaultRouteTable`
- No necesitas User Defined Routes (UDRs) manuales
- El tráfico a 10.119.x.x irá al VPN Gateway del vWAN Hub

### Azure Firewall (si aplica)
El Hub puede tener Azure Firewall. Verificar que las rutas no se bloqueen.

### DNS
- Los F5s se acceden por IP directamente
- No se requiere Private DNS en este caso

---

*Documento creado: December 12, 2025*
*Para CMT Azure Deployment*
