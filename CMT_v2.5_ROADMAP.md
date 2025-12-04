# CMT v2.5 → v3.0 Roadmap - Certificate Manager Tool

> **Versión actual**: 2.0 (Production Ready)  
> **Versión intermedia**: 2.5 (Enterprise Optimization)  
> **Versión objetivo**: 3.0 (Full Automation)  
> **Última actualización**: 4 Diciembre 2025

---

## 📋 Resumen Ejecutivo

CMT v2.5 enfoca las mejoras en **rendimiento**, **precisión de datos en tiempo real**, y **simplificación de la arquitectura** para soportar eficientemente el entorno enterprise de Solera (100+ F5s distribuidos globalmente en EMEA y US).

---

## 🎯 Objetivos Principales

### v2.5 - Enterprise Optimization
1. **Datos en tiempo real** - Eliminar dependencia de cache stale
2. **Reducir complejidad operacional** - Menos componentes = menos puntos de falla
3. **Infraestructura cloud** - Azure Container Apps + CI/CD automatizado
4. **Seguridad enterprise** - Azure AD SSO + RBAC por grupos Windows AD

### v3.0 - Full Automation
5. **Zero-touch renewals** - Integración directa con CAs (ACME, DigiCert API)
6. **Políticas inteligentes** - Auto-renewal basado en reglas
7. **Compliance ready** - Audit logs completos para auditorías

---

## 🚀 Features Planificadas

### Feature 1: Real-Time Usage Detection (Opción D)

**Estado**: 📋 Planificado  
**Prioridad**: Alta  
**Esfuerzo estimado**: 2-3 días

#### Descripción
Reemplazar el sistema de cache persistente con consultas en tiempo real a los F5s, utilizando batch requests y queries paralelas.

#### Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────────┐
│              ARQUITECTURA SIN CACHE PERSISTENTE                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  GET /certificates/                                             │
│  ├── Lista básica (sin usage_state) → Respuesta inmediata      │
│  └── Frontend solicita usage_state en chunks                   │
│                                                                 │
│  POST /certificates/batch-usage  (NUEVO ENDPOINT)              │
│  body: { cert_ids: [1,2,3...50] }                              │
│  ├── Agrupa certificados por device_id                         │
│  ├── Consulta F5s en paralelo (asyncio)                        │
│  ├── Una conexión por device (no por certificado)              │
│  └── Respuesta: 3-5s para 50 certs del mismo device            │
│                                                                 │
│  FLUJO FRONTEND:                                                │
│  1. Carga lista de certificados (inmediato)                    │
│  2. Detecta certs visibles en viewport (~20-30)                │
│  3. Solicita usage_state solo para esos certs                  │
│  4. Actualización progresiva de la UI                          │
│  5. Al hacer scroll, solicita siguiente batch                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Beneficios

| Aspecto | Cache Actual | Real-Time (v2.5) |
|---------|--------------|------------------|
| Precisión de datos | 4-6h delay | ✅ Tiempo real |
| Tablas de BD | 3 tablas cache | ✅ 0 tablas extra |
| Celery Beat tasks | Refresh cada 4h | ✅ Eliminado |
| Complejidad | Alta | ✅ Baja |
| Carga a F5s | Full scan periódico | ✅ On-demand |
| Auditoría | Datos potencialmente stale | ✅ Siempre exacto |

#### Implementación Técnica

**Backend - Nuevo endpoint:**
```python
@router.post("/batch-usage")
async def get_certificates_usage_batch(
    cert_ids: List[int],
    db: Session = Depends(get_db),
    current_user: User = Depends(auth_service.get_current_active_user)
):
    """
    Obtiene el usage_state para múltiples certificados en una sola llamada.
    Agrupa por device para minimizar conexiones a F5.
    """
    # 1. Agrupar cert_ids por device_id
    # 2. Para cada device, abrir UNA conexión
    # 3. Consultar todos los certs de ese device en paralelo
    # 4. Retornar mapa { cert_id: usage_state }
```

**Frontend - Lazy loading:**
```typescript
// Intersection Observer para detectar certs visibles
const observer = new IntersectionObserver((entries) => {
  const visibleCertIds = entries
    .filter(e => e.isIntersecting)
    .map(e => e.target.dataset.certId);
  
  if (visibleCertIds.length > 0) {
    fetchUsageStateBatch(visibleCertIds);
  }
});
```

#### Archivos a Eliminar (Post-implementación)
- `backend/services/cache_builder.py` - Todo el archivo
- `backend/api/endpoints/f5_cache.py` - Todo el archivo
- Tablas de BD: `ssl_profiles_cache`, `ssl_profile_vips_cache`, `cert_profile_links_cache`

#### Archivos a Modificar
- `backend/api/endpoints/certificates.py` - Agregar endpoint batch, remover lógica de cache
- `backend/db/models.py` - Remover modelos de cache
- `frontend/src/components/CertificateTable.jsx` - Implementar lazy loading
- `backend/main.py` - Remover router de f5_cache

---

### Feature 2: Cleanup de Código Legacy

**Estado**: ✅ Parcialmente completado (Phase 1)  
**Prioridad**: Media

#### Completado en Phase 1
- [x] Eliminar imports no usados (`iControlUnexpectedHTTPError`, `Fernet`)
- [x] Eliminar migraciones backup obsoletas
- [x] Limpiar archivos temporales (`.DS_Store`, `celerybeat-schedule`)
- [x] Consistencia docker-compose (POSTGRES_USER/DB = `cmt`)
- [x] Agregar `venv/` a `.gitignore`

#### Pendiente para v2.5
- [ ] Eliminar `cache_builder.py` (después de Feature 1)
- [ ] Eliminar `f5_cache.py` (después de Feature 1)
- [ ] Refactorizar `f5_service_logic.py` (942 líneas → módulos separados)
- [ ] Eliminar código comentado y TODOs obsoletos

---

### Feature 3: Refactor de f5_service_logic.py

**Estado**: 📋 Planificado  
**Prioridad**: Media  
**Esfuerzo estimado**: 1-2 días

#### Problema Actual
`f5_service_logic.py` tiene 942 líneas con múltiples responsabilidades mezcladas.

#### Propuesta de Estructura
```
backend/services/f5/
├── __init__.py
├── connection.py      # Manejo de conexión/autenticación F5
├── certificates.py    # Operaciones de certificados
├── profiles.py        # Operaciones de SSL profiles
├── deployment.py      # Lógica de deploy
└── queries.py         # Queries de información (usage, etc.)
```

---

### Feature 4: Mejoras de Seguridad

**Estado**: 📋 Planificado  
**Prioridad**: Alta

- [ ] Rotación automática de encryption key
- [ ] Audit log de todas las operaciones de certificados
- [ ] Rate limiting por usuario/IP
- [ ] Validación de certificados antes de deploy (chain validation)

---

### Feature 5: Dashboard de Métricas

**Estado**: 📋 Planificado  
**Prioridad**: Baja

- [ ] Certificados por estado de expiración (30/60/90 días)
- [ ] Certificados por región (EMEA/US)
- [ ] Histórico de renovaciones
- [ ] Alertas configurables

---

### Feature 6: Migración a Azure Container Apps (CI/CD Enterprise)

**Estado**: 📋 Planificado  
**Prioridad**: Alta  
**Esfuerzo estimado**: 1-2 semanas

#### Problema Actual
- VM Windows Server 2025 con desconexiones frecuentes
- Deployment manual y propenso a errores
- Single point of failure
- Sin auto-healing ni auto-scaling

#### Solución Propuesta: Azure Container Apps con Private Networking

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA AZURE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   GitHub     │───►│   GitHub     │───►│   Azure      │      │
│  │   Repo       │    │   Actions    │    │   Container  │      │
│  │   (cmt-deploy)│   │   (CI/CD)    │    │   Registry   │      │
│  └──────────────┘    └──────────────┘    └──────┬───────┘      │
│                                                  │               │
│                                                  ▼               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Azure Virtual Network (Private)              │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │         Azure Container Apps Environment          │    │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │    │  │
│  │  │  │ Backend  │  │ Frontend │  │ Celery   │       │    │  │
│  │  │  │ FastAPI  │  │ Nginx+   │  │ Worker   │       │    │  │
│  │  │  │ :8000    │  │ React    │  │ +Beat    │       │    │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘       │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │           │              │              │                 │  │
│  │  ┌────────┴──────┐ ┌────┴─────┐ ┌─────┴──────┐          │  │
│  │  │ PostgreSQL    │ │ Redis    │ │ Key Vault  │          │  │
│  │  │ Flexible      │ │ Cache    │ │ (Secrets)  │          │  │
│  │  │ (Private EP)  │ │(Private) │ │            │          │  │
│  │  └───────────────┘ └──────────┘ └────────────┘          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                    ExpressRoute / Site-to-Site VPN             │
│                              │                                  │
│                    ┌─────────┴─────────┐                       │
│                    │  Solera Internal  │                       │
│                    │  Network          │                       │
│                    │  ┌─────────────┐  │                       │
│                    │  │ F5 Devices  │  │                       │
│                    │  │ (100+ EMEA/ │  │                       │
│                    │  │  US)        │  │                       │
│                    │  └─────────────┘  │                       │
│                    └───────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

#### Recursos Azure Requeridos

| Recurso | SKU | Propósito | Costo Est./mes |
|---------|-----|-----------|----------------|
| Container Apps Environment | Consumption | Hosting containers | ~$30-50 |
| Container Registry | Basic | Docker images | ~$5 |
| PostgreSQL Flexible | Burstable B1ms | Base de datos | ~$15 |
| Redis Cache | Basic C0 | Celery broker | ~$16 |
| Key Vault | Standard | Secrets management | ~$1 |
| VNet + Private Endpoints | - | Networking privado | ~$10 |
| **Total estimado** | | | **~$77-97/mes** |

#### Pipeline CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy-cmt.yml
name: 🚀 Deploy CMT to Azure

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - 'docker-compose.prod.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging

env:
  ACR_NAME: cmtregistry
  RESOURCE_GROUP: rg-cmt-prod
  CONTAINER_APP_ENV: cmt-env
  LOCATION: westeurope

jobs:
  build:
    name: 🏗️ Build & Push Images
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ github.sha }}
    
    steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive
    
    - name: 🔐 Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: 🔐 Login to ACR
      run: az acr login --name ${{ env.ACR_NAME }}
    
    - name: 🐳 Build Backend Image
      run: |
        docker build \
          -t ${{ env.ACR_NAME }}.azurecr.io/cmt-backend:${{ github.sha }} \
          -t ${{ env.ACR_NAME }}.azurecr.io/cmt-backend:latest \
          -f app/backend/Dockerfile \
          ./app/backend
        docker push ${{ env.ACR_NAME }}.azurecr.io/cmt-backend --all-tags
    
    - name: 🐳 Build Frontend Image
      run: |
        docker build \
          -t ${{ env.ACR_NAME }}.azurecr.io/cmt-frontend:${{ github.sha }} \
          -t ${{ env.ACR_NAME }}.azurecr.io/cmt-frontend:latest \
          -f app/frontend/Dockerfile.prod \
          ./app/frontend
        docker push ${{ env.ACR_NAME }}.azurecr.io/cmt-frontend --all-tags

  deploy:
    name: 🚀 Deploy to Container Apps
    needs: build
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - name: 🔐 Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: 🚀 Deploy Backend
      run: |
        az containerapp update \
          --name cmt-backend \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --image ${{ env.ACR_NAME }}.azurecr.io/cmt-backend:${{ github.sha }}
    
    - name: 🚀 Deploy Frontend
      run: |
        az containerapp update \
          --name cmt-frontend \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --image ${{ env.ACR_NAME }}.azurecr.io/cmt-frontend:${{ github.sha }}
    
    - name: 🚀 Deploy Celery Worker
      run: |
        az containerapp update \
          --name cmt-celery \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --image ${{ env.ACR_NAME }}.azurecr.io/cmt-backend:${{ github.sha }}
    
    - name: ✅ Verify Deployment
      run: |
        az containerapp show \
          --name cmt-backend \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --query "properties.runningStatus"
```

#### Beneficios vs VM Actual

| Aspecto | VM Windows Server | Azure Container Apps |
|---------|-------------------|---------------------|
| Disponibilidad | ~95% (desconexiones) | 99.95% SLA |
| Deployment | Manual (~30 min) | Automático (~5 min) |
| Rollback | Manual, riesgoso | 1 click, automático |
| Scaling | Manual | Auto-scaling |
| Mantenimiento | Windows updates, patches | Zero maintenance |
| Costo | ~$100/mes + tiempo IT | ~$80/mes, sin IT overhead |
| Seguridad | Manual hardening | Managed, always updated |

#### Plan de Migración

```
Semana 1:
├── Día 1-2: Crear infraestructura Azure (Bicep/Terraform)
├── Día 3: Configurar networking privado + VPN/ExpressRoute
├── Día 4: Migrar base de datos PostgreSQL
└── Día 5: Configurar CI/CD pipeline

Semana 2:
├── Día 1-2: Testing en ambiente staging
├── Día 3: Migración de datos producción
├── Día 4: Cutover a Azure Container Apps
└── Día 5: Monitoreo y ajustes
```

---

### Feature 7: Azure AD SSO + RBAC por Grupos de Windows AD

**Estado**: 📋 Planificado  
**Prioridad**: Alta  
**Esfuerzo estimado**: 3-5 días

#### Descripción
Integrar autenticación con Azure AD (sincronizado con Windows AD de Solera) para Single Sign-On y control de acceso basado en grupos de Active Directory.

#### Arquitectura de Autenticación

```
┌─────────────────────────────────────────────────────────────────┐
│                    AZURE AD + RBAC FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │  Windows    │────►│  Azure AD   │────►│  Azure AD   │       │
│  │  AD Solera  │sync │  Connect    │     │  (Cloud)    │       │
│  │             │     │             │     │             │       │
│  │ Groups:     │     │             │     │ App Reg:    │       │
│  │ - Network   │     │             │     │ CMT-App     │       │
│  │ - Security  │     │             │     │             │       │
│  │ - Viewers   │     │             │     │             │       │
│  └─────────────┘     └─────────────┘     └──────┬──────┘       │
│                                                  │               │
│                                                  ▼               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      CMT Application                      │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Frontend (React)                                   │  │  │
│  │  │  ┌─────────────────────────────────────────────┐   │  │  │
│  │  │  │  MSAL.js                                     │   │  │  │
│  │  │  │  - Login with Microsoft                      │   │  │  │
│  │  │  │  - Get access token                          │   │  │  │
│  │  │  │  - Include groups in token                   │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                           │                               │  │
│  │                    Bearer Token                           │  │
│  │                    (JWT with groups)                      │  │
│  │                           │                               │  │
│  │                           ▼                               │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Backend (FastAPI)                                  │  │  │
│  │  │  ┌─────────────────────────────────────────────┐   │  │  │
│  │  │  │  Azure AD JWT Validation                     │   │  │  │
│  │  │  │  - Validate token signature                  │   │  │  │
│  │  │  │  - Extract user groups                       │   │  │  │
│  │  │  │  - Map groups to CMT roles                   │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

#### Mapeo de Grupos AD → Roles CMT

| Grupo Windows AD | Rol CMT | Permisos |
|------------------|---------|----------|
| `SG-Network-Admins` | ADMIN | Full access: renovar, deploy, eliminar, configurar |
| `SG-Network-Operators` | OPERATOR | Renovar certificados, deploy, ver todo |
| `SG-Security-Team` | VIEWER | Solo lectura: ver certificados, estado, reportes |
| `SG-CMT-Viewers` | VIEWER | Solo lectura: dashboard básico |
| *(Sin grupo)* | - | Acceso denegado |

#### Implementación Backend

```python
# backend/core/azure_ad_auth.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt import PyJWKClient
from typing import List, Optional
from enum import Enum

class CMTRole(str, Enum):
    ADMIN = "ADMIN"
    OPERATOR = "OPERATOR" 
    VIEWER = "VIEWER"

# Mapeo de Object IDs de grupos AD a roles CMT
AD_GROUP_TO_ROLE = {
    "a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx": CMTRole.ADMIN,      # SG-Network-Admins
    "e5f6g7h8-xxxx-xxxx-xxxx-xxxxxxxxxxxx": CMTRole.OPERATOR,   # SG-Network-Operators
    "i9j0k1l2-xxxx-xxxx-xxxx-xxxxxxxxxxxx": CMTRole.VIEWER,     # SG-Security-Team
    "m3n4o5p6-xxxx-xxxx-xxxx-xxxxxxxxxxxx": CMTRole.VIEWER,     # SG-CMT-Viewers
}

class AzureADUser:
    def __init__(self, token_payload: dict):
        self.id = token_payload.get("oid")
        self.email = token_payload.get("preferred_username")
        self.name = token_payload.get("name")
        self.groups = token_payload.get("groups", [])
        self.role = self._determine_role()
    
    def _determine_role(self) -> Optional[CMTRole]:
        """Determina el rol más alto basado en grupos AD"""
        user_roles = []
        for group_id in self.groups:
            if group_id in AD_GROUP_TO_ROLE:
                user_roles.append(AD_GROUP_TO_ROLE[group_id])
        
        if not user_roles:
            return None
        
        # Prioridad: ADMIN > OPERATOR > VIEWER
        if CMTRole.ADMIN in user_roles:
            return CMTRole.ADMIN
        if CMTRole.OPERATOR in user_roles:
            return CMTRole.OPERATOR
        return CMTRole.VIEWER

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> AzureADUser:
    """Valida token JWT de Azure AD y retorna usuario"""
    token = credentials.credentials
    
    try:
        # Obtener JWKS de Azure AD
        jwks_client = PyJWKClient(
            f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys"
        )
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        
        # Validar token
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=CLIENT_ID,
            issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
        )
        
        user = AzureADUser(payload)
        
        if user.role is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User is not a member of any authorized AD group"
            )
        
        return user
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

def require_role(allowed_roles: List[CMTRole]):
    """Decorator para requerir roles específicos"""
    async def role_checker(user: AzureADUser = Depends(get_current_user)):
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role {user.role} not authorized. Required: {allowed_roles}"
            )
        return user
    return role_checker

# Uso en endpoints:
@router.post("/{cert_id}/deploy")
async def deploy_certificate(
    cert_id: int,
    user: AzureADUser = Depends(require_role([CMTRole.ADMIN, CMTRole.OPERATOR]))
):
    # Solo ADMIN y OPERATOR pueden deployar
    ...

@router.get("/")
async def list_certificates(
    user: AzureADUser = Depends(require_role([CMTRole.ADMIN, CMTRole.OPERATOR, CMTRole.VIEWER]))
):
    # Todos pueden ver la lista
    ...
```

#### Implementación Frontend (MSAL.js)

```typescript
// frontend/src/auth/msalConfig.ts
import { Configuration, LogLevel } from "@azure/msal-browser";

export const msalConfig: Configuration = {
  auth: {
    clientId: "YOUR_CLIENT_ID",
    authority: "https://login.microsoftonline.com/YOUR_TENANT_ID",
    redirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

export const loginRequest = {
  scopes: ["api://YOUR_CLIENT_ID/access_as_user"],
};

// frontend/src/auth/AuthProvider.tsx
import { MsalProvider, useMsal, useIsAuthenticated } from "@azure/msal-react";
import { PublicClientApplication } from "@azure/msal-browser";

const msalInstance = new PublicClientApplication(msalConfig);

export function AuthProvider({ children }) {
  return (
    <MsalProvider instance={msalInstance}>
      {children}
    </MsalProvider>
  );
}

// Hook para obtener token en requests
export function useAuthToken() {
  const { instance, accounts } = useMsal();
  
  const getToken = async () => {
    const response = await instance.acquireTokenSilent({
      ...loginRequest,
      account: accounts[0],
    });
    return response.accessToken;
  };
  
  return { getToken };
}
```

#### Configuración Azure AD App Registration

```
Azure Portal → Azure Active Directory → App Registrations

1. Nueva App Registration:
   - Name: CMT-Certificate-Manager
   - Supported account types: Single tenant (Solera only)
   - Redirect URI: https://cmt.solera.internal/

2. Token Configuration:
   - Add optional claim: groups
   - Group claims: Security groups
   - Emit groups as: Group IDs

3. API Permissions:
   - Microsoft Graph → User.Read
   - Microsoft Graph → GroupMember.Read.All (admin consent)

4. Expose an API:
   - Application ID URI: api://cmt-certificate-manager
   - Scope: access_as_user
```

#### Matriz de Permisos por Rol

| Endpoint | ADMIN | OPERATOR | VIEWER |
|----------|-------|----------|--------|
| `GET /certificates/` | ✅ | ✅ | ✅ |
| `GET /certificates/{id}` | ✅ | ✅ | ✅ |
| `GET /certificates/{id}/usage` | ✅ | ✅ | ✅ |
| `POST /certificates/{id}/initiate-renewal` | ✅ | ✅ | ❌ |
| `POST /certificates/{id}/deploy` | ✅ | ✅ | ❌ |
| `DELETE /certificates/{id}` | ✅ | ❌ | ❌ |
| `GET /devices/` | ✅ | ✅ | ✅ |
| `POST /devices/` | ✅ | ❌ | ❌ |
| `PUT /devices/{id}/credentials` | ✅ | ❌ | ❌ |
| `POST /f5/scan` | ✅ | ✅ | ❌ |
| `GET /users/` | ✅ | ❌ | ❌ |

#### Beneficios de Azure AD SSO

| Aspecto | Auth Actual (Local) | Azure AD SSO |
|---------|---------------------|--------------|
| Login | Usuario/password manual | Single Sign-On automático |
| Gestión usuarios | Admin CMT crea cuentas | Automático desde AD |
| Grupos/Roles | Manual en CMT | Sincronizado con AD |
| Offboarding | Olvidar desactivar | Automático al salir de AD |
| Audit | Logs locales | Azure AD + CMT logs |
| MFA | No disponible | Azure AD MFA |
| Compliance | Manual | Enterprise-grade |

---

## 🚀 Features v3.0 - Full Automation

### Feature 8: CA Integration Layer (ACME + APIs)

**Estado**: 📋 Planificado para v3.0  
**Prioridad**: Alta  
**Esfuerzo estimado**: 2-3 semanas

#### Descripción
Integración directa con Certificate Authorities para automatizar completamente el ciclo de vida de certificados, eliminando la necesidad de copiar/pegar CSRs y certificados manualmente.

#### Arquitectura Multi-CA

```
┌─────────────────────────────────────────────────────────────────┐
│                  CMT v3.0 - CA ORCHESTRATOR                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                         ┌─────────────┐                        │
│                    ┌───►│ Solera PKI  │ (Microsoft AD CS)      │
│                    │    │ via ACME/   │                        │
│                    │    │ NDES        │                        │
│                    │    └─────────────┘                        │
│  ┌─────────────┐   │                                           │
│  │    CMT      │   │    ┌─────────────┐                        │
│  │   v3.0      │───┼───►│ DigiCert    │ (CertCentral API)      │
│  │             │   │    │ API         │                        │
│  │ CA Provider │   │    └─────────────┘                        │
│  │ Abstraction │   │                                           │
│  └──────┬──────┘   │    ┌─────────────┐                        │
│         │          ├───►│ Sectigo     │ (SCM API)              │
│         │          │    │ API         │                        │
│         │          │    └─────────────┘                        │
│         │          │                                           │
│         │          │    ┌─────────────┐                        │
│         │          └───►│ Let's       │ (ACME público)         │
│         │               │ Encrypt     │ (si hay servicios      │
│         │               └─────────────┘  públicos)             │
│         │                                                       │
│         │ Cert + Key                                            │
│         ▼                                                       │
│  ┌─────────────────────────────────────────┐                   │
│  │           F5 Devices (100+)             │                   │
│  │      EMEA           │        US         │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementación: Provider Abstraction

```python
# backend/services/ca_providers/base.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional

class CAType(str, Enum):
    INTERNAL_PKI = "internal_pki"    # Microsoft AD CS, EJBCA
    DIGICERT = "digicert"            # DigiCert CertCentral
    SECTIGO = "sectigo"              # Sectigo Certificate Manager
    ACME_PUBLIC = "acme_public"      # Let's Encrypt, ZeroSSL
    ACME_PRIVATE = "acme_private"    # Step-CA, Boulder (internal)

@dataclass
class CertificateRequest:
    common_name: str
    csr_pem: str
    validity_days: int = 365
    san_domains: list[str] = None
    organization: str = None
    
@dataclass
class CertificateResponse:
    certificate_pem: str
    chain_pem: str
    order_id: str
    issued_at: datetime
    expires_at: datetime
    ca_type: CAType

class CAProvider(ABC):
    """Abstract base class for Certificate Authority integrations"""
    
    @property
    @abstractmethod
    def ca_type(self) -> CAType:
        """Return the type of CA this provider handles"""
        pass
    
    @abstractmethod
    async def request_certificate(
        self, 
        request: CertificateRequest
    ) -> CertificateResponse:
        """
        Submit CSR to CA and obtain signed certificate.
        May be synchronous (internal PKI) or async (commercial CA).
        """
        pass
    
    @abstractmethod
    async def check_order_status(self, order_id: str) -> dict:
        """Check status of pending certificate order"""
        pass
    
    @abstractmethod
    async def revoke_certificate(
        self, 
        certificate_pem: str, 
        reason: str
    ) -> bool:
        """Revoke a certificate"""
        pass
    
    async def renew_certificate(
        self,
        original_cert_pem: str,
        new_csr_pem: str
    ) -> CertificateResponse:
        """Default renewal is just a new request"""
        request = CertificateRequest(
            common_name=self._extract_cn(original_cert_pem),
            csr_pem=new_csr_pem
        )
        return await self.request_certificate(request)


# backend/services/ca_providers/digicert.py
import httpx
from .base import CAProvider, CAType, CertificateRequest, CertificateResponse

class DigiCertProvider(CAProvider):
    """DigiCert CertCentral API integration"""
    
    BASE_URL = "https://www.digicert.com/services/v2"
    
    def __init__(self, api_key: str, org_id: str):
        self.api_key = api_key
        self.org_id = org_id
        self.client = httpx.AsyncClient(
            headers={"X-DC-DEVKEY": api_key}
        )
    
    @property
    def ca_type(self) -> CAType:
        return CAType.DIGICERT
    
    async def request_certificate(
        self, 
        request: CertificateRequest
    ) -> CertificateResponse:
        # 1. Create order
        order_data = {
            "certificate": {
                "common_name": request.common_name,
                "csr": request.csr_pem,
                "signature_hash": "sha256",
            },
            "organization": {"id": self.org_id},
            "validity_years": request.validity_days // 365,
            "product": {"name_id": "ssl_plus"}  # or ssl_wildcard, etc.
        }
        
        response = await self.client.post(
            f"{self.BASE_URL}/order/certificate/ssl_plus",
            json=order_data
        )
        response.raise_for_status()
        order = response.json()
        
        # 2. For OV/EV certs, may need to wait for validation
        # For DV or pre-validated domains, cert is issued immediately
        if order.get("certificate_id"):
            cert_response = await self._download_certificate(
                order["certificate_id"]
            )
            return cert_response
        
        # Return pending status
        return CertificateResponse(
            certificate_pem=None,
            chain_pem=None,
            order_id=str(order["id"]),
            issued_at=None,
            expires_at=None,
            ca_type=self.ca_type
        )
    
    async def _download_certificate(self, cert_id: int) -> CertificateResponse:
        response = await self.client.get(
            f"{self.BASE_URL}/certificate/{cert_id}/download/format/pem_all"
        )
        # Parse and return...


# backend/services/ca_providers/internal_pki.py
class InternalPKIProvider(CAProvider):
    """
    Microsoft AD CS integration via:
    - NDES (Network Device Enrollment Service)
    - EST (Enrollment over Secure Transport)
    - Or direct DCOM/RPC if on Windows
    """
    
    def __init__(self, ca_server: str, template_name: str):
        self.ca_server = ca_server
        self.template_name = template_name
    
    @property
    def ca_type(self) -> CAType:
        return CAType.INTERNAL_PKI
    
    async def request_certificate(
        self, 
        request: CertificateRequest
    ) -> CertificateResponse:
        # Option 1: Use certreq command via subprocess
        # Option 2: Use NDES/SCEP endpoint
        # Option 3: Use EST protocol
        
        # Internal PKI usually issues immediately
        cert_pem = await self._submit_to_adcs(request.csr_pem)
        
        return CertificateResponse(
            certificate_pem=cert_pem,
            chain_pem=self._get_ca_chain(),
            order_id=f"internal-{uuid.uuid4()}",
            issued_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(days=request.validity_days),
            ca_type=self.ca_type
        )


# backend/services/ca_providers/acme.py
from acme import client, messages
import josepy

class ACMEProvider(CAProvider):
    """
    Generic ACME client for any RFC 8555 compatible CA:
    - Let's Encrypt (public)
    - Step-CA (private)
    - Smallstep (private)
    - Boulder (private)
    """
    
    def __init__(
        self, 
        directory_url: str,
        account_key_pem: str,
        email: str
    ):
        self.directory_url = directory_url
        self.account_key = josepy.JWKRSA.load(account_key_pem.encode())
        self.email = email
        self._client = None
    
    @property
    def ca_type(self) -> CAType:
        if "letsencrypt" in self.directory_url:
            return CAType.ACME_PUBLIC
        return CAType.ACME_PRIVATE
    
    async def request_certificate(
        self, 
        request: CertificateRequest
    ) -> CertificateResponse:
        # 1. Create new order
        order = await self._client.new_order(
            identifiers=[
                messages.Identifier(typ="dns", value=request.common_name)
            ]
        )
        
        # 2. Complete challenges (DNS-01 for internal, HTTP-01 for public)
        for authz in order.authorizations:
            challenge = self._select_challenge(authz)
            await self._complete_challenge(challenge)
        
        # 3. Finalize with CSR
        order = await self._client.finalize_order(
            order, 
            request.csr_pem.encode()
        )
        
        # 4. Download certificate
        cert_pem = await self._client.download_certificate(order)
        
        return CertificateResponse(
            certificate_pem=cert_pem,
            chain_pem=self._extract_chain(cert_pem),
            order_id=order.uri,
            issued_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(days=90),  # LE = 90 days
            ca_type=self.ca_type
        )
```

#### Factory Pattern para Multi-CA

```python
# backend/services/ca_providers/factory.py
from .base import CAProvider, CAType
from .digicert import DigiCertProvider
from .sectigo import SectigoProvider
from .internal_pki import InternalPKIProvider
from .acme import ACMEProvider
from core.config import settings

class CAProviderFactory:
    """Factory to get the appropriate CA provider based on certificate type"""
    
    _providers: dict[CAType, CAProvider] = {}
    
    @classmethod
    def initialize(cls):
        """Initialize all configured CA providers"""
        
        if settings.DIGICERT_API_KEY:
            cls._providers[CAType.DIGICERT] = DigiCertProvider(
                api_key=settings.DIGICERT_API_KEY,
                org_id=settings.DIGICERT_ORG_ID
            )
        
        if settings.INTERNAL_PKI_SERVER:
            cls._providers[CAType.INTERNAL_PKI] = InternalPKIProvider(
                ca_server=settings.INTERNAL_PKI_SERVER,
                template_name=settings.INTERNAL_PKI_TEMPLATE
            )
        
        if settings.ACME_DIRECTORY_URL:
            cls._providers[CAType.ACME_PRIVATE] = ACMEProvider(
                directory_url=settings.ACME_DIRECTORY_URL,
                account_key_pem=settings.ACME_ACCOUNT_KEY,
                email=settings.ACME_EMAIL
            )
    
    @classmethod
    def get_provider(cls, ca_type: CAType) -> CAProvider:
        """Get CA provider by type"""
        if ca_type not in cls._providers:
            raise ValueError(f"CA provider {ca_type} not configured")
        return cls._providers[ca_type]
    
    @classmethod
    def get_provider_for_domain(cls, domain: str) -> CAProvider:
        """
        Intelligently select CA based on domain:
        - *.solera.internal → Internal PKI
        - *.solera.com → DigiCert (commercial)
        - test.* → Let's Encrypt (if public)
        """
        if ".internal" in domain or domain.endswith(".local"):
            return cls.get_provider(CAType.INTERNAL_PKI)
        
        if any(d in domain for d in ["solera.com", "solera.eu"]):
            return cls.get_provider(CAType.DIGICERT)
        
        # Default to internal PKI
        return cls.get_provider(CAType.INTERNAL_PKI)
```

#### Flujo de Renovación Automatizada

```
┌─────────────────────────────────────────────────────────────────┐
│              FLUJO RENOVACIÓN v3.0 (AUTOMÁTICO)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ANTES (v2.x - Manual):                                        │
│  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   │
│  │Admin│──►│ CMT │──►│Copy │──►│ CA  │──►│Copy │──►│ CMT │   │
│  │ve   │   │gen  │   │ CSR │   │Portal   │cert │   │deploy│   │
│  │alert│   │ CSR │   │     │   │     │   │     │   │     │   │
│  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   │
│  Tiempo total: 30-60 minutos, requiere humano                  │
│                                                                 │
│  DESPUÉS (v3.0 - Automático):                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  CMT v3.0 (Celery Beat)                 │   │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐            │   │
│  │  │1. Detect │──►│2. Gen CSR│──►│3. Submit │            │   │
│  │  │expiring  │   │+ new key │   │to CA API │            │   │
│  │  │< 30 days │   │          │   │          │            │   │
│  │  └──────────┘   └──────────┘   └────┬─────┘            │   │
│  │                                      │                  │   │
│  │  ┌──────────┐   ┌──────────┐   ┌────▼─────┐            │   │
│  │  │6. Notify │◄──│5. Deploy │◄──│4. Receive│            │   │
│  │  │ admins   │   │to F5     │   │cert from │            │   │
│  │  │(info only)   │          │   │CA        │            │   │
│  │  └──────────┘   └──────────┘   └──────────┘            │   │
│  └─────────────────────────────────────────────────────────┘   │
│  Tiempo total: 2-5 minutos, ZERO intervención humana           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Feature 9: Políticas de Renovación Inteligentes

**Estado**: 📋 Planificado para v3.0  
**Prioridad**: Alta  
**Esfuerzo estimado**: 1 semana

#### Descripción
Sistema de políticas que define cuándo y cómo renovar certificados automáticamente, con diferentes niveles de automatización según criticidad.

#### Modelo de Políticas

```python
# backend/db/models.py - Nuevos modelos

class RenewalPolicyType(str, Enum):
    AUTO_RENEW = "auto_renew"           # Renovar automáticamente
    NOTIFY_THEN_RENEW = "notify_renew"  # Notificar, esperar 24h, luego renovar
    NOTIFY_ONLY = "notify_only"         # Solo notificar, requiere aprobación
    MANUAL = "manual"                   # Sin automatización

class RenewalPolicy(Base):
    __tablename__ = "renewal_policies"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    
    # Matching criteria
    domain_pattern = Column(String(255))  # *.solera.com, *.internal
    device_group = Column(String(100))    # EMEA, US, Production
    ca_type = Column(String(50))          # internal_pki, digicert
    
    # Policy settings
    policy_type = Column(Enum(RenewalPolicyType), default=RenewalPolicyType.NOTIFY_ONLY)
    days_before_expiry = Column(Integer, default=30)
    
    # Notification settings
    notify_emails = Column(ARRAY(String))
    notify_teams_webhook = Column(String(500))
    notify_slack_channel = Column(String(100))
    
    # Approval settings
    require_approval = Column(Boolean, default=True)
    approver_group = Column(String(100))  # AD group that can approve
    auto_approve_after_hours = Column(Integer)  # Auto-approve if no response
    
    # Audit
    created_by = Column(String(100))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Priority (lower = higher priority)
    priority = Column(Integer, default=100)

class ScheduledRenewal(Base):
    __tablename__ = "scheduled_renewals"
    
    id = Column(Integer, primary_key=True)
    certificate_id = Column(Integer, ForeignKey("certificates.id"))
    policy_id = Column(Integer, ForeignKey("renewal_policies.id"))
    
    status = Column(String(50))  # pending, approved, in_progress, completed, failed
    scheduled_at = Column(DateTime)
    approved_at = Column(DateTime)
    approved_by = Column(String(100))
    completed_at = Column(DateTime)
    
    # Results
    new_certificate_id = Column(Integer)
    error_message = Column(Text)
```

#### Ejemplos de Políticas

| Política | Patrón | Tipo | Días antes | Aprobación |
|----------|--------|------|------------|------------|
| Producción Crítica | `*.prod.solera.com` | NOTIFY_ONLY | 60 | Sí, Network Admins |
| Producción Normal | `*.solera.com` | NOTIFY_THEN_RENEW | 30 | Auto después de 24h |
| Desarrollo | `*.dev.solera.internal` | AUTO_RENEW | 14 | No |
| Testing | `*.test.*` | AUTO_RENEW | 7 | No |
| Interno General | `*.internal` | AUTO_RENEW | 30 | No |

#### UI de Gestión de Políticas

```
┌─────────────────────────────────────────────────────────────────┐
│  CMT > Settings > Renewal Policies                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ + Create Policy                          [Import] [Export]│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority │ Name              │ Pattern        │ Action  │   │
│  ├──────────┼───────────────────┼────────────────┼─────────┤   │
│  │    1     │ Prod Critical     │ *.prod.solera. │ 🔔 Only │   │
│  │    2     │ Production        │ *.solera.com   │ 🔔→🔄   │   │
│  │    3     │ Development       │ *.dev.*        │ 🔄 Auto │   │
│  │    4     │ Internal          │ *.internal     │ 🔄 Auto │   │
│  │   99     │ Default           │ *              │ 🔔 Only │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Legend: 🔄 Auto-renew  🔔 Notify  🔔→🔄 Notify then renew     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Feature 10: Audit Logs y Compliance

**Estado**: 📋 Planificado para v3.0  
**Prioridad**: Media  
**Esfuerzo estimado**: 1 semana

#### Descripción
Sistema completo de audit logging para cumplir con requerimientos de compliance y facilitar investigaciones de seguridad.

#### Modelo de Audit Log

```python
# backend/db/models.py

class AuditAction(str, Enum):
    # Certificate actions
    CERT_VIEWED = "cert.viewed"
    CERT_RENEWAL_INITIATED = "cert.renewal.initiated"
    CERT_RENEWAL_APPROVED = "cert.renewal.approved"
    CERT_RENEWAL_REJECTED = "cert.renewal.rejected"
    CERT_DEPLOYED = "cert.deployed"
    CERT_DELETED = "cert.deleted"
    CERT_REVOKED = "cert.revoked"
    
    # Device actions
    DEVICE_CREATED = "device.created"
    DEVICE_UPDATED = "device.updated"
    DEVICE_CREDENTIALS_CHANGED = "device.credentials.changed"
    DEVICE_SCANNED = "device.scanned"
    DEVICE_DELETED = "device.deleted"
    
    # Policy actions
    POLICY_CREATED = "policy.created"
    POLICY_UPDATED = "policy.updated"
    POLICY_DELETED = "policy.deleted"
    
    # Auth actions
    USER_LOGIN = "auth.login"
    USER_LOGOUT = "auth.logout"
    USER_LOGIN_FAILED = "auth.login.failed"
    PERMISSION_DENIED = "auth.permission.denied"

class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(BigInteger, primary_key=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # Who
    user_id = Column(String(100))  # Azure AD Object ID
    user_email = Column(String(255))
    user_name = Column(String(255))
    user_groups = Column(ARRAY(String))
    user_ip = Column(String(45))
    user_agent = Column(String(500))
    
    # What
    action = Column(Enum(AuditAction), index=True)
    resource_type = Column(String(50))  # certificate, device, policy
    resource_id = Column(String(100))
    resource_name = Column(String(255))
    
    # Details
    details = Column(JSONB)  # Additional context
    previous_state = Column(JSONB)  # For updates
    new_state = Column(JSONB)  # For updates
    
    # Result
    success = Column(Boolean, default=True)
    error_message = Column(Text)
    
    # Correlation
    request_id = Column(String(36))  # UUID for request tracing
    session_id = Column(String(36))

# Índices para queries comunes
Index('ix_audit_user_action', AuditLog.user_email, AuditLog.action)
Index('ix_audit_resource', AuditLog.resource_type, AuditLog.resource_id)
Index('ix_audit_timestamp_action', AuditLog.timestamp, AuditLog.action)
```

#### Middleware de Auditoría

```python
# backend/middleware/audit.py
from fastapi import Request
from contextvars import ContextVar
import uuid

request_context: ContextVar[dict] = ContextVar('request_context', default={})

class AuditMiddleware:
    async def __call__(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        
        # Set context for this request
        request_context.set({
            "request_id": request_id,
            "user_ip": request.client.host,
            "user_agent": request.headers.get("user-agent"),
            "path": request.url.path,
            "method": request.method,
        })
        
        response = await call_next(request)
        return response

# Helper function to log audit events
async def log_audit(
    action: AuditAction,
    resource_type: str,
    resource_id: str,
    resource_name: str = None,
    details: dict = None,
    success: bool = True,
    error_message: str = None,
    user: AzureADUser = None,
    db: Session = None
):
    ctx = request_context.get()
    
    log = AuditLog(
        request_id=ctx.get("request_id"),
        user_id=user.id if user else None,
        user_email=user.email if user else None,
        user_name=user.name if user else None,
        user_groups=user.groups if user else None,
        user_ip=ctx.get("user_ip"),
        user_agent=ctx.get("user_agent"),
        action=action,
        resource_type=resource_type,
        resource_id=str(resource_id),
        resource_name=resource_name,
        details=details or {},
        success=success,
        error_message=error_message,
    )
    
    db.add(log)
    await db.commit()
```

#### Uso en Endpoints

```python
@router.post("/{cert_id}/deploy")
async def deploy_certificate(
    cert_id: int,
    request: DeployRequest,
    db: Session = Depends(get_db),
    user: AzureADUser = Depends(require_role([CMTRole.ADMIN, CMTRole.OPERATOR]))
):
    certificate = db.get(Certificate, cert_id)
    
    try:
        result = await deploy_to_f5(certificate, request.signed_cert_content)
        
        # Log successful deployment
        await log_audit(
            action=AuditAction.CERT_DEPLOYED,
            resource_type="certificate",
            resource_id=cert_id,
            resource_name=certificate.common_name,
            details={
                "device_id": certificate.device_id,
                "device_hostname": certificate.device.hostname,
                "profiles_updated": result.get("profiles_updated", [])
            },
            user=user,
            db=db
        )
        
        return result
        
    except Exception as e:
        # Log failed deployment
        await log_audit(
            action=AuditAction.CERT_DEPLOYED,
            resource_type="certificate",
            resource_id=cert_id,
            resource_name=certificate.common_name,
            success=False,
            error_message=str(e),
            user=user,
            db=db
        )
        raise
```

#### Dashboard de Auditoría

```
┌─────────────────────────────────────────────────────────────────┐
│  CMT > Audit Logs                              [Export CSV/PDF] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Filters:                                                       │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐  │
│  │ Date Range │ │ User       │ │ Action     │ │ Resource   │  │
│  │ Last 7 days│ │ All        │ │ All        │ │ All        │  │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Time       │ User           │ Action        │ Resource  │   │
│  ├────────────┼────────────────┼───────────────┼───────────┤   │
│  │ 10:23:45   │ john.doe@...   │ 🚀 Deployed   │ *.solera  │   │
│  │ 10:22:30   │ john.doe@...   │ ✅ Approved   │ *.solera  │   │
│  │ 09:15:00   │ jane.smith@... │ 🔄 Initiated  │ api.prod  │   │
│  │ 09:00:00   │ SYSTEM         │ 🔔 Notified   │ 5 certs   │   │
│  │ Yesterday  │ admin@...      │ ⚙️ Policy chg │ Prod Crit │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Compliance Reports:                                            │
│  [📊 Monthly Summary] [📋 All Deployments] [🔐 Access Report]  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Reportes de Compliance

```python
# backend/api/endpoints/reports.py

@router.get("/compliance/certificate-deployments")
async def certificate_deployments_report(
    start_date: date,
    end_date: date,
    db: Session = Depends(get_db),
    user: AzureADUser = Depends(require_role([CMTRole.ADMIN]))
):
    """
    Generate compliance report of all certificate deployments.
    Required for SOX, ISO 27001, PCI-DSS audits.
    """
    logs = db.query(AuditLog).filter(
        AuditLog.action == AuditAction.CERT_DEPLOYED,
        AuditLog.timestamp >= start_date,
        AuditLog.timestamp <= end_date
    ).all()
    
    return {
        "report_type": "Certificate Deployments",
        "period": f"{start_date} to {end_date}",
        "generated_at": datetime.utcnow(),
        "generated_by": user.email,
        "summary": {
            "total_deployments": len(logs),
            "successful": len([l for l in logs if l.success]),
            "failed": len([l for l in logs if not l.success]),
            "unique_certificates": len(set(l.resource_id for l in logs)),
            "unique_users": len(set(l.user_email for l in logs)),
        },
        "details": [
            {
                "timestamp": l.timestamp,
                "certificate": l.resource_name,
                "deployed_by": l.user_email,
                "device": l.details.get("device_hostname"),
                "success": l.success,
            }
            for l in logs
        ]
    }
```

---

## 📅 Timeline Tentativo

```
Diciembre 2025:
├── Semana 1: ✅ Phase 1 Cleanup completado
├── Semana 2: Feature 1 - Real-Time Usage (Backend)
├── Semana 3: Feature 1 - Real-Time Usage (Frontend)
└── Semana 4: Feature 2 - Cleanup código legacy

Enero 2025:
├── Semana 1-2: Feature 6 - Azure Container Apps + CI/CD
│   ├── Crear infraestructura Azure (Bicep)
│   ├── Configurar networking privado
│   ├── Setup CI/CD pipeline
│   └── Migración de datos
├── Semana 3: Feature 7 - Azure AD SSO
│   ├── App Registration
│   ├── Backend JWT validation
│   └── Frontend MSAL integration
└── Semana 4: Feature 7 - RBAC por grupos AD
    ├── Mapeo grupos → roles
    ├── Testing permisos
    └── Documentación

Febrero 2025:
├── Feature 3 - Refactor f5_service_logic.py
├── Feature 4 - Mejoras de seguridad adicionales
├── Feature 5 - Dashboard de métricas
└── 🎉 Release v2.5 

Marzo-Abril 2025 (v3.0):
├── Semana 1-2: Feature 8 - CA Integration Layer
│   ├── Provider abstraction base
│   ├── DigiCert API integration
│   ├── Internal PKI (AD CS) integration
│   └── ACME client para CAs privadas
├── Semana 3-4: Feature 8 - Testing & Rollout
│   ├── Testing con CA de desarrollo
│   ├── Pilot con subset de certificados
│   └── Full rollout
├── Semana 5: Feature 9 - Renewal Policies
│   ├── Policy model & UI
│   ├── Auto-renewal scheduler
│   └── Notification system
└── Semana 6: Feature 10 - Audit & Compliance
    ├── Audit logging middleware
    ├── Compliance reports
    └── 🎉 Release v3.0
```

### Priorización de Features

| # | Feature | Versión | Prioridad | Impacto |
|---|---------|---------|-----------|---------|
| 1 | Real-Time Usage Detection | v2.5 | Alta | Precisión datos |
| 6 | Azure Container Apps | v2.5 | Alta | Estabilidad + CI/CD |
| 7 | Azure AD SSO + RBAC | v2.5 | Alta | Seguridad enterprise |
| 2 | Cleanup código legacy | v2.5 | Media | Mantenibilidad |
| 3 | Refactor f5_service_logic | v2.5 | Media | Código limpio |
| 4 | Mejoras de seguridad | v2.5 | Media | Compliance |
| 5 | Dashboard métricas | v2.5 | Baja | UX |
| **8** | **CA Integration Layer** | **v3.0** | **Alta** | **Zero-touch renewals** |
| **9** | **Renewal Policies** | **v3.0** | **Alta** | **Automatización inteligente** |
| **10** | **Audit & Compliance** | **v3.0** | **Media** | **Enterprise compliance** |

### Comparativa: Manual vs Automatizado

| Métrica | CMT v2.x (Actual) | CMT v2.5 | CMT v3.0 |
|---------|-------------------|----------|----------|
| Tiempo renovación | 30-60 min | 15-20 min | 2-5 min |
| Intervención humana | 100% | 50% | 5% |
| Errores humanos | Posibles | Reducidos | Eliminados |
| Cobertura audit | Parcial | Completa | Compliance-ready |
| Escalabilidad | 100 certs | 500 certs | 10,000+ certs |

---

## 🔄 Migración del Cache

### Plan de Transición
1. **Fase A**: Implementar nuevo endpoint `/batch-usage`
2. **Fase B**: Actualizar frontend para usar nuevo endpoint
3. **Fase C**: Deprecar endpoints de cache (ya marcados)
4. **Fase D**: Eliminar tablas y código de cache
5. **Fase E**: Crear migración Alembic para drop tables

### Rollback Plan
Si la carga a los F5s es excesiva:
- Mantener cache como fallback
- Implementar circuit breaker por device
- Agregar caching en Redis con TTL corto (5 min)

---

## 📝 Notas de Implementación

### Consideraciones para 100+ F5s

1. **Connection Pooling**: Reutilizar conexiones HTTP a F5s
2. **Timeout Configuration**: 10s timeout por F5, fail fast
3. **Retry Logic**: Max 2 retries con exponential backoff
4. **Graceful Degradation**: Si un F5 no responde, mostrar "unknown" no error

### Límites Sugeridos

| Parámetro | Valor | Razón |
|-----------|-------|-------|
| Max certs por batch | 50 | Evitar timeouts |
| Max concurrent F5 connections | 10 | No saturar red |
| Query timeout | 10s | Fail fast |
| Retry attempts | 2 | Balance reliability/speed |

---

## ✅ Checklist Pre-Release v2.5

### Código y Testing
- [ ] Todos los tests pasan
- [ ] Code review completado
- [ ] Documentación de API actualizada

### Infraestructura Azure
- [ ] Container Apps Environment creado
- [ ] PostgreSQL migrado y funcionando
- [ ] Redis Cache configurado
- [ ] Networking privado validado
- [ ] CI/CD pipeline funcionando

### Seguridad
- [ ] Azure AD App Registration configurado
- [ ] Grupos AD mapeados correctamente
- [ ] JWT validation funcionando
- [ ] RBAC permisos verificados
- [ ] MFA habilitado para grupos Admin

### Operaciones
- [ ] Runbook de operaciones actualizado
- [ ] Alertas configuradas en Azure Monitor
- [ ] Backup de PostgreSQL automatizado
- [ ] Rollback plan documentado y probado

### Migración
- [ ] Datos migrados de VM actual
- [ ] Cutover plan aprobado
- [ ] Comunicación a usuarios enviada
- [ ] Período de parallel run completado

---

## ✅ Checklist Pre-Release v3.0

### CA Integration (Feature 8)
- [ ] Provider abstraction layer implementado
- [ ] Al menos 1 CA provider funcionando (DigiCert/Internal PKI)
- [ ] Certificate Request workflow testeado end-to-end
- [ ] Auto-renewal pipeline funcionando
- [ ] CSR generation probado con múltiples algoritmos
- [ ] Rollback a manual mode documentado

### Renewal Policies (Feature 9)
- [ ] Database models migrados
- [ ] Policy UI funcionando
- [ ] Certificate-to-policy matching lógica verificada
- [ ] Scheduler de auto-renewals activo
- [ ] Notification system integrado (email/Teams)
- [ ] Edge cases documentados (policy conflicts, failures)

### Audit & Compliance (Feature 10)
- [ ] Audit middleware capturando todas las acciones
- [ ] Compliance reports generándose correctamente
- [ ] SOC2/ISO27001 mapping verificado por Security team
- [ ] Log retention policy configurada
- [ ] Export to SIEM (opcional) funcionando

### Testing Avanzado v3.0
- [ ] Load testing con 1000+ certificados
- [ ] Chaos testing (CA unavailable, network failures)
- [ ] Audit log integrity verification
- [ ] Multi-CA failover testeado
- [ ] Performance benchmarks documentados

### Documentación v3.0
- [ ] Runbook actualizado con CA procedures
- [ ] Troubleshooting guide para auto-renewals
- [ ] Security review por equipo InfoSec
- [ ] Training materials para operadores

---

## 📚 Referencias

- [FASE3_DEPRECATION.md](./FASE3_DEPRECATION.md) - Documentación original del sistema de cache
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Guía de deployment actual
- [DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md) - Estado del proyecto

### Documentación Externa
- [DigiCert CertCentral API](https://dev.digicert.com/en/certcentral-apis.html)
- [ACME Protocol RFC 8555](https://tools.ietf.org/html/rfc8555)
- [Microsoft AD CS Documentation](https://docs.microsoft.com/en-us/windows-server/identity/ad-cs/active-directory-certificate-services-overview)
- [Azure Container Apps](https://docs.microsoft.com/en-us/azure/container-apps/)
- [MSAL Python Library](https://github.com/AzureAD/microsoft-authentication-library-for-python)
