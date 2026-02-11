# 🏠 Kaptia - Multi-tenant CRM

CRM con WhatsApp, automatización y base de datos. Deployment automático vía GitHub Actions.

**Stack:** Chatwoot • n8n • NocoDB • WAHA • PostgreSQL • Redis • Traefik

---

## 🚀 Quick Start

### 1. Preparar servidor (una vez)
```bash
ssh root@tu-servidor
bash <(curl -s https://raw.githubusercontent.com/tu-repo/kaptia/main/infrastructure/server-setup.sh)
```

### 2. Configurar Traefik (una vez)
```bash
cd /opt/traefik
bash setup-traefik.sh
```

### 3. Secrets en GitHub

#### Compartidos (configurar 1 vez):
```
SHARED_SSH_PRIVATE_KEY       # Tu clave SSH privada
SHARED_SSH_USER              # root
SHARED_SERVER_HOST           # IP del servidor
SHARED_LETSENCRYPT_EMAIL     # tu@email.com
```

#### Por cliente (4 secrets):
```bash
# Generar valores
./generate-secrets.sh CLIENTE1

# Crear en GitHub:
CLIENTE1_PROJECT_NAME              # cliente1
CLIENTE1_DOMAIN                    # cliente1.com
CLIENTE1_POSTGRES_PASSWORD         # (del script)
CLIENTE1_CHATWOOT_SECRET_KEY_BASE  # (del script)
```

### 4. Deploy

1. GitHub Actions → "🚀 Deploy to Production"
2. Seleccionar cliente → Run workflow

**Dominios auto-generados:**
- `crm.cliente1.com` - Chatwoot
- `n8n.cliente1.com` - Automatización
- `waha.cliente1.com` - WhatsApp API
- `db.cliente1.com` - NocoDB

---

## 📦 Agregar nuevo cliente

1. **Configurar DNS:** 4 subdominios → IP servidor
2. **Agregar a workflow:** Editar `.github/workflows/deploy.yml` línea 10
3. **Generar secrets:** `./generate-secrets.sh CLIENTE2`
4. **Crear 4 secrets** en GitHub
5. **Deploy:** GitHub Actions → Seleccionar cliente

---

## 🔧 Comandos útiles

```bash
# Ver contenedores
docker ps

# Logs de un cliente
cd /opt/kaptia-cliente1
docker compose logs -f chatwoot_web

# Reiniciar servicios
docker compose restart

# Ver estado
docker compose ps
```

---

## 📂 Estructura

```
/opt/
├── traefik/              # Proxy compartido
├── kaptia-cliente1/      # Instancia cliente 1
├── kaptia-cliente2/      # Instancia cliente 2
└── kaptia-clienteN/      # Instancia cliente N
```

Cada instancia es completamente independiente.

---

## 🆘 Troubleshooting

**Contenedor no inicia:**
```bash
cd /opt/kaptia-cliente1
docker compose down && docker compose up -d
docker compose logs -f
```

**SSL no funciona:**
```bash
# Verificar DNS
nslookup crm.cliente1.com

# Ver logs Traefik
docker logs traefik
```

**Error de permisos:**
```bash
sudo chown -R 1000:1000 /opt/kaptia-cliente1/n8n_data
sudo chown -R 1000:1000 /opt/kaptia-cliente1/waha_data
```
