# 🏠 Kaptia

Sistema completo y parametrizable para la captación y gestión de propiedades inmobiliarias, con CRM integrado, automatización de workflows y comunicación por WhatsApp.

## 📋 Componentes del Sistema

Este sistema integra múltiples servicios que trabajan conjuntamente:

- **PostgreSQL + PgVector**: Base de datos principal con soporte para vectores
- **Redis**: Sistema de caché y mensajería
- **Chatwoot**: CRM y sistema de chat multicanal
- **NocoDB**: Interfaz visual para la base de datos (tipo Airtable)
- **n8n**: Plataforma de automatización de workflows (tipo Zapier/Make)
- **WAHA**: API HTTP para WhatsApp

## 🚀 Instalación Rápida

### Requisitos Previos

1. **Servidor Linux** con:
   - Docker 20.10+
   - Docker Compose 2.0+
   - Traefik configurado (para HTTPS automático)
   - Dominio con DNS apuntando al servidor

2. **Puertos necesarios**:
   - 80, 443 (Traefik)
   - 5678 (n8n, opcional si usa Traefik)

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

5. **Crear la red de Traefik** (si no existe):
```bash
docker network create kaptia-network
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

✅ **PostgreSQL**:
- Crea extensiones necesarias (uuid-ossp, pgvector)
- Crea tablas: properties, contacts, interactions, followups, system_config
- Genera índices para búsquedas optimizadas

✅ **Chatwoot**:
- Ejecuta migraciones de base de datos
- Crea usuario administrador automáticamente
- Email: `admin@tudominio.com`
- Password: El valor de `POSTGRES_PASSWORD` de tu .env

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
- Password: El valor de `POSTGRES_PASSWORD` en tu .env

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
├── docker-compose.yml          # Configuración de servicios
├── .env                        # Variables de entorno (crear desde env.example)
├── env.example                 # Plantilla de configuración
├── setup.sh                    # Script de instalación automática
├── auto-config.sh              # Script de auto-configuración de servicios
├── README.md                   # Esta documentación
├── n8n_data/                   # Datos persistentes de n8n
├── n8n_workflows/              # Workflows de ejemplo para importar
│   ├── 1_example_property_capture.json
│   ├── 2_example_daily_followups.json
│   └── README.md
├── waha_data/                 # Datos persistentes de WAHA
└── redis_data/                # Datos persistentes de Redis
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

### Los servicios no inician:
```bash
# Verificar logs
docker-compose logs

# Verificar red de Traefik
docker network ls | grep web

# Recrear red si es necesario
docker network create web
```

### No se genera certificado SSL:
- Verificar que el DNS apunte correctamente
- Verificar logs de Traefik
- Comprobar que los puertos 80 y 443 estén abiertos

### Chatwoot no conecta con WAHA:
- Verificar variables de entorno WAHA_API_KEY
- Comprobar que ambos servicios estén en la misma red
- Revisar logs de ambos servicios

## 📞 Soporte

Para soporte técnico o consultas sobre personalización del sistema, contactar con el administrador del sistema.

## 📝 Licencia

Este software es propietario y está destinado exclusivamente para instalación en servidores de clientes autorizados.

---

**Última actualización**: Enero 2026
**Versión**: 1.0.0
