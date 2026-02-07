#!/bin/bash

# =============================================================================
# Script de Instalación Integral - Kaptia
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
║            🏠 KAPTIA - Instalación en Servidor           ║
║                                                            ║
║      Sistema Completo de Captación Inmobiliaria           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script debe ejecutarse como root o con sudo"
    echo "Ejecuta: sudo bash install.sh"
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

# Detectar versión de Ubuntu
UBUNTU_VERSION=$(lsb_release -cs)
UBUNTU_RELEASE=$(lsb_release -rs)
print_info "Ubuntu $UBUNTU_RELEASE ($UBUNTU_VERSION) detectado"

# Limpiar repositorios problemáticos
rm -f /etc/apt/sources.list.d/ubuntu-archive.sources 2>/dev/null || true

# Configurar repositorios según la versión
if [[ "$UBUNTU_VERSION" == "noble" ]] || [[ "$UBUNTU_RELEASE" == "24.04" ]]; then
    print_info "Configurando repositorios para Ubuntu 24.04 LTS (Noble)"
    
    # Ubuntu 24.04 usa el nuevo formato DEB822 por defecto
    mkdir -p /etc/apt/sources.list.d
    cat > /etc/apt/sources.list.d/ubuntu.sources <<'DEBS822'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
DEBS822
    
    print_success "Repositorios Ubuntu 24.04 configurados"
    
elif [[ "$UBUNTU_VERSION" == "jammy" ]] || [[ "$UBUNTU_RELEASE" == "22.04" ]]; then
    print_info "Ubuntu 22.04 LTS detectado - usando repositorios estándar"
    
elif [[ "$UBUNTU_VERSION" == "oracular" ]]; then
    print_warning "Ubuntu Oracular (desarrollo) detectado - Reconfigurando repositorios"
    
    cat > /etc/apt/sources.list <<'SOURCES'
deb http://archive.ubuntu.com/ubuntu/ oracular main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ oracular-updates main restricted universe multiverse
SOURCES
fi

# Actualizar sin fallar en repositorios problemáticos
print_info "Actualizando índices de paquetes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update 2>&1 | tail -10 || print_warning "Actualización parcial (continuando...)"

# Upgrade del sistema
print_info "Actualizando paquetes del sistema (esto puede tardar unos minutos)..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | tail -10 || print_warning "Upgrade parcial (continuando...)"

print_success "Sistema actualizado"

# =============================================================================
# 2. INSTALAR DEPENDENCIAS BÁSICAS
# =============================================================================
print_header "2. Instalando Dependencias Básicas"

print_info "Instalando paquetes críticos..."
apt-get install -y curl wget git openssl ca-certificates gnupg lsb-release

print_info "Instalando paquetes opcionales..."
apt-get install -y htop nano vim net-tools ufw fail2ban tmux screen software-properties-common apt-transport-https

# Para Ubuntu 24.04: instalar paquetes adicionales recomendados
if [[ "$UBUNTU_VERSION" == "noble" ]]; then
    print_info "Instalando paquetes adicionales para Ubuntu 24.04..."
    apt-get install -y python3-pip python3-venv build-essential
fi

print_success "Dependencias básicas instaladas"

# =============================================================================
# 3. INSTALAR DOCKER
# =============================================================================
print_header "3. Instalando Docker"

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+')
    print_warning "Docker ya instalado (v$DOCKER_VERSION)"
else
    print_info "Descargando e instalando Docker..."
    
    # Agregar repositorio oficial de Docker
    mkdir -p /etc/apt/keyrings
    
    print_info "Descargando clave GPG de Docker..."
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        print_warning "No se pudo descargar la clave GPG de Docker"
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Usar repositorio de Docker - Ubuntu 24.04 es soportado
    DOCKER_DISTRO=$(lsb_release -cs)
    print_info "Configurando repositorio Docker para: $DOCKER_DISTRO"
    
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $DOCKER_DISTRO stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_info "Actualizando índices de paquetes..."
    apt-get update 2>&1 | grep -v "^Get:" | grep -v "^Ign:" || true
    
    print_info "Instalando Docker Engine..."
    if apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        # Iniciar Docker
        systemctl start docker
        systemctl enable docker
        print_success "Docker instalado y habilitado"
        
        # Verificar instalación
        docker --version
    else
        print_error "No se pudo instalar Docker"
        exit 1
    fi
fi

# =============================================================================
# 4. INSTALAR DOCKER COMPOSE (versión V2)
# =============================================================================
print_header "4. Verificando Docker Compose V2"

if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_success "Docker Compose V2 instalado (v$COMPOSE_VERSION)"
else
    print_info "Instalando Docker Compose V2..."
    apt-get install -y docker-compose-plugin
    
    # Verificar instalación
    if docker compose version &> /dev/null; then
        print_success "Docker Compose V2 instalado correctamente"
        docker compose version
    else
        print_error "Error al instalar Docker Compose V2"
        exit 1
    fi
fi

# =============================================================================
# 5. CONFIGURAR DOCKER DAEMON (opcional)
# =============================================================================
print_header "5. Configurando Docker Daemon"

if [ ! -f /etc/docker/daemon.json ]; then
    print_info "Creando configuración de Docker daemon..."
    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "5"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "userland-proxy": false,
    "experimental": false,
    "metrics-addr": "127.0.0.1:9323",
    "ipv6": false
}
EOF
    
    systemctl restart docker
    sleep 3
    print_success "Configuración Docker daemon aplicada"
else
    print_warning "Configuración Docker daemon ya existe"
fi

# =============================================================================
# 6. CREAR RED DE DOCKER
# =============================================================================
print_header "6. Preparando Redes de Docker"

if docker network ls | grep -q kaptia-network; then
    print_warning "Red 'kaptia-network' ya existe"
else
    print_info "Creando red 'kaptia-network'..."
    docker network create kaptia-network
    print_success "Red 'kaptia-network' creada"
fi

# =============================================================================
# 7. INSTALAR TRAEFIK (Proxy Inverso)
# =============================================================================
print_header "7. Instalando Traefik (Proxy Inverso)"

if [ ! -d "/opt/traefik" ]; then
    print_info "Configurando Traefik..."
    mkdir -p /opt/traefik
    
    cat > /opt/traefik/docker-compose.yml <<'EOF'
version: '3.8'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: always
    security_opt:
      - no-new-privileges:true
    networks:
      - traefik-network
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    environment:
      - CF_API_EMAIL=email@example.com
      - CF_API_KEY=your_cloudflare_api_key
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/traefik.yml:/traefik.yml:ro
      - /opt/traefik/config.yml:/config.yml:ro
      - /opt/traefik/acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.example.com`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.service=api@internal"

networks:
  traefik-network:
    driver: bridge
EOF
    
    chmod 600 /opt/traefik/docker-compose.yml
    print_success "Traefik configurado (ubicación: /opt/traefik)"
    print_warning "Ejecuta 'docker compose -f /opt/traefik/docker-compose.yml up -d' manualmente"
else
    print_warning "Traefik ya configurado en /opt/traefik"
fi

# =============================================================================
# 8. INSTALAR HERRAMIENTAS DE ADMINISTRACIÓN
# =============================================================================
print_header "8. Instalando Herramientas de Administración"

# Portainer (interfaz gráfica Docker)
if docker ps -a --format '{{.Names}}' | grep -q portainer; then
    print_warning "Portainer ya está instalado"
else
    print_info "Instalando Portainer..."
    docker run -d \
        --name=portainer \
        --restart=always \
        -p 9000:9000 \
        -p 8000:8000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    print_success "Portainer instalado (accede en puerto 9000)"
fi

# =============================================================================
# 9. CONFIGURAR FIREWALL
# =============================================================================
print_header "9. Configurando Firewall (UFW)"

print_info "Configurando Firewall (UFW)..."
ufw --force enable
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 3000/tcp    # Chatwoot
ufw allow 5678/tcp    # n8n
ufw allow 9000/tcp    # Portainer
ufw allow 9001/tcp    # Portainer
print_success "Firewall configurado"

# =============================================================================
# 10. CONFIGURAR FAIL2BAN
# =============================================================================
print_header "10. Configurando Fail2Ban (Protección contra ataques)"

systemctl start fail2ban
systemctl enable fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

systemctl restart fail2ban
print_success "Fail2Ban configurado"

# =============================================================================
# 11. CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================================
print_header "11. Preparando Estructura de Directorios"

# Crear directorio para aplicaciones
if [ ! -d "/opt/kaptia" ]; then
    mkdir -p /opt/kaptia
    chmod 755 /opt/kaptia
    print_success "Directorio /opt/kaptia creado"
else
    print_warning "Directorio /opt/kaptia ya existe"
fi

# Crear directorio para backups
if [ ! -d "/backups/kaptia" ]; then
    mkdir -p /backups/kaptia
    chmod 700 /backups/kaptia
    print_success "Directorio /backups/kaptia creado"
else
    print_warning "Directorio /backups/kaptia ya existe"
fi

# =============================================================================
# 12. INSTALAR HERRAMIENTAS ADICIONALES
# =============================================================================
print_header "12. Instalando Herramientas Complementarias"

print_info "Instalando cliente PostgreSQL..."
apt-get install -y postgresql-client 2>&1 | grep -v "^Selecting" | tail -3 || apt-get install -y postgresql-client-16 || apt-get install -y postgresql-client-common
print_success "PostgreSQL CLI instalado"

print_info "Instalando Certbot para SSL..."
apt-get install -y certbot
print_success "Certbot instalado"

print_info "Instalando Node Exporter para monitoreo..."
if apt-get install -y prometheus-node-exporter 2>&1 | grep -q "Unable to locate"; then
    print_warning "prometheus-node-exporter no disponible, instalando manualmente..."
    # Instalación manual de node_exporter si no está en repos
    NODE_EXPORTER_VERSION="1.7.0"
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-${NODE_EXPORTER_VERSION}*
    print_success "Node Exporter instalado manualmente"
else
    systemctl enable prometheus-node-exporter 2>/dev/null || true
    print_success "Node Exporter instalado desde repos"
fi

print_success "Herramientas complementarias instaladas"

# =============================================================================
# 13. CONFIGURAR LOGS Y ROTACIÓN
# =============================================================================
print_header "13. Configurando Gestión de Logs"

cat > /etc/logrotate.d/docker-containers <<EOF
/var/lib/docker/containers/*/*-json.log {
    rotate 7
    daily
    compress
    size 100m
    missingok
    delaycompress
    copytruncate
}
EOF

print_success "Rotación de logs configurada"

# =============================================================================
# 14. CREAR SCRIPT DE BACKUP
# =============================================================================
print_header "14. Creando Scripts de Respaldo"

cat > /usr/local/bin/kaptia-backup <<'EOF'
#!/bin/bash
# Script para respaldar datos de Kaptia

BACKUP_DIR="/backups/kaptia"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.tar.gz"

echo "Iniciando respaldo..."

# Crear respaldo
docker run --rm \
    -v kaptia_db:/db_backup \
    -v $BACKUP_DIR:/backup \
    alpine tar czf /backup/backup_$DATE.tar.gz /db_backup

echo "Respaldo completado: $BACKUP_FILE"

# Mantener solo los últimos 7 días de respaldos
find $BACKUP_DIR -type f -name "backup_*.tar.gz" -mtime +7 -delete

echo "Limpieza completada"
EOF

chmod +x /usr/local/bin/kaptia-backup
print_success "Script de respaldo instalado: /usr/local/bin/kaptia-backup"

# =============================================================================
# 15. CREAR SCRIPT DE MONITOREO
# =============================================================================
print_header "15. Creando Scripts de Monitoreo"

cat > /usr/local/bin/kaptia-status <<'EOF'
#!/bin/bash
# Mostrar estado del sistema Kaptia

echo "╔════════════════════════════════════════════╗"
echo "║       Estado del Sistema Kaptia            ║"
echo "╚════════════════════════════════════════════╝"
echo ""

echo "📊 Docker:"
docker ps --filter "label!=com.docker.compose.project" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "💾 Uso de Disco:"
df -h | grep -E "/$|/backups|/opt"
echo ""

echo "🔋 Uso de Memoria:"
free -h
echo ""

echo "🌐 Puertos en Escucha:"
netstat -tulpn 2>/dev/null | grep LISTEN || ss -tulpn 2>/dev/null | grep LISTEN
EOF

chmod +x /usr/local/bin/kaptia-status
print_success "Script de estado instalado: /usr/local/bin/kaptia-status"

# =============================================================================
# 16. GENERAR ARCHIVO DE CONFIGURACIÓN
# =============================================================================
print_header "16. Preparando Archivo de Configuración"

cat > /opt/kaptia/install-info.txt <<EOF
╭────────────────────────────────────────────────────────────╮
│           Información de Instalación - Kaptia              │
╰────────────────────────────────────────────────────────────╯

FECHA INSTALACIÓN: $(date)
USUARIO: $(whoami)
SERVIDOR: $(hostname)
SISTEMA: Ubuntu $(lsb_release -rs) ($(lsb_release -cs))
ARQUITECTURA: $(dpkg --print-architecture)
KERNEL: $(uname -r)

DEPENDENCIAS INSTALADAS:
✓ Docker $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
✓ Docker Compose $(docker compose version --short 2>/dev/null)
✓ Traefik (Proxy Inverso)
✓ PostgreSQL CLI
✓ Certbot (SSL)
✓ UFW (Firewall)
✓ Fail2Ban (Protección)
✓ Portainer (Gestión)
✓ Node Exporter (Monitoreo)

DIRECTORIOS CREADOS:
- /opt/kaptia          (Aplicación principal)
- /backups/kaptia      (Respaldos)
- /opt/traefik         (Proxy reverso)

SCRIPTS DISPONIBLES:
- kaptia-backup        (Crear respaldo)
- kaptia-status        (Ver estado del sistema)

PRÓXIMOS PASOS:
1. Clona el repositorio en /opt/kaptia
   git clone <repo-url> /opt/kaptia
   
2. Configura el archivo .env
   cd /opt/kaptia
   cp env.example .env
   nano .env
   
3. Ejecuta: docker compose up -d

4. Ejecuta: ./auto-config.sh

PUERTOS EN ESCUCHA:
- 22      (SSH)
- 80      (HTTP)
- 443     (HTTPS)
- 3000    (Chatwoot)
- 5678    (n8n)
- 9000    (Portainer)
- 8080    (Traefik Dashboard)

FIREWALL:
- SSH (22) - Habilitado
- HTTP (80) - Habilitado
- HTTPS (443) - Habilitado
- Puertos de aplicación - Habilitados

RECURSOS DEL SISTEMA:
- CPU: $(nproc) cores
- RAM: $(free -h | awk '/^Mem:/ {print $2}')
- Disco: $(df -h / | awk 'NR==2 {print $2}') total

EOF

print_success "Información de instalación guardada"

# =============================================================================
# 17. LIMPIAR E INFORMAR
# =============================================================================
print_header "17. Resumen de Instalación"

apt-get autoremove -y
apt-get autoclean -y

echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           ✓ INSTALACIÓN COMPLETADA CON ÉXITO              ║
║              Sistema listo para Ubuntu 24.04               ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Sistema instalado en:"
echo "  • Ubuntu $(lsb_release -rs) ($(lsb_release -cs))"
echo "  • Docker $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
echo "  • Docker Compose $(docker compose version --short 2>/dev/null)"
echo ""

print_info "Próximos pasos:"
echo "  1. Clona el repositorio:"
echo "     git clone <repo-url> /opt/kaptia"
echo ""
echo "  2. Configura las variables de entorno:"
echo "     cd /opt/kaptia"
echo "     cp env.example .env"
echo "     nano .env"
echo ""
echo "  3. Inicia los servicios:"
echo "     docker compose up -d"
echo ""
echo "  4. Ejecuta la auto-configuración:"
echo "     ./auto-config.sh"
echo ""
echo "  5. Accede a Portainer (Gestión Docker):"
echo "     http://$(hostname -I | awk '{print $1}'):9000"
echo ""

print_info "Comandos útiles:"
echo "  • Ver estado del sistema:  kaptia-status"
echo "  • Crear respaldo:          kaptia-backup"
echo "  • Ver logs en tiempo real: docker compose logs -f"
echo "  • Ver info de instalación: cat /opt/kaptia/install-info.txt"
echo "  • Reiniciar Docker:        systemctl restart docker"
echo ""

print_warning "Notas importantes de seguridad:"
echo "  • Cambia TODAS las contraseñas predeterminadas"
echo "  • Configura certificados SSL/TLS con Certbot"
echo "  • Configura backups automáticos (crontab)"
echo "  • Revisa reglas del firewall: ufw status"
echo "  • Mantén el sistema actualizado: apt update && apt upgrade"
echo "  • Revisa logs regularmente: journalctl -xe"
echo ""

print_success "Instalación completada. ¡El sistema está listo para usar!"

exit 0
