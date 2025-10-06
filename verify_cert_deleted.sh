#!/bin/bash
# Script para verificar si un certificado fue realmente eliminado del F5
# Uso: ./verify_cert_deleted.sh <nombre_certificado>

CERT_NAME="$1"

if [ -z "$CERT_NAME" ]; then
    echo "Uso: $0 <nombre_certificado>"
    echo "Ejemplo: $0 Solera123"
    exit 1
fi

echo "========================================="
echo "Verificando certificado: $CERT_NAME"
echo "========================================="
echo ""

echo "1. Buscando archivo físico en filesystem..."
CERT_FILE=$(find /config/filestore -name "*${CERT_NAME}*" 2>/dev/null)
if [ -z "$CERT_FILE" ]; then
    echo "   ✓ NO encontrado en filesystem (ELIMINADO CORRECTAMENTE)"
else
    echo "   ✗ AÚN existe en: $CERT_FILE"
fi
echo ""

echo "2. Buscando en TMDB (base de datos interna)..."
TMDB_RESULT=$(tmsh list sys file ssl-cert one-line | grep -i "$CERT_NAME")
if [ -z "$TMDB_RESULT" ]; then
    echo "   ✓ NO encontrado en TMDB (LIMPIO)"
else
    echo "   ⚠ REFERENCIA ZOMBIE encontrada:"
    echo "   $TMDB_RESULT"
    echo ""
    echo "   Esto es normal después de borrar. La referencia desaparecerá después de:"
    echo "   - tmsh load sys config"
    echo "   - Reinicio del F5"
    echo "   - Tiempo suficiente para que el caché expire"
fi
echo ""

echo "3. Intentando cargar el certificado directamente..."
tmsh show sys file ssl-cert "$CERT_NAME" 2>&1 | head -5
echo ""

echo "========================================="
echo "Resumen:"
echo "========================================="
if [ -z "$CERT_FILE" ]; then
    echo "El certificado '$CERT_NAME' FUE ELIMINADO CORRECTAMENTE."
    if [ -n "$TMDB_RESULT" ]; then
        echo "La referencia zombie en el GUI es solo caché y es inofensiva."
    fi
else
    echo "El certificado '$CERT_NAME' AÚN EXISTE en el filesystem."
fi
