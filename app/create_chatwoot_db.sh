#!/bin/bash

# =============================================================================
# Script para Crear Base de Datos de Chatwoot
# =============================================================================
# Este script crea la base de datos de Chatwoot si no existe
# =============================================================================

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | grep -v '^$' | xargs)
else
    print_error "Archivo .env no encontrado"
    exit 1
fi

print_info "Creando base de datos de Chatwoot..."

# Verificar que PostgreSQL esté corriendo
if ! docker compose exec -T postgres pg_isready -U ${POSTGRES_USER} &>/dev/null; then
    print_error "PostgreSQL no está disponible. Asegúrate de que los contenedores estén corriendo."
    exit 1
fi

# Crear la base de datos
docker compose exec -T postgres psql -U ${POSTGRES_USER} -d postgres << EOSQL
SELECT 'CREATE DATABASE ${CHATWOOT_DATABASE}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${CHATWOOT_DATABASE}')\gexec
EOSQL

print_success "Base de datos ${CHATWOOT_DATABASE} verificada/creada"

# Reiniciar Chatwoot para que se conecte
print_info "Reiniciando servicios de Chatwoot..."
docker compose restart chatwoot_web chatwoot_worker

print_success "Chatwoot reiniciado correctamente"

echo ""
print_info "Esperando 10 segundos para que Chatwoot se inicie..."
sleep 10

echo ""
print_success "¡Base de datos creada! Chatwoot debería estar funcionando ahora."
echo ""
print_info "Verifica los logs con: docker compose logs -f chatwoot_web"
