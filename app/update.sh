#!/bin/bash

# =============================================================================
# Script de Actualización - Property Scraper
# =============================================================================
# Este script actualiza todas las imágenes Docker a sus últimas versiones
# =============================================================================

set -e

echo "==================================="
echo "Actualizando Sistema"
echo "==================================="
echo ""

# Hacer backup antes de actualizar
read -p "¿Deseas hacer un backup antes de actualizar? (S/n): " -r
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "📦 Realizando backup..."
    ./backup.sh
fi

# Detener servicios
echo "⏸️  Deteniendo servicios..."
docker-compose down

# Actualizar imágenes
echo "⬇️  Descargando últimas versiones..."
docker-compose pull

# Reiniciar servicios
echo "▶️  Iniciando servicios..."
docker-compose up -d

# Esperar y verificar
echo "⏳ Esperando a que los servicios inicien..."
sleep 15

echo ""
echo "📊 Estado de los servicios:"
docker-compose ps

echo ""
echo "==================================="
echo "✅ Actualización Completada"
echo "==================================="
echo ""
echo "Para ver los logs:"
echo "  docker-compose logs -f"
echo ""
