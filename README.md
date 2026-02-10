# 🏠 Kaptia

Sistema de captación inmobiliaria con CRM, automatización y WhatsApp.

**Componentes:** Chatwoot (CRM) • n8n (Automatización) • NocoDB • WAHA (WhatsApp) • PostgreSQL • Redis • Traefik

## 📁 Estructura

```
kaptia/
├── infrastructure/     # Setup del servidor (una vez)
├── app/               # Aplicación (docker-compose + scripts)
├── deploy/            # Scripts de deployment
└── .github/           # GitHub Actions CI/CD
```

## 🚀 Instalación

### Opción 1: CI/CD Automático (Recomendado para tus servidores)

**1. Preparar servidor:**
```bash
sudo bash infrastructure/server-setup.sh
```

**2. Configurar GitHub Secrets:**
```
Settings > Secrets > Actions

Por cada cliente, crea estos secrets con el prefijo del cliente:

# Conexión SSH
PRIMEHOUSING_SSH_PRIVATE_KEY
PRIMEHOUSING_SSH_USER
PRIMEHOUSING_SERVER_HOST

# Configuración básica
PRIMEHOUSING_PROJECT_NAME          # ej: primehousing
PRIMEHOUSING_DOMAIN                # ej: primehousing.es

# Base de datos
PRIMEHOUSING_POSTGRES_PASSWORD     # Generar con: openssl rand -base64 32

# Chatwoot
PRIMEHOUSING_CHATWOOT_SECRET_KEY_BASE  # Generar con: openssl rand -hex 64

# WAHA (WhatsApp)
PRIMEHOUSING_WAHA_API_KEY_PLAIN        # Generar con: openssl rand -base64 32
PRIMEHOUSING_WAHA_DASHBOARD_PASSWORD   # Generar con: openssl rand -base64 16
```

**3. Deploy automático:**
```bash
# Deploy manual desde GitHub UI:
Actions > Deploy to Production > Run workflow
Selecciona el cliente (CLIENTE1, CLIENTE2, MISERVIDOR)
```

### Opción 2: Manual (Para servidor del cliente)

**1. Preparar servidor:**
```bash
cd /opt
sudo git clone <repo-url> kaptia
cd kaptia
sudo bash infrastructure/server-setup.sh
```

**2. Configurar app:**
```bash
cd app
cp env.example .env
nano .env  # Editar con tus valores
```

**3. Desplegar:**
```bash
./setup.sh  # Script interactivo
# O manual: docker compose up -d && ./auto-config.sh
```

## 🔑 Generar Credenciales

```bash
openssl rand -hex 64  # CHATWOOT_SECRET_KEY_BASE
openssl rand -base64 32 | tr -d "=+/" | cut -c1-25  # Contraseñas
echo -n "tu_key" | sha512sum | cut -d' ' -f1  # WAHA hash
```

## 🔄 Operaciones

```bash
# Estado
docker compose ps
./monitor.sh

# Logs
docker compose logs -f

# Backup
./backup.sh

# Actualizar
git push origin main  # Con CI/CD
./update.sh  # Manual
```

## GitHub Actions

**Workflows incluidos:**
- `deploy.yml` - Deploy automático (push a main)
- `validate.yml` - Validación en PRs
- `rollback.yml` - Rollback manual

**Secrets requeridos:** Ver ejemplo en [.github/workflows/deploy.yml](.github/workflows/deploy.yml)
