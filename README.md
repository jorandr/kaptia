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
- SSH_PRIVATE_KEY, SSH_USER, SERVER_HOST
- DOMAIN, PROJECT_NAME
- Contraseñas (POSTGRES_PASSWORD, CHATWOOT_SECRET_KEY_BASE, etc.)
```

**3. Deploy automático:**
```bash
git push origin main  # Deploy automático
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
