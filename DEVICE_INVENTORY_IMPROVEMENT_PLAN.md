# 📋 Device Inventory Dashboard - Plan de Mejora

**Versión**: CMT v2.5  
**Fecha inicio**: 5 Diciembre 2025  
**Estado**: 🔄 En Progreso - Fase 2  

---

## 📊 Resumen Ejecutivo

El Device Inventory Dashboard tiene una base sólida pero requiere mejoras en visualización de clusters, vista de detalle, edición de dispositivos, y consistencia de código.

### Decisiones de Diseño
- **Vista de detalle**: Drawer lateral (no pierde contexto de la tabla)
- **Agrupación de clusters**: Ordenar por cluster_key + separador visual (Fase 1)
- **Orden de prioridades**: Mantener plan propuesto

---

## ✅ Lo Que Está Bien Hecho

| Aspecto | Detalle |
|---------|---------|
| Modelo de datos robusto | Device tiene 20+ campos útiles (HA, sync, cluster) |
| API backend completa | Endpoints para CRUD, facts, cache, auto-cluster |
| HA Detection | Implementado con `failover-state` query |
| Sync Status | Colores semáforo (green/yellow/red) |
| Bulk Actions | Toolbar con acciones útiles |
| Rate Limiting | Endpoints sensibles protegidos |

---

## ❌ Problemas Identificados

| Problema | Impacto | Fase |
|----------|---------|------|
| Sin vista de detalle | Info limitada, click no hace nada | F2 |
| Clusters no visibles | Backend los calcula pero UI no los muestra | F1 |
| Sin indicador de Primary | `is_primary_preferred` no se visualiza | F1 |
| Sin edición de dispositivos | Solo agregar/eliminar | F2 |
| Sin toggle Active/Inactive | Campo `active` sin control en UI | F1 |
| Tipos duplicados | `DeviceRow` definido 3 veces | F3 |
| Sin paginación backend | Retorna todos los dispositivos | F4 |
| Filtros backend no usados | `ha_state`, `sync_status` sin UI | F2 |

---

## 🗺️ Plan de Implementación

---

### **Fase 1: UX/Visual** ✅ COMPLETADA (5 Dic 2025)
> Mejorar la presentación visual y la organización de datos

| # | Task | Prioridad | Estado | Notas |
|---|------|-----------|--------|-------|
| 1.1 | Agregar columna Cluster | Alta | ✅ Listo | Chip estilizado con `cluster_key` |
| 1.2 | Badge de Primary | Alta | ✅ Listo | Ícono ⭐ junto al hostname si `is_primary_preferred` |
| 1.3 | Agrupación visual por Cluster | Alta | ✅ Listo | Default sort por cluster_key + ip_address |
| 1.4 | Toggle Active/Inactive | Media | ⏭️ Diferido | Mover a Fase 2 |
| 1.5 | Ocultar columnas vacías | Baja | ⏭️ Diferido | Mover a Fase 2 |
| 1.6 | Scan unificado (facts+certs) | Alta | ✅ Listo | Una conexión obtiene todo |

**Commits:**
- `0d60b2553` - feat(ui): Phase 1 Device Inventory improvements
- `ef7093f0d` - feat(scan): Unified scan - facts + certificates in single connection

**Archivos modificados:**
- `frontend/src/components/DeviceTable.jsx` - Columna cluster, badge primary, sort
- `backend/services/f5_facts.py` - Helper para facts con conexión existente
- `backend/services/f5_service_logic.py` - Integración de facts en scan
- `backend/populate_clusters.py` - Script para inferir clusters (50 detectados)

---

### **Fase 2: Funcionalidad** (7-10 días) 🔄 EN PROGRESO
> Agregar capacidades que faltan

| # | Task | Prioridad | Estado | Notas |
|---|------|-----------|--------|-------|
| 2.1 | Device Detail Drawer | Alta | ⬜ Pendiente | Panel lateral con toda la info del device |
| 2.2 | Edit Device Modal | Alta | ⬜ Pendiente | Editar hostname, IP, site, version |
| 2.3 | Filtros avanzados | Media | ⬜ Pendiente | Chips para HA state, sync status, site |
| 2.4 | Health Check indicator | Media | ⬜ Pendiente | Mostrar si device respondió en último refresh |
| 2.5 | Export CSV | Baja | ⬜ Pendiente | Botón para descargar inventario |
| 2.6 | Bulk Set Credentials | Baja | ⬜ Pendiente | Setear credenciales a múltiples devices |

**Archivos a crear:**
- `frontend/src/components/DeviceDetailDrawer.jsx`
- `frontend/src/components/EditDeviceDialog.jsx`

**Archivos a modificar:**
- `frontend/src/pages/DevicesPage.jsx`
- `frontend/src/components/DeviceTable.jsx`
- `backend/api/endpoints/devices.py` (endpoint PUT para editar)

---

### **Fase 3: Calidad de Código** (3-4 días)
> Refactorizar y estandarizar

| # | Task | Prioridad | Estado | Notas |
|---|------|-----------|--------|-------|
| 3.1 | Unificar tipos TypeScript | Alta | ⬜ Pendiente | Crear `types/device.ts` con un solo type |
| 3.2 | Constantes para estados | Media | ⬜ Pendiente | `HA_STATES`, `SYNC_COLORS` como enums |
| 3.3 | Migrar DevicesPage a TS | Media | ⬜ Pendiente | `.jsx` → `.tsx` |
| 3.4 | Usar API client consistente | Baja | ⬜ Pendiente | Todo via `api/devices.ts` |

**Archivos a crear:**
- `frontend/src/types/device.ts`
- `frontend/src/constants/deviceStates.ts`

**Archivos a migrar:**
- `DevicesPage.jsx` → `DevicesPage.tsx`
- `DeviceTable.jsx` → `DeviceTable.tsx`

---

### **Fase 4: Optimización** (3-4 días)
> Mejorar rendimiento para escalar

| # | Task | Prioridad | Estado | Notas |
|---|------|-----------|--------|-------|
| 4.1 | Paginación backend | Alta | ⬜ Pendiente | `?page=1&limit=50` en GET /devices |
| 4.2 | Virtual scrolling | Media | ⬜ Pendiente | DataGrid virtual si hay 500+ devices |
| 4.3 | Cache con React Query | Baja | ⬜ Pendiente | Stale time para evitar re-fetches |

**Archivos a modificar:**
- `backend/api/endpoints/devices.py`
- `backend/schemas/device.py` (agregar PaginatedResponse)
- `frontend/src/api/devices.ts`

---

## 📝 Registro de Cambios

| Fecha | Fase | Task | Commit | Notas |
|-------|------|------|--------|-------|
| 2025-12-05 | — | Plan creado | — | Documento inicial |
| 2025-12-05 | F1 | Columna Cluster + Badge Primary | `0d60b2553` | 50 clusters detectados |
| 2025-12-05 | F1 | Scan unificado facts+certs | `ef7093f0d` | Una conexión, menos carga en F5 |
| 2025-12-05 | F1 | **Fase 1 completada** | — | 4/6 tasks listos, 2 diferidos |

---

## 🎯 Métricas de Éxito

| Métrica | Antes | Objetivo |
|---------|-------|----------|
| Info visible por device | 8 campos | 15+ campos |
| Clicks para ver detalle | N/A | 1 click |
| Clicks para editar | N/A | 2 clicks |
| Visualización de clusters | ❌ | ✅ |
| Indicador de Primary | ❌ | ✅ |
| Filtros avanzados | 1 (search) | 4+ |

---

## 📚 Referencias

- **Backend Device Model**: `app/backend/db/models.py` → clase `Device`
- **Backend API**: `app/backend/api/endpoints/devices.py`
- **Frontend Table**: `app/frontend/src/components/DeviceTable.jsx`
- **Frontend Page**: `app/frontend/src/pages/DevicesPage.jsx`
- **API Client**: `app/frontend/src/api/devices.ts`

---

## 💡 Ideas Futuras (Post-v2.5)

- [ ] Mapa geográfico de dispositivos por site
- [ ] Gráfico de health status histórico
- [ ] Alertas automáticas por sync status
- [ ] Integración con sistemas de monitoreo externos
- [ ] Modo oscuro optimizado para NOC
