#!/bin/bash
# Script para eliminar manualmente la key zombie que quedó
# Uso: ./cleanup_zombie_key.sh <nombre_key> [particion]

KEY_NAME="$1"
PARTITION="${2:-Common}"

if [ -z "$KEY_NAME" ]; then
    echo "❌ Error: Debes proporcionar el nombre de la key"
    echo "Uso: $0 <nombre_key> [particion]"
    echo "Ejemplo: $0 Solera123"
    echo "Ejemplo: $0 Solera123 Common"
    exit 1
fi

echo "========================================="
echo "Limpiando key zombie: $KEY_NAME"
echo "Partición: $PARTITION"
echo "========================================="
echo ""

# Verificar si la key existe
echo "1. Verificando si la key existe..."
if tmsh list sys file ssl-key $KEY_NAME partition $PARTITION &>/dev/null; then
    echo "   ✓ Key encontrada"
    
    # Verificar si está en uso
    echo ""
    echo "2. Verificando si la key está en uso..."
    IN_USE=$(tmsh -q -c 'list ltm profile client-ssl one-line; list ltm profile server-ssl one-line' | grep -i "$KEY_NAME")
    
    if [ -n "$IN_USE" ]; then
        echo "   ⚠️  WARNING: La key está en uso:"
        echo "$IN_USE"
        echo ""
        echo "   ❌ NO SE PUEDE ELIMINAR - Está siendo usada por perfiles SSL"
        exit 1
    else
        echo "   ✓ La key NO está en uso - Seguro para eliminar"
    fi
    
    # Eliminar la key
    echo ""
    echo "3. Eliminando la key..."
    tmsh delete sys file ssl-key $KEY_NAME partition $PARTITION
    
    if [ $? -eq 0 ]; then
        echo "   ✓ Key eliminada exitosamente"
        
        # Guardar configuración
        echo ""
        echo "4. Guardando configuración..."
        tmsh save sys config
        echo "   ✓ Configuración guardada"
        
        echo ""
        echo "========================================="
        echo "✅ ÉXITO: Key '$KEY_NAME' eliminada completamente"
        echo "========================================="
    else
        echo "   ❌ Error al eliminar la key"
        exit 1
    fi
else
    echo "   ℹ️  La key '$KEY_NAME' no existe (ya fue eliminada o nunca existió)"
fi
