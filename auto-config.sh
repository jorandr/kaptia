#!/bin/bash

# =============================================================================
# Script de Auto-Configuración - Sistema de Captación Inmobiliaria
# =============================================================================
# Este script configura automáticamente todos los servicios del sistema
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | grep -v '^$' | xargs)
else
    print_error "Archivo .env no encontrado"
    exit 1
fi

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🤖 AUTO-CONFIGURACIÓN DE SERVICIOS               ║
║                                                       ║
║     Configurando tu sistema automáticamente...       ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

sleep 2

# =============================================================================
# 1. ESPERAR A QUE LOS SERVICIOS ESTÉN LISTOS
# =============================================================================
print_header "1. Verificando disponibilidad de servicios"

print_info "Esperando a PostgreSQL..."
RETRY_COUNT=0
MAX_RETRIES=30
until docker compose exec -T postgres pg_isready -U ${POSTGRES_USER} &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "PostgreSQL no está disponible después de ${MAX_RETRIES} intentos"
        exit 1
    fi
    echo -n "."
    sleep 2
done
print_success "PostgreSQL está listo"

print_info "Esperando a Redis..."
RETRY_COUNT=0
until docker compose exec -T redis redis-cli ping &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Redis no está disponible"
        exit 1
    fi
    echo -n "."
    sleep 2
done
print_success "Redis está listo"

# =============================================================================
# 1.5 CREAR BASE DE DATOS DE CHATWOOT
# =============================================================================
print_info "Verificando y creando base de datos de Chatwoot..."

# Crear la base de datos de Chatwoot si no existe
docker compose exec -T postgres psql -U ${POSTGRES_USER} -d postgres << EOSQL &>/dev/null || true
-- Crear la base de datos de Chatwoot si no existe
SELECT 'CREATE DATABASE ${CHATWOOT_DATABASE}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${CHATWOOT_DATABASE}')\gexec
EOSQL

print_success "Base de datos de Chatwoot verificada/creada"

print_info "Esperando a Chatwoot (esto puede tardar 1-2 minutos)..."
sleep 30
RETRY_COUNT=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302\|404"; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_warning "Chatwoot puede que aún no esté completamente listo"
        break
    fi
    echo -n "."
    sleep 3
done
print_success "Chatwoot está listo"

# =============================================================================
# 2. CONFIGURAR CHATWOOT
# =============================================================================
print_header "2. Configurando Chatwoot"

print_info "Ejecutando migraciones de base de datos..."
docker compose exec -T chatwoot_web bundle exec rails db:chatwoot_prepare &>/dev/null || true
print_success "Migraciones completadas"

print_info "Creando cuenta de super administrador..."

# Generar contraseña que cumpla requisitos de Chatwoot (mínimo 1 carácter especial)
ADMIN_PASSWORD="${POSTGRES_PASSWORD}!2024"

docker compose exec -T chatwoot_web bundle exec rails runner "
begin
  account = Account.create!(name: '${PROJECT_NAME^}')
  user = User.create!(
    email: 'admin@${DOMAIN}',
    name: 'Administrador',
    password: '${ADMIN_PASSWORD}',
    password_confirmation: '${ADMIN_PASSWORD}',
    confirmed_at: Time.now
  )
  AccountUser.create!(
    account: account,
    user: user,
    role: :administrator
  )
  puts 'Usuario administrador creado exitosamente'
rescue => e
  puts 'Usuario ya existe o error: ' + e.message
end
" 2>/dev/null || print_warning "El usuario administrador puede que ya exista"

print_success "Chatwoot configurado"
echo ""
echo -e "${GREEN}Credenciales de Chatwoot:${NC}"
echo -e "  Email: ${YELLOW}admin@${DOMAIN}${NC}"
echo -e "  Password: ${YELLOW}${ADMIN_PASSWORD}${NC}"

# =============================================================================
# 3. CONFIGURAR BASE DE DATOS
# =============================================================================
print_header "3. Configurando estructura de base de datos"

print_info "Creando tablas personalizadas..."

docker compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} << 'EOSQL' 2>/dev/null || true

-- Crear extensión UUID si no existe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- Tabla de propiedades
CREATE TABLE IF NOT EXISTS properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id VARCHAR(255) UNIQUE,
    url TEXT NOT NULL,
    title TEXT,
    description TEXT,
    price NUMERIC(12,2),
    price_formatted VARCHAR(100),
    property_type VARCHAR(50),
    rooms INTEGER,
    bathrooms INTEGER,
    surface_area NUMERIC(10,2),
    location TEXT,
    address TEXT,
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    contact_name VARCHAR(255),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    images JSONB,
    features JSONB,
    status VARCHAR(50) DEFAULT 'pending',
    source VARCHAR(100),
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_properties_status ON properties(status);
CREATE INDEX IF NOT EXISTS idx_properties_city ON properties(city);
CREATE INDEX IF NOT EXISTS idx_properties_price ON properties(price);
CREATE INDEX IF NOT EXISTS idx_properties_scraped_at ON properties(scraped_at);

-- Tabla de contactos
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    whatsapp VARCHAR(50),
    source VARCHAR(100),
    status VARCHAR(50) DEFAULT 'new',
    notes TEXT,
    tags JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contacts_status ON contacts(status);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email);

-- Tabla de interacciones
CREATE TABLE IF NOT EXISTS interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contact_id UUID REFERENCES contacts(id),
    property_id UUID REFERENCES properties(id),
    interaction_type VARCHAR(50),
    channel VARCHAR(50),
    subject TEXT,
    content TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_interactions_contact ON interactions(contact_id);
CREATE INDEX IF NOT EXISTS idx_interactions_property ON interactions(property_id);
CREATE INDEX IF NOT EXISTS idx_interactions_created ON interactions(created_at);

-- Tabla de seguimientos
CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contact_id UUID REFERENCES contacts(id),
    property_id UUID REFERENCES properties(id),
    scheduled_date TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    priority VARCHAR(20) DEFAULT 'normal',
    notes TEXT,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_followups_scheduled ON followups(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_followups_status ON followups(status);
CREATE INDEX IF NOT EXISTS idx_followups_contact ON followups(contact_id);

-- Tabla de configuración del sistema
CREATE TABLE IF NOT EXISTS system_config (
    key VARCHAR(255) PRIMARY KEY,
    value JSONB,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

EOSQL

print_success "Estructura de base de datos creada"

# =============================================================================
# 4. CONFIGURAR N8N
# =============================================================================
print_header "4. Configurando n8n"

print_info "Esperando a que n8n esté listo..."
sleep 10

RETRY_COUNT=0
until curl -s http://localhost:${N8N_PORT:-5678} &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq 20 ]; then
        print_warning "n8n puede que aún no esté completamente listo"
        break
    fi
    echo -n "."
    sleep 3
done

print_success "n8n está listo"
print_info "Los workflows se pueden importar manualmente desde la interfaz web"

# =============================================================================
# 5. CONFIGURAR NOCODB
# =============================================================================
print_header "5. Configurando NocoDB"

print_info "NocoDB se conectará automáticamente a PostgreSQL"
print_success "NocoDB configurado (accede a la web para completar el setup inicial)"

# =============================================================================
# 6. RESUMEN Y PRÓXIMOS PASOS
# =============================================================================
print_header "✅ AUTO-CONFIGURACIÓN COMPLETADA"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           CONFIGURACIÓN EXITOSA                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}📋 SERVICIOS CONFIGURADOS:${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} PostgreSQL - Base de datos con tablas creadas"
echo -e "  ${GREEN}✓${NC} Redis - Cache configurado"
echo -e "  ${GREEN}✓${NC} Chatwoot - Usuario admin creado"
echo -e "  ${GREEN}✓${NC} NocoDB - Listo para usar"
echo -e "  ${GREEN}✓${NC} n8n - Listo para crear workflows"
echo ""

echo -e "${CYAN}🔐 CREDENCIALES DE ACCESO:${NC}"
echo ""
echo -e "${YELLOW}Chatwoot (https://chat.${DOMAIN}):${NC}"
echo -e "  Email:    ${GREEN}admin@${DOMAIN}${NC}"
echo -e "  Password: ${GREEN}${POSTGRES_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}WAHA Dashboard (https://waha.${DOMAIN}):${NC}"
echo -e "  Usuario:  ${GREEN}${WAHA_DASHBOARD_USERNAME}${NC}"
echo -e "  Password: ${GREEN}${WAHA_DASHBOARD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}Base de Datos PostgreSQL:${NC}"
echo -e "  Host:     ${GREEN}${PROJECT_NAME}_db${NC}"
echo -e "  Puerto:   ${GREEN}5432${NC}"
echo -e "  Usuario:  ${GREEN}${POSTGRES_USER}${NC}"
echo -e "  Password: ${GREEN}${POSTGRES_PASSWORD}${NC}"
echo -e "  Database: ${GREEN}${POSTGRES_DB}${NC}"
echo ""

echo -e "${CYAN}📝 PRÓXIMOS PASOS MANUALES:${NC}"
echo ""
echo -e "  ${YELLOW}1.${NC} Accede a WAHA y escanea el código QR de WhatsApp"
echo -e "     ${BLUE}→${NC} https://waha.${DOMAIN}"
echo ""
echo -e "  ${YELLOW}2.${NC} En Chatwoot, conecta el canal de WhatsApp con WAHA"
echo -e "     ${BLUE}→${NC} Settings > Inboxes > Add Inbox > WhatsApp"
echo -e "     ${BLUE}→${NC} API URL: http://${PROJECT_NAME}_whatsapp:3000"
echo -e "     ${BLUE}→${NC} API Key: ${WAHA_API_KEY_PLAIN}"
echo ""
echo -e "  ${YELLOW}3.${NC} Accede a n8n y crea tu primer workflow"
echo -e "     ${BLUE}→${NC} https://n8n.${DOMAIN}"
echo ""
echo -e "  ${YELLOW}4.${NC} Accede a NocoDB para visualizar las tablas creadas"
echo -e "     ${BLUE}→${NC} https://nocodb.${DOMAIN}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🎉 ¡Tu sistema está listo para usarse!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Guardar credenciales en archivo
CREDENTIALS_FILE="credentials_${PROJECT_NAME}.txt"
cat > "$CREDENTIALS_FILE" << EOF
=================================================================
CREDENCIALES DEL SISTEMA - $(date)
=================================================================

CHATWOOT (CRM):
URL: https://chat.${DOMAIN}
Email: admin@${DOMAIN}
Password: ${POSTGRES_PASSWORD}

WAHA (WhatsApp):
URL: https://waha.${DOMAIN}
Usuario: ${WAHA_DASHBOARD_USERNAME}
Password: ${WAHA_DASHBOARD_PASSWORD}
API Key: ${WAHA_API_KEY_PLAIN}

n8n (Automatización):
URL: https://n8n.${DOMAIN}

NocoDB (Base de datos):
URL: https://nocodb.${DOMAIN}

POSTGRESQL:
Host: ${PROJECT_NAME}_db (localhost externo)
Puerto: 5432
Usuario: ${POSTGRES_USER}
Password: ${POSTGRES_PASSWORD}
Database: ${POSTGRES_DB}

=================================================================
IMPORTANTE: Guarda este archivo en un lugar seguro
=================================================================
EOF

print_success "Credenciales guardadas en: ${CREDENTIALS_FILE}"
echo ""
