# 🚀 Guía de Despliegue a Producción

## ✅ Pre-requisitos

Antes de desplegar en producción, verifica que tienes:

- [ ] Acceso SSH al servidor de producción
- [ ] Git instalado en el servidor
- [ ] Docker y Docker Compose instalados
- [ ] Permisos para ejecutar comandos sudo
- [ ] Certificados SSL válidos en `nginx/certs/`
- [ ] Variables de entorno de producción configuradas

---

## 📦 Paso 1: Actualizar el Código en el Servidor

### 1.1 Conectarse al Servidor de Producción

```bash
ssh usuario@puswgiprbamar01.int.audatex.com
```

### 1.2 Navegar al Directorio del Proyecto

```bash
cd /ruta/al/proyecto/cmt-deploy
```

### 1.3 Hacer Pull de los Últimos Cambios

```bash
# Ver el estado actual
git status

# Hacer pull de los cambios desde GitHub
git pull origin main

# Si tienes submódulos (app/), actualizarlos también
cd app
git pull origin main
cd ..
```

---

## 🔐 Paso 2: Configurar Variables de Entorno

### 2.1 Crear/Actualizar archivo `.env.prod`

```bash
# Editar el archivo de variables de entorno
nano .env.prod
```

### 2.2 Contenido Requerido de `.env.prod`

```bash
# Database
DATABASE_URL=postgresql+psycopg2://cmt:STRONG_PASSWORD_HERE@db:5432/cmt
POSTGRES_PASSWORD=STRONG_PASSWORD_HERE

# Redis & Celery
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/1

# Security (IMPORTANTE: Cambiar estos valores!)
JWT_SECRET=GENERATE_STRONG_SECRET_HERE_32_CHARS_MIN
ENCRYPTION_KEY=GENERATE_STRONG_KEY_HERE_32_CHARS_MIN

# F5 Credentials (encriptados)
# Estos se configuran usando el script set_credential.py

# Celery Configuration
CELERY_CONCURRENCY=8
CELERY_PREFETCH=1
CELERY_LOGLEVEL=info

# Application
FORWARDED_ALLOW_IPS=*
```

### 2.3 Generar Secrets Seguros

```bash
# Para JWT_SECRET
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Para ENCRYPTION_KEY (debe ser exactamente 32 bytes para Fernet)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 2.4 Configurar Credenciales de F5

```bash
# Entrar al contenedor de backend
docker-compose -f docker-compose.prod.yml exec backend bash

# Configurar credencial
python set_credential.py
# Seguir las instrucciones interactivas
```

---

## 🏗️ Paso 3: Construir el Frontend

El frontend debe construirse ANTES de levantar los contenedores de producción.

```bash
# Navegar al directorio del frontend
cd app/frontend

# Instalar dependencias (solo si es primera vez o hay cambios)
npm ci

# Construir para producción
npm run build

# Verificar que se creó el directorio dist/
ls -la dist/

# Volver a la raíz
cd ../..
```

**✅ CRÍTICO**: El archivo `docker-compose.prod.yml` monta `./app/frontend/dist` en nginx. Si este directorio no existe, nginx no podrá servir el frontend.

---

## 🐳 Paso 4: Desplegar con Docker Compose

### 4.1 Detener Servicios Actuales (si existen)

```bash
# Detener servicios sin eliminar volúmenes (mantiene la BD)
docker-compose -f docker-compose.prod.yml down

# Si necesitas limpiar completamente (CUIDADO: elimina la BD)
# docker-compose -f docker-compose.prod.yml down -v
```

### 4.2 Construir y Levantar Servicios

```bash
# Construir imágenes (fuerza rebuild)
docker-compose -f docker-compose.prod.yml build --no-cache

# Levantar servicios en modo detached
docker-compose -f docker-compose.prod.yml up -d

# Ver logs en tiempo real
docker-compose -f docker-compose.prod.yml logs -f
```

### 4.3 Verificar Estado de Servicios

```bash
# Ver estado de todos los servicios
docker-compose -f docker-compose.prod.yml ps

# Todos deben estar en estado "Up (healthy)"
```

---

## 🔍 Paso 5: Verificación Post-Despliegue

### 5.1 Verificar Healthchecks

```bash
# Verificar que todos los servicios estén healthy
docker-compose -f docker-compose.prod.yml ps

# Espera ver algo como:
# NAME       STATUS
# backend    Up (healthy)
# worker     Up (healthy)
# beat       Up (healthy)
# nginx      Up (healthy)
# db         Up (healthy)
# redis      Up (healthy)
```

### 5.2 Verificar Logs de Cada Servicio

```bash
# Backend
docker-compose -f docker-compose.prod.yml logs backend | tail -50

# Worker (Celery)
docker-compose -f docker-compose.prod.yml logs worker | tail -50

# Beat (Scheduler)
docker-compose -f docker-compose.prod.yml logs beat | tail -50

# Nginx
docker-compose -f docker-compose.prod.yml logs nginx | tail -50
```

### 5.3 Verificar Base de Datos

```bash
# Entrar al contenedor de PostgreSQL
docker-compose -f docker-compose.prod.yml exec db psql -U cmt -d cmt

# Verificar tablas
\dt

# Verificar que existan usuarios
SELECT username, role FROM users;

# Salir
\q
```

### 5.4 Crear Usuario Admin Inicial (si es primera instalación)

```bash
# Entrar al contenedor de backend
docker-compose -f docker-compose.prod.yml exec backend bash

# Ejecutar script de creación de usuarios
python create_initial_users.py

# Salir
exit
```

---

## 🌐 Paso 6: Pruebas Funcionales

### 6.1 Verificar Acceso Web

```bash
# Desde el servidor (interno)
curl -k https://localhost/healthz

# Debe responder: ok
```

### 6.2 Verificar Frontend

Abre en un navegador:
```
https://puswgiprbamar01.int.audatex.com
```

Debes ver:
- ✅ Página de login
- ✅ Sin errores de consola (F12)
- ✅ Recursos cargando correctamente

### 6.3 Verificar API

```bash
# Test de login
curl -k -X POST https://puswgiprbamar01.int.audatex.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'

# Debe devolver un token JWT
```

### 6.4 Probar Nuevas Funcionalidades

1. **Login** como usuario ADMIN
2. Navegar a **Certificates** (`/certificates`)
3. Verificar que el botón de eliminar (🗑️) aparece
4. Navegar a **Certificate Cleanup** (`/certificate-cleanup`)
5. Seleccionar un dispositivo F5
6. Ejecutar análisis
7. Verificar métricas y clasificación

---

## 📊 Paso 7: Monitoreo Continuo

### 7.1 Monitorear Logs en Tiempo Real

```bash
# Todos los servicios
docker-compose -f docker-compose.prod.yml logs -f

# Solo backend
docker-compose -f docker-compose.prod.yml logs -f backend

# Solo worker (para ver tareas Celery)
docker-compose -f docker-compose.prod.yml logs -f worker
```

### 7.2 Verificar Uso de Recursos

```bash
# Ver uso de CPU y memoria
docker stats

# Ver espacio en disco
df -h

# Ver logs de Docker
sudo journalctl -u docker -f
```

---

## 🔄 Paso 8: Actualizaciones Futuras

Para futuras actualizaciones, sigue este procedimiento simplificado:

```bash
# 1. Pull de cambios
git pull origin main
cd app && git pull origin main && cd ..

# 2. Rebuild del frontend (si hubo cambios)
cd app/frontend
npm ci
npm run build
cd ../..

# 3. Rebuild y restart de servicios
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

# 4. Verificar logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## 🚨 Troubleshooting

### Problema: Servicios no inician

```bash
# Ver logs detallados
docker-compose -f docker-compose.prod.yml logs backend
docker-compose -f docker-compose.prod.yml logs db

# Verificar configuración
docker-compose -f docker-compose.prod.yml config
```

### Problema: Frontend no carga

```bash
# Verificar que dist/ existe
ls -la app/frontend/dist/

# Si no existe, construir
cd app/frontend
npm run build
cd ../..

# Restart nginx
docker-compose -f docker-compose.prod.yml restart nginx
```

### Problema: Base de datos no conecta

```bash
# Verificar que el contenedor está healthy
docker-compose -f docker-compose.prod.yml ps db

# Ver logs de PostgreSQL
docker-compose -f docker-compose.prod.yml logs db

# Verificar variables de entorno
docker-compose -f docker-compose.prod.yml exec backend env | grep DATABASE
```

### Problema: Celery no procesa tareas

```bash
# Ver logs del worker
docker-compose -f docker-compose.prod.yml logs worker

# Ver logs del beat
docker-compose -f docker-compose.prod.yml logs beat

# Verificar conexión a Redis
docker-compose -f docker-compose.prod.yml exec worker redis-cli -h redis ping
```

---

## 📋 Checklist Final de Despliegue

- [ ] Git pull completado exitosamente
- [ ] Submódulo `app/` actualizado
- [ ] `.env.prod` configurado con secrets fuertes
- [ ] Credenciales F5 configuradas con `set_credential.py`
- [ ] Frontend construido (`app/frontend/dist/` existe)
- [ ] Servicios levantados con `docker-compose up -d`
- [ ] Todos los servicios en estado "healthy"
- [ ] Base de datos accesible y con tablas
- [ ] Usuario admin creado
- [ ] Frontend carga en el navegador
- [ ] Login funcional
- [ ] API responde correctamente
- [ ] Página de cleanup accesible (`/certificate-cleanup`)
- [ ] Botón de eliminar visible en `/certificates`
- [ ] Logs sin errores críticos

---

## 🎉 ¡Despliegue Completado!

Si todos los checks están verdes, tu aplicación está funcionando correctamente en producción.

### URLs de Acceso

- **Frontend**: https://puswgiprbamar01.int.audatex.com
- **API**: https://puswgiprbamar01.int.audatex.com/api/v1
- **Healthcheck**: https://puswgiprbamar01.int.audatex.com/healthz

### Próximos Pasos

1. Configurar monitoreo y alertas
2. Configurar backups automáticos de la base de datos
3. Configurar rotación de logs
4. Documentar procedimientos operativos

---

**Documentación Relacionada:**
- `DEPLOYMENT_GUIDE.md` - Guía técnica de componentes
- `README.md` - Documentación general del proyecto
- `app/backend/README.md` - Documentación del backend
