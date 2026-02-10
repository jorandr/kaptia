# Workflows de Ejemplo para n8n

Esta carpeta contiene workflows predefinidos que puedes importar en n8n para comenzar rápidamente.

## 📁 Workflows Disponibles

### 1. `1_example_property_capture.json`
**Captura de Propiedades vía Webhook**

- **Trigger**: Webhook HTTP POST
- **Funcionalidad**: Recibe datos de una propiedad, los procesa, guarda en la base de datos y envía notificación por WhatsApp
- **Endpoint**: `https://n8n.tudominio.com/webhook/capture-property`

**Ejemplo de uso**:
```bash
curl -X POST https://n8n.tudominio.com/webhook/capture-property \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.example.com/propiedad/12345",
    "title": "Piso 3 habitaciones en Madrid Centro",
    "price": 250000,
    "description": "Piso amplio y luminoso",
    "phone": "+34600000000",
    "location": "Madrid Centro"
  }'
```

### 2. `2_example_daily_followups.json`
**Recordatorio Diario de Seguimientos**

- **Trigger**: Programado (cada día a las 9:00)
- **Funcionalidad**: Obtiene los seguimientos pendientes del día y envía un resumen al equipo por WhatsApp

## 📥 Cómo Importar los Workflows

### Opción 1: Desde la interfaz web de n8n

1. Accede a n8n: `https://n8n.tudominio.com`
2. Crea una cuenta o inicia sesión
3. Haz clic en el menú superior derecho > "Import from File"
4. Selecciona el archivo JSON del workflow
5. Revisa y ajusta los parámetros según tu configuración
6. Activa el workflow

### Opción 2: Copiando los archivos directamente

```bash
# Copiar workflows al directorio de n8n
cp n8n_workflows/*.json n8n_data/
```

## ⚙️ Configuración Necesaria

### 1. Credenciales de PostgreSQL

En n8n, crea una credencial de tipo "PostgreSQL":
- **Host**: `nombre_proyecto_db` (ejemplo: `kaptia_db`)
- **Database**: El valor de `POSTGRES_DB` de tu .env
- **User**: El valor de `POSTGRES_USER` de tu .env
- **Password**: El valor de `POSTGRES_PASSWORD` de tu .env
- **Port**: `5432`

### 2. Configurar Variables de Entorno en n8n

Las variables de entorno se pueden usar en los workflows con `{{ $env.VARIABLE }}`:
- `PROJECT_NAME`: Nombre del proyecto
- `WAHA_API_KEY_PLAIN`: API key de WAHA

### 3. Ajustar Números de WhatsApp

En los workflows que envían mensajes de WhatsApp, busca y reemplaza:
- `NUMERO_DESTINO@c.us` → El número de destino (ej: `34600000000@c.us`)
- `NUMERO_EQUIPO@c.us` → El número de tu equipo

## 🎨 Personalización

Estos workflows son ejemplos básicos. Puedes personalizarlos:

- **Añadir más campos** a las propiedades
- **Integrar con otros servicios** (email, Telegram, etc.)
- **Crear validaciones** personalizadas
- **Añadir lógica de negocio** específica de tu empresa
- **Conectar con Chatwoot** para crear conversaciones automáticamente

## 📚 Recursos

- [Documentación de n8n](https://docs.n8n.io/)
- [Nodos disponibles](https://docs.n8n.io/integrations/)
- [Crear workflows personalizados](https://docs.n8n.io/workflows/)
