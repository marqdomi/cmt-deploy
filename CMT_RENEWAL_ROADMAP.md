# CMT Certificate Renewal - Roadmap de Mejoras

> **Última actualización:** 7 de Diciembre 2025  
> **Branch:** v2.5  
> **Estado General:** ⚡ En desarrollo activo

---

## 📋 Resumen Ejecutivo

Este documento rastrea las mejoras propuestas para el proceso de renovación de certificados en CMT, basado en la auditoría del flujo actual y el análisis de opciones de automatización.

### Flujo Actual (Manual)
```
CMT Inventory → F5 GUI (CSR) → DigiCert → PFX Generator → Vault → Renew Wizard → Cleanup
     ↓              ↓              ↓            ↓           ↓          ↓           ↓
  Detectar      Crear CSR     Aprobar y    Ensamblar    Almacenar  Desplegar   Eliminar
  vencidos      y .key        obtener .crt  PFX          seguro     en F5       viejo
```

### Flujo Objetivo (Optimizado)
```
CMT Inventory → CMT CSR Generator → DigiCert → CMT Import/Vault → Deploy → Auto-Cleanup
     ↓                 ↓                ↓              ↓              ↓           ↓
  Detectar        Generar CSR      Aprobar y      Importar       Desplegar   Programar
  + Estado        localmente       obtener .crt   directo        + Audit     limpieza
```

---

## 🎯 Mejoras Priorizadas

### Fase 1: Visibilidad y Trazabilidad (Bajo Riesgo)

| ID | Mejora | Estado | Prioridad | Esfuerzo | Impacto |
|----|--------|--------|-----------|----------|---------|
| 1.1 | Estado de Renovación (tracking) | ✅ **Completado** | Alta | Medio | Alto |
| 1.2 | Audit Log de Deployments | ✅ **Completado** | Alta | Bajo | Alto |
| 1.3 | Limpiar código orphan del wizard | ✅ **Completado** | Baja | Bajo | Bajo |

#### 1.1 Estado de Renovación ✅ COMPLETADO
- **Descripción:** Agregar campo `renewal_status` a certificados
- **Estados:** `none` → `expiring` → `csr_created` → `pending_ca` → `cert_ready` → `deployed` → `verified`
- **Beneficio:** Visibilidad del proceso completo, evitar duplicados

**Implementado:**
- ✅ `CertRenewalStatus` enum en `db/models.py`
- ✅ `renewal_status` column en tabla `certificates`
- ✅ Alembic migration `b2c3d4e5f6g7`
- ✅ Campos adicionales: `renewal_request_id`, `renewal_started_at`, `renewal_notes`

#### 1.2 Audit Log ✅ COMPLETADO
- **Descripción:** Tabla de auditoría para todas las operaciones de deployment
- **Campos:** timestamp, usuario, certificado, acción, dispositivo, resultado
- **Beneficio:** Trazabilidad completa, compliance

**Implementado:**

**Backend:**
- ✅ `AuditAction` enum (18 tipos de acciones)
- ✅ `AuditResult` enum (success, failure, partial)
- ✅ `AuditLog` model con todos los campos necesarios
- ✅ `services/audit_service.py` - Servicio centralizado de auditoría
- ✅ `api/endpoints/audit.py` - REST API endpoints
- ✅ Alembic migration para tabla `audit_logs`

**Frontend:**
- ✅ `types/audit.ts` - Definiciones TypeScript
- ✅ `api/audit.ts` - Cliente API
- ✅ `components/AuditLogTable.tsx` - Tabla con filtros y paginación
- ✅ `pages/AuditLogPage.tsx` - Página de visualización con stats
- ✅ Navegación en MainLayout

**Endpoints API:**
```
GET  /api/v1/audit/logs              - Lista paginada con filtros
GET  /api/v1/audit/logs/{id}         - Detalle de entrada
GET  /api/v1/audit/resource/{type}/{id} - Historial de recurso
GET  /api/v1/audit/device/{id}       - Historial de dispositivo
GET  /api/v1/audit/stats             - Estadísticas para dashboard
GET  /api/v1/audit/actions           - Lista de acciones disponibles
```

#### 1.3 Limpieza Código Orphan ✅ COMPLETADO
- **Descripción:** Eliminar referencias a `isOrphanProfile` del wizard
- **Archivos:** `RenewWizardDialog.jsx`, `ImpactPreviewStep.jsx`, `ConfirmDeploymentStep.jsx`
- **Beneficio:** Código más limpio y mantenible

---

### Fase 2: Eficiencia Operativa (Impacto Alto)

| ID | Mejora | Estado | Prioridad | Esfuerzo | Impacto |
|----|--------|--------|-----------|----------|---------|
| 2.1 | CSR Generator en CMT | ✅ **Completado** | Alta | Alto | Muy Alto |
| 2.2 | Batch Renewal (Wildcards) | ✅ **Completado** | Media | Medio | Alto |
| 2.3 | Import desde Vault | 🔴 Pendiente | Media | Medio | Medio |

#### 2.1 CSR Generator en CMT ✅ COMPLETADO
- **Descripción:** Generar CSR y private key directamente desde CMT
- **Problema conocido:** F5 NO permite exportar keys (confirmado - diseño de seguridad)
- **Enfoque implementado:** Generación LOCAL con `cryptography` + Upload a F5
- **Beneficio:** Elimina paso manual en F5 GUI, flujo completamente controlado

**Componentes implementados:**

**Backend (Python):**
- `services/csr_service.py` - Core de generación CSR, keys, y PFX
- `schemas/csr.py` - Pydantic models para API
- `api/endpoints/csr.py` - 7 REST endpoints
- `db/models.py` - RenewalRequest model mejorado con nuevos campos y estados

**Frontend (TypeScript):**
- `components/CSRGeneratorWizard.tsx` - Wizard de 3 pasos
- `components/PendingCSRsPanel.tsx` - Lista de CSRs pendientes
- `pages/CsrGeneratorPage.tsx` - Página principal
- `types/csr.ts` - Definiciones de tipos TypeScript

**Endpoints API:**
```
POST /api/v1/csr/generate    - Genera CSR + Key encriptada
POST /api/v1/csr/complete    - Completa con cert firmado → PFX
GET  /api/v1/csr/pending     - Lista CSRs pendientes
GET  /api/v1/csr/{id}        - Detalle de request
GET  /api/v1/csr/{id}/download-pfx - Descarga PFX
DELETE /api/v1/csr/{id}      - Elimina request
```

#### 2.2 Batch Renewal ✅ COMPLETADO
- **Descripción:** Renovar wildcard en múltiples dispositivos simultáneamente
- **Beneficio:** Eficiencia en renovaciones masivas

**Componentes implementados:**

**Backend (Python):**
- `api/endpoints/batch.py` - Endpoints para operaciones batch
  - GET /wildcards - Lista wildcards agrupados por cantidad de dispositivos
  - GET /wildcards/{name} - Detalle de wildcard con dispositivos asociados
  - POST /deploy - Inicia deployment batch con BackgroundTask
  - GET /deploy/{batch_id} - Estado de operación batch
  - GET /deploy - Lista de operaciones batch activas
- Tracking en memoria (producción usaría Redis)

**Frontend (TypeScript):**
- `types/batch.ts` - BatchDeployStatus, WildcardGroup, WildcardDeviceInfo, etc.
- `api/batch.ts` - Cliente HTTP para batch API
- `pages/BatchRenewalPage.tsx` - Página completa con:
  - Stats cards (total wildcards, dispositivos afectados, operaciones activas)
  - Tabla expandible de wildcards agrupados
  - Diálogo de deployment con selección de dispositivos
  - Tracking de progreso con polling
- Ruta `/batch-renewal` en App.jsx
- Link en MainLayout (icono Autorenew)

**Endpoints API:**
```
GET  /api/v1/batch/wildcards           - Lista wildcards agrupados
GET  /api/v1/batch/wildcards/{name}    - Detalle wildcard + dispositivos
POST /api/v1/batch/deploy              - Inicia batch deployment
GET  /api/v1/batch/deploy/{batch_id}   - Estado de operación
GET  /api/v1/batch/deploy              - Lista operaciones activas
```

#### 2.3 Import desde Vault
- **Descripción:** Obtener PFX directamente de Vault Solera
- **Beneficio:** Elimina paso manual de descarga

---

### Fase 3: Automatización Avanzada (Futuro)

| ID | Mejora | Estado | Prioridad | Esfuerzo | Impacto |
|----|--------|--------|-----------|----------|---------|
| 3.1 | Cleanup Automatizado | 🔴 Pendiente | Baja | Bajo | Medio |
| 3.2 | Notificaciones Avanzadas | 🔴 Pendiente | Baja | Medio | Medio |
| 3.3 | Integración DigiCert API | 🔴 Pendiente | Baja | Alto | Alto |

---

## 📊 Progreso General

```
Fase 1: ████████████████████ 100% (3/3 completadas) ✅
Fase 2: █████████████░░░░░░░ 66% (2/3 completadas)  
Fase 3: ░░░░░░░░░░░░░░░░░░░░ 0% (0/3 completadas)
```

---

## 📝 Notas de Sesiones

### Sesión: 6 de Diciembre 2025 - FASE 1 COMPLETADA
**Implementación de Renewal Status Tracking y Audit Log:**

**Fase 1.1 - Renewal Status:**
- ✅ `CertRenewalStatus` enum: none, expiring, csr_created, pending_ca, cert_ready, deployed, verified, failed
- ✅ `renewal_status` column en certificates
- ✅ Campos adicionales: renewal_request_id (FK), renewal_started_at, renewal_notes
- ✅ Index `ix_certificates_renewal_status`

**Fase 1.2 - Audit Log:**
- ✅ `AuditAction` enum (18 acciones): cert_deployed, cert_renewed, csr_generated, device_added, user_login, etc.
- ✅ `AuditResult` enum: success, failure, partial
- ✅ `AuditLog` model con: user, action, resource, device, result, description, error_message, ip_address
- ✅ `services/audit_service.py` - Service layer con métodos:
  - log_cert_deployed(), log_cert_renewed(), log_cert_deleted()
  - log_csr_generated(), log_csr_completed()
  - log_device_scanned(), log_user_login()
  - get_logs_for_resource(), get_logs_for_device()
- ✅ `api/endpoints/audit.py` - REST API con:
  - GET /logs (paginado, filtros)
  - GET /logs/{id}
  - GET /resource/{type}/{id}
  - GET /device/{id}
  - GET /stats (estadísticas)
  - GET /actions (lista acciones)
- ✅ Alembic migration `b2c3d4e5f6g7` (idempotente)

**Frontend (TypeScript):**
- ✅ `types/audit.ts` - AuditLogEntry, AuditAction, AuditResult, AUDIT_ACTION_METADATA
- ✅ `api/audit.ts` - Cliente HTTP
- ✅ `components/AuditLogTable.tsx` - Tabla con filtros, paginación, chips de estado
- ✅ `pages/AuditLogPage.tsx` - Stats cards, breakdown por tipo, tabla completa
- ✅ Ruta `/audit-log` en App.jsx
- ✅ Link en MainLayout (icono History)

**Siguiente paso:** Fase 2.2 - Batch Renewal (Wildcards)

---

### Sesión: 7 de Diciembre 2025 - BATCH RENEWAL COMPLETADO
**Implementación de Batch Renewal para Wildcards (Fase 2.2):**

**Backend:**
- ✅ `api/endpoints/batch.py` con 5 endpoints para operaciones batch
- ✅ Agrupación de wildcards por cantidad de dispositivos
- ✅ Background tasks para deployments largos
- ✅ Tracking de estado de operaciones batch
- ✅ Router registrado en `main.py`

**Frontend:**
- ✅ `types/batch.ts` - Tipos TypeScript completos
- ✅ `api/batch.ts` - Cliente HTTP
- ✅ `pages/BatchRenewalPage.tsx` - Página completa con:
  - Stats cards (wildcards, dispositivos, operaciones)
  - Tabla expandible con wildcards agrupados
  - Diálogo de deployment batch con selección de dispositivos
  - Polling de progreso de operaciones
- ✅ Ruta `/batch-renewal` en App.jsx
- ✅ Navegación en MainLayout (icono Autorenew)

**Problema resuelto:**
- Fix de error 500 en login: SQLAlchemy no podía determinar join condition entre Certificate y RenewalRequest debido a múltiples FKs
- Solución: Agregar `foreign_keys=[original_certificate_id]` al relationship

**Siguiente paso:** Fase 2.3 - Import desde Vault

---

### Sesión: 6 de Diciembre 2025 - FASE 1 COMPLETADA
**Implementación completa del CSR Generator:**

**Backend:**
- ✅ `services/csr_service.py` - Core de generación CSR y PFX
- ✅ `schemas/csr.py` - Pydantic models
- ✅ `api/endpoints/csr.py` - 7 REST endpoints
- ✅ `db/models.py` - RenewalRequest model mejorado
- ✅ Alembic migration creada
- ✅ Fix import `get_current_user` desde `auth_service`

**Frontend (TypeScript):**
- ✅ `components/CSRGeneratorWizard.tsx` - Wizard 3 pasos con tipos
- ✅ `components/PendingCSRsPanel.tsx` - Panel con tipos
- ✅ `pages/CsrGeneratorPage.tsx` - Página con tipos
- ✅ `types/csr.ts` - Definiciones de tipos completas
- ✅ Navegación agregada en MainLayout

**Code Cleanup realizado:**
- ✅ Eliminados 9 componentes obsoletos (CsrInputDialog, DeployDialog, etc.)
- ✅ Eliminado `vips_service.py` (no utilizado)
- ✅ Eliminada función muerta `export_key_and_create_csr`
- ✅ Eliminados build artifacts (nginx-html/assets, dist)
- ✅ Fix `resizable` prop en DataGrid (feature de Pro)

**Siguiente paso:** Fase 1.1 - Estado de Renovación (tracking)

---

## 🔬 Investigación Técnica: CSR Generator

### Problema Original
El usuario intentó usar el SDK de F5 para descargar la private key generada en F5 GUI, pero F5 bloquea esto por seguridad.

### Hallazgos
1. **API `/mgmt/tm/sys/crypto/key`** - Solo metadatos, no contenido
2. **API `/mgmt/tm/sys/file/ssl-key`** - Permite upload pero no download de contenido
3. **TMSH** - Mismo comportamiento restrictivo

### Solución Validada
```
CMT Local                    DigiCert                 F5
   │                            │                      │
   ├─ Generate Key+CSR ─────────┤                      │
   │                            │                      │
   ├─ User submits CSR ─────────►                      │
   │                            │                      │
   │◄──── Returns .crt ─────────┤                      │
   │                            │                      │
   ├─ Assemble PFX ─────────────┤                      │
   │                            │                      │
   ├─ Upload Key via REST ──────┼──────────────────────►
   ├─ Upload Cert via REST ─────┼──────────────────────►
   └────────────────────────────┴──────────────────────┘
```

### Dependencia Nueva
```
pip install cryptography  # Ya está en requirements.txt
```

---

## 🔧 Decisiones Técnicas

### Enfoque de Automatización
- **Seleccionado:** iControl REST (imperativo) + CMT como orquestador
- **Descartado:** AS3 (declarativo) - No alineado con flujo incremental
- **Descartado:** BIG-IQ - Costo innecesario, CMT cubre necesidad
- **Considerado para futuro:** Ansible para batch operations

### Stack Tecnológico
- Frontend: React + Vite + MUI
- Backend: FastAPI + SQLAlchemy
- F5: iControl REST API
- Almacenamiento seguro: Vault Solera (HashiCorp Vault)

---

## 📚 Referencias

- [F5 iControl REST API](https://clouddocs.f5.com/api/icontrol-rest/)
- [F5 Certificate Management](https://my.f5.com/manage/s/article/K14620)
- [Python cryptography library](https://cryptography.io/)
- [DigiCert API](https://dev.digicert.com/)

---

## ⚠️ Riesgos Identificados

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Key export bloqueado por F5 | Alta | Alto | Generar key localmente |
| Pérdida de key privada | Media | Crítico | Almacenar en Vault |
| Incompatibilidad con DigiCert | Baja | Medio | Validar CSR antes de enviar |

---

*Este documento se actualiza conforme avanza el desarrollo.*
