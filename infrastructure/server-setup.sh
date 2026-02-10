#!/bin/bash

# =============================================================================
# Script de Configuración de Infraestructura - Kaptia
# =============================================================================
# Instala todas las dependencias y requisitos en un servidor nuevo
# Compatible con: Ubuntu 20.04+, Ubuntu 22.04, Ubuntu 24.04 LTS, Debian 11+
# Optimizado para: Ubuntu 24.04 LTS (Noble Numbat)
# =============================================================================

set -e  # Detener en el primer error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Banner inicial
clear
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      🏠 KAPTIA - Configuración de Infraestructura         ║
║                                                            ║
║        Preparación del Servidor para Deployment           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script debe ejecutarse como root o con sudo"
    echo "Ejecuta: sudo bash server-setup.sh"
    exit 1
fi

# Verificar requisitos mínimos del sistema
print_info "Verificando requisitos del sistema..."

# Verificar memoria RAM (mínimo 2GB recomendado)
TOTAL_RAM=$(free -m | awk '/^Mem:/ {print $2}')
if [ "$TOTAL_RAM" -lt 2000 ]; then
    print_warning "Memoria RAM baja: ${TOTAL_RAM}MB (recomendado: 2GB+)"
else
    print_success "Memoria RAM: ${TOTAL_RAM}MB"
fi

# Verificar espacio en disco (mínimo 10GB)
AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_DISK" -lt 10 ]; then
    print_warning "Espacio en disco bajo: ${AVAILABLE_DISK}GB (recomendado: 10GB+)"
else
    print_success "Espacio en disco: ${AVAILABLE_DISK}GB disponibles"
fi

# Verificar arquitectura
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" ]] && [[ "$ARCH" != "arm64" ]]; then
    print_error "Arquitectura no soportada: $ARCH"
    exit 1
fi
print_success "Arquitectura: $ARCH"

# =============================================================================
# 1. ACTUALIZAR SISTEMA
# =============================================================================
print_header "1. Actualizando Sistema"

UBUNTU_VERSION=$(lsb_release -cs)
UBUNTU_RELEASE=$(lsb_release -rs)
print_info "Ubuntu $UBUNTU_RELEASE ($UBUNTU_VERSION) detectado"

# Actualizar índices de paquetes
print_info "Actualizando índices de paquetes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Upgrade del sistema
print_info "Actualizando paquetes del sistema..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

print_success "Sistema actualizado"

# =============================================================================
# 2. INSTALAR DEPENDENCIAS BÁSICAS
# =============================================================================
print_header "2. Instalando Dependencias Básicas"

apt-get install -y curl wget git openssl ca-certificates gnupg lsb-release
apt-get install -y htop nano vim net-tools ufw fail2ban software-properties-common apt-transport-https

print_success "Dependencias básicas instaladas"

# =============================================================================
# 3. INSTALAR DOCKER
# =============================================================================
print_header "3. Instalando Docker"

if command -v docker &> /dev/null; then
    print_warning "Docker ya instalado"
else
    print_info "Instalando Docker..."
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
    print_success "Docker instalado y habilitado"
fi

# =============================================================================
# 4. CONFIGURAR FIREWALL
# =============================================================================
print_header "4. Configurando Firewall (UFW)"

ufw --force enable
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
print_success "Firewall configurado"

# =============================================================================
# 5. CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================================
print_header "5. Preparando Estructura de Directorios"

mkdir -p /opt/kaptia
mkdir -p /backups/kaptia
chmod 755 /opt/kaptia
chmod 700 /backups/kaptia
print_success "Directorios creados"

# =============================================================================
# 6. CREAR USUARIO DE DEPLOYMENT
# =============================================================================
print_header "6. Creando Usuario de Deployment"

if id "kaptia" &>/dev/null; then
    print_warning "Usuario 'kaptia' ya existe"
else
    useradd -m -s /bin/bash -G docker kaptia
    print_success "Usuario 'kaptia' creado y agregado al grupo docker"
fi

# =============================================================================
# RESUMEN
# =============================================================================
print_header "Resumen de Instalación"

echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║       ✓ CONFIGURACIÓN DE SERVIDOR COMPLETADA              ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Sistema preparado para deployment de Kaptia"
print_info "Usuario de deployment: kaptia"
print_info "Directorio de aplicación: /opt/kaptia"
echo ""
print_warning "Próximos pasos:"
echo "  1. Configura las SSH keys para el usuario kaptia"
echo "  2. Usa GitHub Actions para deployar la aplicación"
echo ""

exit 0
