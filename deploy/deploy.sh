#!/bin/bash

# =============================================================================
# Script de Deployment - Kaptia
# =============================================================================
# Deploy de la aplicación Kaptia en cualquier servidor
# Se usa tanto manualmente como desde GitHub Actions
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Variables por defecto
DEPLOY_DIR="${DEPLOY_DIR:-/opt/kaptia}"
BACKUP_DIR="${BACKUP_DIR:-/backups/kaptia}"
ENV_FILE="${ENV_FILE:-.env}"

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║          🚀 Kaptia Deployment Script                  ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# =============================================================================
# 1. VERIFICAR REQUISITOS
# =============================================================================
print_info "Verificando requisitos..."

if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose no está instalado"
    exit 1
fi

print_success "Docker y Docker Compose disponibles"

# =============================================================================
# 2. CREAR BACKUP (si existe instalación previa)
# =============================================================================
if [ -d "$DEPLOY_DIR" ] && [ -f "$DEPLOY_DIR/docker-compose.yml" ]; then
    print_info "Creando backup antes del deployment..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    cd "$DEPLOY_DIR"
    docker compose down || true
    
    tar -czf "$BACKUP_FILE" \
        --exclude='*.log' \
        --exclude='node_modules' \
        .
    
    print_success "Backup creado: $BACKUP_FILE"
fi

# =============================================================================
# 3. PREPARAR DIRECTORIO DE DEPLOYMENT
# =============================================================================
print_info "Preparando directorio de deployment..."

mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# =============================================================================
# 4. COPIAR ARCHIVOS DE LA APLICACIÓN
# =============================================================================
print_info "Copiando archivos de la aplicación..."

# Aquí se copiarían los archivos desde el repositorio
# En GitHub Actions, esto ya está hecho por el checkout

# =============================================================================
# 5. VERIFICAR ARCHIVO .env
# =============================================================================
print_info "Verificando configuración..."

if [ ! -f "$ENV_FILE" ]; then
    print_error "Archivo $ENV_FILE no encontrado"
    print_info "Crea el archivo .env con la configuración necesaria"
    exit 1
fi

print_success "Archivo .env encontrado"

# =============================================================================
# 6. PULL DE IMÁGENES
# =============================================================================
print_info "Descargando imágenes Docker..."

docker compose pull

print_success "Imágenes actualizadas"

# =============================================================================
# 7. DEPLOYMENT
# =============================================================================
print_info "Desplegando aplicación..."

docker compose up -d --remove-orphans

print_success "Aplicación desplegada"

# =============================================================================
# 8. VERIFICAR SALUD DE CONTENEDORES
# =============================================================================
print_info "Verificando estado de contenedores..."

sleep 10

FAILED_CONTAINERS=$(docker compose ps --format json | jq -r 'select(.Health == "unhealthy" or .State == "exited") | .Name' 2>/dev/null || echo "")

if [ -n "$FAILED_CONTAINERS" ]; then
    print_warning "Algunos contenedores tienen problemas:"
    echo "$FAILED_CONTAINERS"
else
    print_success "Todos los contenedores están corriendo"
fi

# =============================================================================
# 9. MOSTRAR ESTADO
# =============================================================================
print_info "Estado de la aplicación:"
docker compose ps

# =============================================================================
# RESUMEN
# =============================================================================
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║          ✓ DEPLOYMENT COMPLETADO                      ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Comandos útiles:"
echo "  • Ver logs:          docker compose logs -f"
echo "  • Reiniciar:         docker compose restart"
echo "  • Detener:           docker compose down"
echo "  • Estado:            docker compose ps"
echo ""

exit 0
