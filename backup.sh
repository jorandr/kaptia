#!/bin/bash

# =============================================================================
# Script de Backup - Property Scraper
# =============================================================================
# Este script realiza backups de todos los datos importantes del sistema
# =============================================================================

set -e

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
else
    echo "Error: Archivo .env no encontrado"
    exit 1
fi

# Configuración
BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${PROJECT_NAME}_backup_${DATE}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Crear directorio de backups
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_PATH"

echo "==================================="
echo "Iniciando Backup del Sistema"
echo "==================================="
echo "Proyecto: $PROJECT_NAME"
echo "Fecha: $(date)"
echo "Destino: $BACKUP_PATH"
echo ""

# Backup de PostgreSQL
echo "📦 Backup de PostgreSQL..."
docker-compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" > "$BACKUP_PATH/postgres_full.sql"
echo "✓ PostgreSQL backup completado"

# Backup de Redis
echo "📦 Backup de Redis..."
docker-compose exec -T redis redis-cli SAVE
docker cp ${PROJECT_NAME}_redis:/data/dump.rdb "$BACKUP_PATH/redis_dump.rdb"
echo "✓ Redis backup completado"

# Backup de n8n
echo "📦 Backup de n8n..."
tar -czf "$BACKUP_PATH/n8n_data.tar.gz" n8n_data/ 2>/dev/null || true
echo "✓ n8n backup completado"

# Backup de WAHA
echo "📦 Backup de WAHA..."
tar -czf "$BACKUP_PATH/waha_data.tar.gz" waha_data/ 2>/dev/null || true
echo "✓ WAHA backup completado"

# Backup de configuración
echo "📦 Backup de configuración..."
cp .env "$BACKUP_PATH/env.backup"
cp docker-compose.yml "$BACKUP_PATH/"
echo "✓ Configuración backup completada"

# Comprimir todo
echo "📦 Comprimiendo backup..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"
cd ..

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo "==================================="
echo "✅ Backup Completado"
echo "==================================="
echo "Archivo: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Tamaño: $BACKUP_SIZE"
echo ""
echo "Para restaurar este backup, ejecuta:"
echo "./restore.sh ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo ""

# Limpiar backups antiguos (mantener solo los últimos 7)
echo "🧹 Limpiando backups antiguos..."
cd "$BACKUP_DIR"
ls -t *.tar.gz | tail -n +8 | xargs -r rm
cd ..
echo "✓ Limpieza completada"
