#!/bin/bash

# =============================================================================
# Script de Instalación Automática - Property Scraper
# =============================================================================
# Este script facilita la instalación inicial del sistema
# =============================================================================

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones auxiliares
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

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Banner
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🏠 PROPERTY SCRAPER - Setup Automático           ║
║                                                       ║
║     Sistema de Captación Inmobiliaria                ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# =============================================================================
# 1. VERIFICAR REQUISITOS
# =============================================================================
print_header "1. Verificando Requisitos del Sistema"

# Verificar Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+')
    print_success "Docker instalado (versión $DOCKER_VERSION)"
else
    print_error "Docker no está instalado"
    print_info "Instalar Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Verificar Docker Compose
if command -v docker compose &> /dev/null || docker compose version &> /dev/null; then
    print_success "Docker Compose instalado"
else
    print_error "Docker Compose no está instalado"
    exit 1
fi

# Verificar permisos de Docker
if docker ps &> /dev/null; then
    print_success "Permisos de Docker correctos"
else
    print_error "No tienes permisos para ejecutar Docker"
    print_info "Ejecuta: sudo usermod -aG docker $USER"
    exit 1
fi

# =============================================================================
# 2. CONFIGURACIÓN INICIAL
# =============================================================================
print_header "2. Configuración Inicial"

# Crear archivo .env si no existe
if [ ! -f .env ]; then
    print_info "Creando archivo .env desde plantilla..."
    cp env.example .env
    print_success "Archivo .env creado"
else
    print_warning "El archivo .env ya existe"
    read -p "¿Deseas sobrescribirlo? (s/N): " -r
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        cp env.example .env
        print_success "Archivo .env sobrescrito"
    fi
fi

# Solicitar configuración básica
echo ""
print_info "Configuración básica del sistema"
echo ""

read -p "Nombre del proyecto (sin espacios): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-propertyscraper}

read -p "Dominio principal (ej: example.com): " DOMAIN
DOMAIN=${DOMAIN:-example.com}

read -p "Email para certificados SSL: " EMAIL
EMAIL=${EMAIL:-admin@$DOMAIN}

# Generar contraseñas seguras
print_info "Generando contraseñas seguras..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
CHATWOOT_SECRET=$(openssl rand -hex 64)
WAHA_API_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
WAHA_API_KEY_HASH=$(echo -n "$WAHA_API_KEY" | sha512sum | cut -d' ' -f1)
WAHA_DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Actualizar .env
print_info "Actualizando archivo .env..."

sed -i "s/PROJECT_NAME=.*/PROJECT_NAME=$PROJECT_NAME/" .env
sed -i "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env
sed -i "s/LETSENCRYPT_EMAIL=.*/LETSENCRYPT_EMAIL=$EMAIL/" .env
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
sed -i "s/CHATWOOT_SECRET_KEY_BASE=.*/CHATWOOT_SECRET_KEY_BASE=$CHATWOOT_SECRET/" .env
sed -i "s/WAHA_API_KEY_PLAIN=.*/WAHA_API_KEY_PLAIN=$WAHA_API_KEY/" .env
sed -i "s/WAHA_API_KEY_HASH=.*/WAHA_API_KEY_HASH=sha512:$WAHA_API_KEY_HASH/" .env
sed -i "s/WAHA_DASHBOARD_PASSWORD=.*/WAHA_DASHBOARD_PASSWORD=$WAHA_DASHBOARD_PASSWORD/" .env
sed -i "s/WAHA_SWAGGER_PASSWORD=.*/WAHA_SWAGGER_PASSWORD=$WAHA_DASHBOARD_PASSWORD/" .env

print_success "Configuración guardada en .env"

# =============================================================================
# 3. CREAR DIRECTORIOS NECESARIOS
# =============================================================================
print_header "3. Creando Directorios de Datos"

mkdir -p n8n_data waha_data redis_data
print_success "Directorios creados"

# =============================================================================
# 4. INICIAR SERVICIOS
# =============================================================================
print_header "4. Iniciando Servicios Docker"

print_info "Descargando imágenes (esto puede tardar unos minutos)..."
docker compose pull

print_info "Iniciando todos los servicios..."
docker compose up -d

# Esperar a que los servicios inicien
print_info "Esperando a que los servicios inicien..."
sleep 10

# Verificar estado
print_info "Verificando estado de los servicios..."
docker compose ps

# =============================================================================
# 4.5 CREAR BASE DE DATOS DE CHATWOOT
# =============================================================================
print_info "Creando base de datos de Chatwoot..."

# Esperar a que PostgreSQL esté listo
RETRY_COUNT=0
until docker compose exec -T postgres pg_isready -U admin &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq 15 ]; then
        print_warning "PostgreSQL tardó más de lo esperado en iniciarse"
        break
    fi
    echo -n "."
    sleep 2
done

# Crear la base de datos de Chatwoot
CHATWOOT_DB=$(grep CHATWOOT_DATABASE .env | cut -d '=' -f2)
CHATWOOT_DB=${CHATWOOT_DB:-chatwoot_production}

docker compose exec -T postgres psql -U admin -d postgres << EOSQL &>/dev/null || true
SELECT 'CREATE DATABASE $CHATWOOT_DB'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$CHATWOOT_DB')\gexec
EOSQL

print_success "Base de datos de Chatwoot creada"

# =============================================================================
# 5. AUTO-CONFIGURACIÓN
# =============================================================================
print_header "5. Auto-Configuración de Servicios"

read -p "¿Deseas ejecutar la configuración automática de los servicios? (S/n): " -r
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_info "Iniciando auto-configuración..."
    ./auto-config.sh
else
    print_warning "Auto-configuración omitida. Deberás configurar los servicios manualmente."
fi

# =============================================================================
# 6. RESUMEN FINAL
# =============================================================================
print_header "✅ Instalación Completada"

echo ""
echo -e "${GREEN}El sistema se ha instalado correctamente.${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📋 Información de Acceso:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "🌐 Chatwoot (CRM):     ${GREEN}https://chat.$DOMAIN${NC}"
echo -e "🗄️  NocoDB (Base Datos): ${GREEN}https://nocodb.$DOMAIN${NC}"
echo -e "⚡ n8n (Automatización): ${GREEN}https://n8n.$DOMAIN${NC}"
echo -e "📱 WAHA (WhatsApp):     ${GREEN}https://waha.$DOMAIN${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔐 Credenciales Importantes:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "WAHA Dashboard:"
echo -e "  Usuario: admin"
echo -e "  Password: ${GREEN}$WAHA_DASHBOARD_PASSWORD${NC}"
echo ""
echo -e "WAHA API Key:"
echo -e "  ${GREEN}$WAHA_API_KEY${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANTE: Guarda estas credenciales en un lugar seguro${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 Próximos Pasos:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Verificar que el DNS de tus dominios apunte a este servidor"
echo "2. En WAHA: escanear código QR de WhatsApp"
echo "3. En Chatwoot: conectar el canal de WhatsApp"
echo "4. En n8n: importar workflows desde la carpeta n8n_workflows/"
echo ""
echo -e "${YELLOW}💡 Tip: Las credenciales se guardaron en credentials_${PROJECT_NAME}.txt${NC}"
echo ""
echo -e "${GREEN}Para ver los logs:${NC}"
echo "  docker compose logs -f"
echo ""
echo -e "${GREEN}Para reiniciar servicios:${NC}"
echo "  docker compose restart"
echo ""
echo -e "${GREEN}Para detener todo:${NC}"
echo "  docker compose down"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}📖 Consulta el README.md para más información${NC}"
echo ""

# Guardar credenciales en archivo
cat > credentials.txt << EOF
=============================================================================
CREDENCIALES DEL SISTEMA - Property Scraper
=============================================================================
Generadas el: $(date)
Proyecto: $PROJECT_NAME
Dominio: $DOMAIN

ACCESOS WEB:
-----------
Chatwoot:   https://chat.$DOMAIN
NocoDB:     https://nocodb.$DOMAIN
n8n:        https://n8n.$DOMAIN
WAHA:       https://waha.$DOMAIN

CREDENCIALES:
------------
PostgreSQL:
  Usuario: admin
  Password: $POSTGRES_PASSWORD
  Base de datos: property_data

WAHA Dashboard:
  Usuario: admin
  Password: $WAHA_DASHBOARD_PASSWORD

WAHA API Key:
  $WAHA_API_KEY

Chatwoot Secret Key Base:
  $CHATWOOT_SECRET

=============================================================================
⚠️  MANTÉN ESTE ARCHIVO EN UN LUGAR SEGURO Y NO LO COMPARTAS
=============================================================================
EOF

print_success "Credenciales guardadas en: credentials.txt"
chmod 600 credentials.txt
print_warning "Archivo protegido con permisos 600"

print_success "¡Instalación completada! 🎉"
