# 🏠 Kaptia

Sistema completo y parametrizable para la captación y gestión de propiedades inmobiliarias, con CRM integrado, automatización de workflows y comunicación por WhatsApp.

## 📋 Componentes del Sistema

Este sistema integra múltiples servicios que trabajan conjuntamente:

- **Traefik**: Reverse proxy con HTTPS automático (Let's Encrypt)
- **PostgreSQL + PgVector**: Base de datos principal con soporte para vectores
- **Redis**: Sistema de caché y mensajería
- **Chatwoot**: CRM y sistema de chat multicanal (web + worker + migrations)
- **NocoDB**: Interfaz visual para la base de datos (tipo Airtable)
- **n8n**: Plataforma de automatización de workflows (tipo Zapier/Make)
- **WAHA**: API HTTP para WhatsApp

## 🚀 Instalación Rápida

### Requisitos Previos

1. **Servidor Linux** con:
   - Docker 20.10+
   - Docker Compose 2.0+
   - Dominio con DNS apuntando al servidor

2. **Puertos necesarios**:
   - 80 (HTTP - redirige a HTTPS)
   - 443 (HTTPS)
   - 3000 (Chatwoot - solo para acceso local/debug)
   - 5678 (n8n - opcional si usa Traefik)

### Pasos de Instalación

1. **Clonar o copiar el proyecto al servidor**:
```bash
cd /opt
git clone [url-del-repositorio] property-scraper
cd property-scraper
```

2. **Configurar variables de entorno**:
```bash
cp env.example .env
nano .env
```

3. **Configurar el archivo .env** con los valores de tu instalación:
   - `PROJECT_NAME`: Nombre único para esta instalación
   - `DOMAIN`: Tu dominio principal
   - Contraseñas seguras para todas las credenciales
   - Dominios para cada servicio (chat., nocodb., n8n., waha.)

4. **Generar hash SHA512 para WAHA** (si es necesario):
```bash
echo -n "tu_api_key" | sha512sum
```

5. **Crear la red de Docker** (si no existe):
```bash
docker network create web
```

**MÉTODO RÁPIDO - Script automatizado**:
```bash
./setup.sh
```
El script de instalación te guiará por todos los pasos y puede ejecutar la auto-configuración automáticamente.

---

**MÉTODO MANUAL - Paso a paso**:

6. **Iniciar los servicios**:
```bash
docker-compose up -d
```

7. **Ejecutar auto-configuración (recomendado)**:
```bash
./auto-config.sh
```
Este script configurará automáticamente:
- Base de datos con tablas predefinidas
- Usuario administrador en Chatwoot
- Estructura inicial del sistema

8. **Verificar que los servicios estén corriendo**:
```bash
docker-compose ps
docker-compose logs -f
```

## 🤖 Auto-Configuración

El sistema incluye un script de auto-configuración que automatiza la mayoría de tareas de setup inicial:

```bash
./auto-config.sh
```

### ¿Qué configura automáticamente?

✅ **Migraciones de Chatwoot**:
- Ejecuta automáticamente las migraciones de base de datos al iniciar
- Servicio `chatwoot_migrations` se ejecuta una vez antes que web y worker
- Crea todas las tablas necesarias (installation_configs, users, accounts, etc.)
- Los servicios web y worker esperan a que las migraciones terminen

✅ **PostgreSQL**:
- Crea extensiones necesarias (uuid-ossp, pgvector)
- Crea tablas: properties, contacts, interactions, followups, system_config
- Genera índices para búsquedas optimizadas
- Base de datos separada para Chatwoot (chatwoot_production)

✅ **Chatwoot**:
- Ejecuta migraciones de base de datos
- Crea usuario administrador automáticamente
- Email: `admin@tudominio.com`
- Password: `${POSTGRES_PASSWORD}!2024` (incluye caracteres especiales requeridos)

✅ **Base de datos**:
- Estructura completa de tablas para gestión inmobiliaria
- Campos optimizados para propiedades, contactos y seguimientos
- Soporte para JSONB para datos flexibles

✅ **Credenciales**:
- Genera archivo `credentials_[proyecto].txt` con todos los accesos
- Muestra resumen completo en pantalla

### ❌ Configuración manual requerida

Estos pasos NO pueden automatizarse por seguridad:

- **Escanear QR de WhatsApp en WAHA** (requiere tu móvil)
- **Crear cuenta inicial en n8n** (primera vez)
- **Conectar canal de WhatsApp en Chatwoot** (configuración web)

## ⚙️ Configuración Inicial

### 1. Chatwoot (CRM)

**Si ejecutaste auto-config.sh**, ya tienes:
- Cuenta de administrador creada
- Email: `admin@tudominio.com`
- Password: `${POSTGRES_PASSWORD}!2024` (nota el sufijo !2024 para cumplir requisitos de seguridad)

**Configuración adicional**:
1. Acceder a `https://chat.tudominio.com`
2. Iniciar sesión con las credenciales creadas
3. Configurar:
   - Canales de comunicación (WhatsApp vía WAHA)
   - Agentes y equipos
   - Etiquetas y flujos de conversación

**Si NO ejecutaste auto-config.sh**:
1. Acceder a `https://chat.tudominio.com`
2. Crear cuenta de administrador manualmente
3. Configurar cuenta/organización

### 2. WAHA (WhatsApp)

1. Acceder a `https://waha.tudominio.com`
2. Login con credenciales del .env
3. Crear nueva sesión de WhatsApp
4. Escanear código QR con WhatsApp
5. Configurar webhook hacia Chatwoot

### 3. n8n (Automatización)

1. Acceder a `https://n8n.tudominio.com`
2. Crear cuenta de administrador
3. **Importar workflows de ejemplo**:
   - Menú > Import from File
   - Seleccionar archivos de `n8n_workflows/`
   - Workflows disponibles:
     - Captura de propiedades vía webhook
     - Recordatorio diario de seguimientos
4. Configurar credenciales de PostgreSQL en n8n:
   - Host: `${PROJECT_NAME}_db`
   - Database, User, Password: Según tu .env
5. Ajustar números de WhatsApp en los workflows

### 4. NocoDB (Base de Datos)

**Si ejecutaste auto-config.sh**, las tablas ya están creadas:
- `properties` - Propiedades inmobiliarias
- `contacts` - Contactos y leads
- `interactions` - Historial de interacciones
- `followups` - Seguimientos programados
- `system_config` - Configuración del sistema

**Pasos**:
1. Acceder a `https://nocodb.tudominio.com`
2. Conectar a la base de datos PostgreSQL (usa los datos del .env)
3. Las tablas aparecerán automáticamente
4. Puedes crear vistas, formularios y APIs personalizadas



## 📁 Estructura de Archivos

```
property-scraper/
├── docker-compose.yml          # Configuración de servicios principales
├── .env                        # Variables de entorno (crear desde env.example)
├── env.example                 # Plantilla de configuración
├── setup.sh                    # Script de instalación automática
├── auto-config.sh              # Script de auto-configuración de servicios
├── README.md                   # Esta documentación
├── traefik/                    # Configuración de Traefik (si se usa separado)
│   ├── docker-compose.yml      # Servicio de Traefik
│   ├── traefik.yml             # Configuración principal de Traefik
│   ├── setup-traefik.sh        # Script de configuración de Traefik
│   └── config/                 # Middlewares y configuración adicional
├── n8n_data/                   # Datos persistentes de n8n
├── n8n_workflows/              # Workflows de ejemplo para importar
│   ├── 1_example_property_capture.json
│   ├── 2_example_daily_followups.json
│   └── README.md
├── waha_data/                  # Datos persistentes de WAHA
└── redis_data/                 # Datos persistentes de Redis
```

## 🌐 Arquitectura del Sistema

### Servicios Docker

El sistema utiliza una arquitectura de microservicios con los siguientes contenedores:

1. **Traefik** (Opcional - puede estar en red externa)
   - Reverse proxy y balanceador de carga
   - Gestión automática de certificados SSL con Let's Encrypt
   - Dashboard de monitoreo
   - Red: `web` (externa)

2. **PostgreSQL** (`${PROJECT_NAME}_db`)
   - Base de datos principal con extensión pgvector
   - Almacena datos de propiedades, contactos y Chatwoot
   - Healthcheck integrado
   - Red: `web`

3. **Redis** (`${PROJECT_NAME}_redis`)
   - Cache y cola de mensajes para Chatwoot
   - Almacenamiento de sesiones de WAHA
   - Red: `web`

4. **Chatwoot Migrations** (`${PROJECT_NAME}_chatwoot_migrations`)
   - Servicio de inicialización (ejecución única)
   - Ejecuta `rails db:chatwoot_prepare`
   - Crea todas las tablas necesarias
   - Los demás servicios esperan su finalización exitosa
   - `restart: "no"` - No se reinicia automáticamente

5. **Chatwoot Web** (`${PROJECT_NAME}_chatwoot_web`)
   - Interfaz web del CRM
   - Puerto 3000 expuesto para acceso local
   - Depende de: postgres (healthy), redis (started), chatwoot_migrations (completed)
   - Red: `web`

6. **Chatwoot Worker** (`${PROJECT_NAME}_chatwoot_worker`)
   - Procesamiento de trabajos en segundo plano (Sidekiq)
   - Gestión de colas y tareas asíncronas
   - Depende de: postgres (healthy), redis (started), chatwoot_migrations (completed)
   - Red: `web`

7. **NocoDB** (`${PROJECT_NAME}_nocodb`)
   - Interfaz visual para base de datos
   - Puerto 8080 interno
   - Red: `web`

8. **n8n** (`${PROJECT_NAME}_n8n`)
   - Plataforma de automatización
   - Puerto 5678
   - Volumen local: `./n8n_data`
   - Red: `web`

9. **WAHA** (`${PROJECT_NAME}_whatsapp`)
   - API de WhatsApp
   - Puerto 3000 interno
   - Volumen local: `./waha_data`
   - Red: `web`

### Dependencias entre Servicios

```
Traefik (externo)
    ↓
┌───┴─────────────────────────────────────┐
│                                         │
│  PostgreSQL ← HealthCheck               │
│      ↓                                  │
│  Chatwoot Migrations (una vez)          │
│      ↓                                  │
│  ┌─────────────┬──────────────┐        │
│  │             │              │         │
│  Chatwoot Web  Chatwoot Worker         │
│  │             │              │         │
│  NocoDB        n8n          WAHA        │
│                                         │
│  Redis ← Compartido por todos           │
│                                         │
└─────────────────────────────────────────┘
            Red: web
```

## 🔐 Seguridad

### Recomendaciones importantes:

1. **Cambiar todas las contraseñas por defecto** en el archivo .env
2. **Generar SECRET_KEY_BASE seguro** (mínimo 64 caracteres):
```bash
openssl rand -hex 64
```
3. **Usar contraseñas fuertes** para bases de datos y APIs
4. **Configurar firewall** para bloquear puertos innecesarios
5. **Actualizar regularmente** las imágenes Docker:
```bash
docker-compose pull
docker-compose up -d
```
6. **Backups regulares** de los volúmenes:
```bash
docker-compose exec postgres pg_dump -U admin inmo_data > backup.sql
```

## 🛠️ Mantenimiento

### Ver logs:
```bash
docker-compose logs -f [servicio]
# Ejemplos:
docker-compose logs -f chatwoot_web
docker-compose logs -f n8n
```

### Reiniciar servicios:
```bash
docker-compose restart [servicio]
# O todos:
docker-compose restart
```

### Actualizar servicios:
```bash
docker-compose pull
docker-compose up -d
```

### Limpiar datos (¡CUIDADO! Elimina todo):
```bash
docker-compose down -v
```

## 🆘 Solución de Problemas

### Error: PG::UndefinedTable - relation "installation_configs" does not exist
**Causa**: Las migraciones de Chatwoot no se ejecutaron correctamente.

**Solución**:
```bash
# Opción 1: Reiniciar los servicios (las migraciones se ejecutan automáticamente)
docker-compose restart chatwoot_migrations chatwoot_web chatwoot_worker

# Opción 2: Ejecutar migraciones manualmente
docker-compose exec chatwoot_web bundle exec rails db:chatwoot_prepare

# Opción 3: Verificar logs del servicio de migraciones
docker-compose logs chatwoot_migrations
```

### Error: Password must contain at least 1 special character
**Causa**: La contraseña de Chatwoot debe incluir caracteres especiales.

**Solución**: El script `auto-config.sh` ya añade `!2024` a la contraseña. Si creas usuarios manualmente, asegúrate de incluir al menos un carácter especial: `!@#$%^&*()_+-=[]{}|"/\.,\`<>:;?~'`

### Los servicios no inician:
```bash
# Verificar logs
docker-compose logs

# Verificar orden de inicio
docker-compose logs chatwoot_migrations
docker-compose logs chatwoot_web
docker-compose logs chatwoot_worker

# Verificar red
docker network ls | grep web

# Recrear red si es necesario
docker network create web
```

### Chatwoot web/worker fallan al iniciar:
**Causa**: El servicio `chatwoot_migrations` no completó exitosamente.

**Solución**:
```bash
# Ver estado de todos los servicios
docker-compose ps

# Ver logs del servicio de migraciones
docker-compose logs chatwoot_migrations

# Si las migraciones fallaron, detener y reiniciar
docker-compose stop chatwoot_web chatwoot_worker
docker-compose up -d chatwoot_migrations
# Esperar a que complete
docker-compose up -d chatwoot_web chatwoot_worker
```

### No se genera certificado SSL:
- Verificar que el DNS apunte correctamente
- Verificar logs de Traefik: `docker logs traefik`
- Comprobar que los puertos 80 y 443 estén abiertos
- Verificar que `LETSENCRYPT_EMAIL` esté configurado en .env
- Si usas Traefik externo, verificar que la red `web` esté compartida

### DNS_PROBE_FINISHED_NXDOMAIN en el dashboard de Traefik:
**Causa**: El dominio no existe o no resuelve.

**Solución**:
- Verificar que el DNS de `traefik.${DOMAIN}` apunte a la IP del servidor
- Si tu dominio principal es `n8n.primehousing.es`, el dashboard estará en `traefik.n8n.primehousing.es`
- Considera usar un dominio base más simple como `primehousing.es`

### Chatwoot no conecta con WAHA:
- Verificar variables de entorno WAHA_API_KEY
- Comprobar que ambos servicios estén en la misma red
- Revisar logs de ambos servicios

## 📞 Soporte

Para soporte técnico o consultas sobre personalización del sistema, contactar con el administrador del sistema.

## 📝 Licencia

Este software es propietario y está destinado exclusivamente para instalación en servidores de clientes autorizados.

---

**Última actualización**: Febrero 2026
**Versión**: 2.0.0

### Changelog v2.0.0

**Mejoras importantes**:
- ✅ Servicio de migraciones automáticas de Chatwoot (`chatwoot_migrations`)
- ✅ Gestión de dependencias entre servicios con healthchecks
- ✅ Contraseñas de Chatwoot con validación de caracteres especiales
- ✅ Puerto 3000 de Chatwoot expuesto para debug local
- ✅ Configuración de red simplificada (externa: true)
- ✅ Documentación extendida de arquitectura y troubleshooting
- ✅ Base de datos separada para Chatwoot (chatwoot_production)
- ✅ Worker de Chatwoot independiente para mejor escalabilidad

**Cambios de configuración**:
- Red `web` debe existir previamente (externa)
- Contraseña de admin: `${POSTGRES_PASSWORD}!2024`
- Servicio `chatwoot_migrations` ejecuta `db:chatwoot_prepare`
