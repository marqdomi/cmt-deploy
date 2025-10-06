#!/bin/bash
# Script de despliegue automatizado a producción
# Uso: ./deploy_production.sh

set -e  # Detener en cualquier error

echo "=================================================="
echo "🚀 DESPLIEGUE A PRODUCCIÓN - CMT Deploy"
echo "=================================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 1. Verificar que estamos en el directorio correcto
echo "1. Verificando directorio..."
if [ ! -f "docker-compose.prod.yml" ]; then
    print_error "Error: No se encuentra docker-compose.prod.yml"
    print_error "Asegúrate de estar en el directorio raíz del proyecto"
    exit 1
fi
print_status "Directorio correcto"
echo ""

# 2. Verificar que existe .env.prod
echo "2. Verificando variables de entorno..."
if [ ! -f ".env.prod" ]; then
    print_error "Error: No se encuentra .env.prod"
    print_warning "Crea el archivo .env.prod basándote en .env.example"
    exit 1
fi
print_status "Archivo .env.prod encontrado"
echo ""

# 3. Pull de cambios desde GitHub
echo "3. Actualizando código desde GitHub..."
git pull origin main
if [ $? -eq 0 ]; then
    print_status "Código actualizado desde GitHub"
else
    print_error "Error al hacer git pull"
    exit 1
fi
echo ""

# 4. Actualizar submódulo app/ si existe
if [ -d "app/.git" ]; then
    echo "4. Actualizando submódulo app/..."
    cd app
    git pull origin main
    cd ..
    print_status "Submódulo actualizado"
    echo ""
fi

# 5. Construir frontend
echo "5. Construyendo frontend..."
if [ -d "app/frontend" ]; then
    cd app/frontend
    
    # Verificar si node_modules existe, si no, instalar
    if [ ! -d "node_modules" ]; then
        print_warning "Instalando dependencias de npm (primera vez)..."
        npm ci
    fi
    
    # Build
    print_warning "Ejecutando npm run build..."
    npm run build
    
    if [ -d "dist" ]; then
        print_status "Frontend construido exitosamente en app/frontend/dist/"
        ls -lh dist/ | head -5
    else
        print_error "Error: No se generó el directorio dist/"
        exit 1
    fi
    
    cd ../..
else
    print_warning "Directorio app/frontend no encontrado, saltando build"
fi
echo ""

# 6. Verificar certificados SSL
echo "6. Verificando certificados SSL..."
if [ -f "nginx/certs/selfsigned.crt" ] && [ -f "nginx/certs/selfsigned.key" ]; then
    print_status "Certificados SSL encontrados"
else
    print_warning "Certificados SSL no encontrados en nginx/certs/"
    print_warning "Se usarán certificados autofirmados por defecto"
fi
echo ""

# 7. Detener servicios actuales
echo "7. Deteniendo servicios actuales..."
docker-compose -f docker-compose.prod.yml down
print_status "Servicios detenidos"
echo ""

# 8. Construir imágenes
echo "8. Construyendo imágenes Docker (esto puede tardar varios minutos)..."
docker-compose -f docker-compose.prod.yml build --no-cache
if [ $? -eq 0 ]; then
    print_status "Imágenes construidas exitosamente"
else
    print_error "Error al construir imágenes"
    exit 1
fi
echo ""

# 9. Levantar servicios
echo "9. Levantando servicios en modo detached..."
docker-compose -f docker-compose.prod.yml up -d
if [ $? -eq 0 ]; then
    print_status "Servicios iniciados"
else
    print_error "Error al levantar servicios"
    exit 1
fi
echo ""

# 10. Esperar a que los servicios estén healthy
echo "10. Esperando a que los servicios estén healthy..."
echo "    (esto puede tomar 30-60 segundos)..."
sleep 10

for i in {1..12}; do
    echo -n "    Verificando intento $i/12... "
    HEALTHY=$(docker-compose -f docker-compose.prod.yml ps | grep -c "healthy" || true)
    TOTAL=$(docker-compose -f docker-compose.prod.yml ps | grep -c "Up" || true)
    echo "$HEALTHY/$TOTAL servicios healthy"
    
    if [ "$HEALTHY" -ge 5 ]; then
        print_status "Todos los servicios están healthy"
        break
    fi
    
    if [ $i -eq 12 ]; then
        print_warning "No todos los servicios están healthy después de 2 minutos"
        print_warning "Revisa los logs con: docker-compose -f docker-compose.prod.yml logs"
    fi
    
    sleep 10
done
echo ""

# 11. Mostrar estado de servicios
echo "11. Estado de servicios:"
docker-compose -f docker-compose.prod.yml ps
echo ""

# 12. Verificar acceso
echo "12. Verificando acceso a la aplicación..."
echo "    Probando healthcheck endpoint..."
HEALTH_RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/healthz || echo "000")
if [ "$HEALTH_RESPONSE" = "200" ]; then
    print_status "Healthcheck respondió correctamente (200 OK)"
else
    print_warning "Healthcheck respondió con código: $HEALTH_RESPONSE"
fi
echo ""

# 13. Resumen final
echo "=================================================="
echo "📋 RESUMEN DEL DESPLIEGUE"
echo "=================================================="
echo ""
print_status "Código actualizado desde GitHub"
print_status "Frontend construido"
print_status "Imágenes Docker construidas"
print_status "Servicios levantados"
echo ""

echo "🌐 URLs de Acceso:"
echo "   Frontend:    https://puswgiprbamar01.int.audatex.com"
echo "   API:         https://puswgiprbamar01.int.audatex.com/api/v1"
echo "   Healthcheck: https://puswgiprbamar01.int.audatex.com/healthz"
echo ""

echo "📊 Comandos Útiles:"
echo "   Ver logs:           docker-compose -f docker-compose.prod.yml logs -f"
echo "   Ver logs backend:   docker-compose -f docker-compose.prod.yml logs -f backend"
echo "   Ver estado:         docker-compose -f docker-compose.prod.yml ps"
echo "   Detener servicios:  docker-compose -f docker-compose.prod.yml down"
echo "   Restart servicio:   docker-compose -f docker-compose.prod.yml restart <servicio>"
echo ""

echo "✅ Próximos Pasos:"
echo "   1. Verificar que el frontend carga en el navegador"
echo "   2. Hacer login con usuario admin"
echo "   3. Probar la funcionalidad de limpieza de certificados"
echo "   4. Revisar logs para asegurar que no hay errores"
echo ""

echo "=================================================="
print_status "¡DESPLIEGUE COMPLETADO!"
echo "=================================================="
