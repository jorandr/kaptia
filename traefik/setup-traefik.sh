#!/bin/bash

# =============================================================================
# Script de Configuración de Traefik
# =============================================================================

set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

cd "$(dirname "$0")"

# Cargar variables de entorno del proyecto principal
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '#' | grep -v '^$' | xargs)
else
    print_error "Archivo .env no encontrado en el directorio padre"
    exit 1
fi

print_info "Configurando Traefik..."

# Crear archivo acme.json con permisos correctos
if [ ! -f acme.json ]; then
    touch acme.json
    chmod 600 acme.json
    print_success "Archivo acme.json creado"
else
    chmod 600 acme.json
    print_success "Permisos de acme.json verificados"
fi

# Crear red si no existe
if ! docker network ls | grep -q "web"; then
    docker network create web
    print_success "Red 'web' creada"
else
    print_success "Red 'web' ya existe"
fi

# Generar credenciales para el dashboard si no existen
if [ -z "$TRAEFIK_DASHBOARD_AUTH" ]; then
    read -p "Usuario para dashboard de Traefik [admin]: " TRAEFIK_USER
    TRAEFIK_USER=${TRAEFIK_USER:-admin}
    
    read -sp "Contraseña para dashboard: " TRAEFIK_PASS
    echo ""
    
    # Generar hash de contraseña
    TRAEFIK_DASHBOARD_AUTH=$(docker run --rm httpd:alpine htpasswd -nb "$TRAEFIK_USER" "$TRAEFIK_PASS")
    
    # Guardar en .env del proyecto principal
    echo "" >> ../.env
    echo "# Traefik Dashboard" >> ../.env
    echo "TRAEFIK_DASHBOARD_AUTH='$TRAEFIK_DASHBOARD_AUTH'" >> ../.env
    
    print_success "Credenciales del dashboard configuradas"
fi

# Iniciar Traefik
print_info "Iniciando Traefik..."
docker compose up -d

print_success "Traefik configurado e iniciado correctamente"
echo ""
echo -e "${GREEN}Dashboard de Traefik:${NC} https://traefik.${DOMAIN}"
echo -e "${GREEN}Usuario:${NC} ${TRAEFIK_USER:-admin}"
echo ""
print_info "Los certificados SSL se generarán automáticamente al acceder a los dominios"
