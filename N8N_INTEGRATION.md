# 🔄 Guía de Integración con n8n

Esta guía explica cómo configurar workflows en n8n para automatizar la captación de propiedades.

## 📋 Workflows Recomendados

### 1. Workflow Básico de Captación

```
Trigger (Webhook/Schedule) 
  → HTTP Request (External API) 
  → Process Data 
  → Save to Database (NocoDB/PostgreSQL) 
  → Notify (WhatsApp/Email)
```

## 🚀 Configuración de Nodos

### Nodo 1: Trigger (Webhook)

Crea un webhook para recibir URLs de propiedades:

```
Método: POST
Ruta: /webhook/property
Body: {
  "url": "https://www.idealista.com/inmueble/12345678/"
}
```

### Nodo 2: HTTP Request - External API

Configuración para llamar a APIs externas:

```
Método: POST/GET
URL: [URL de tu API]
Autenticación: Según API
Headers:
  Content-Type: application/json
Body (JSON):
{
  "url": "{{ $json.url }}"
}
```

### Nodo 3: Function - Procesar Datos

Limpia y estructura los datos:

```javascript
const data = items[0].json;

// Limpiar precio
const cleanPrice = data.price.replace(/[^\d]/g, '');

// Extraer información adicional
const propertyId = data.url.match(/\/(\d+)\/?$/)?.[1];

return [{
  json: {
    property_id: propertyId,
    url: data.url,
    title: data.title,
    price: parseInt(cleanPrice),
    price_formatted: data.price,
    phone: data.phone,
    description: data.description,
    scraped_at: new Date().toISOString(),
    status: 'pending_review'
  }
}];
```

### Nodo 4: NocoDB - Guardar en Base de Datos

```
Operación: Create
Tabla: properties
Datos:
  - property_id: {{ $json.property_id }}
  - url: {{ $json.url }}
  - title: {{ $json.title }}
  - price: {{ $json.price }}
  - phone: {{ $json.phone }}
  - description: {{ $json.description }}
  - scraped_at: {{ $json.scraped_at }}
  - status: {{ $json.status }}
```

### Nodo 5: WhatsApp - Notificación

```
To: +34600000000 (número del equipo comercial)
Mensaje:
🏠 Nueva propiedad captada

📍 {{ $json.title }}
💰 {{ $json.price_formatted }}
📞 {{ $json.phone }}
🔗 {{ $json.url }}

Estado: Pendiente de revisión
```

## 🔄 Workflows Avanzados

### Workflow con Validación de Duplicados

```javascript
// Nodo: Check Duplicates (Function)
const url = items[0].json.url;
const existingProperties = $input.all();

// Buscar si ya existe
const isDuplicate = existingProperties.some(
  prop => prop.json.url === url
);

if (isDuplicate) {
  return {
    json: {
      ...items[0].json,
      is_duplicate: true,
      action: 'skip'
    }
  };
}

return {
  json: {
    ...items[0].json,
    is_duplicate: false,
    action: 'process'
  }
};
```

### Workflow con Enriquecimiento de Datos

```javascript
// Nodo: Enrich Data (Function)
const property = items[0].json;

// Calcular precio por m²
const surface = property.surface || 100; // valor por defecto
const pricePerSqm = Math.round(property.price / surface);

// Categorizar precio
let priceCategory;
if (property.price < 150000) {
  priceCategory = 'económico';
} else if (property.price < 300000) {
  priceCategory = 'medio';
} else if (property.price < 500000) {
  priceCategory = 'alto';
} else {
  priceCategory = 'premium';
}

// Extraer ubicación del título
const locationMatch = property.title.match(/en (.+?)(?:,|$)/);
const location = locationMatch ? locationMatch[1] : 'No especificado';

return [{
  json: {
    ...property,
    price_per_sqm: pricePerSqm,
    price_category: priceCategory,
    location: location,
    enriched_at: new Date().toISOString()
  }
}];
```

### Workflow con Scoring Automático

```javascript
// Nodo: Calculate Score (Function)
const property = items[0].json;
let score = 0;

// Precio (30 puntos)
if (property.price < 200000) score += 30;
else if (property.price < 300000) score += 20;
else if (property.price < 400000) score += 10;

// Ubicación (30 puntos) - personalizar según zonas de interés
const highValueAreas = ['centro', 'salamanca', 'retiro'];
if (highValueAreas.some(area => 
  property.location.toLowerCase().includes(area))) {
  score += 30;
}

// Descripción (20 puntos)
const descLength = property.description?.length || 0;
if (descLength > 500) score += 20;
else if (descLength > 200) score += 10;

// Teléfono disponible (20 puntos)
if (property.phone && property.phone !== 'No disponible') {
  score += 20;
}

// Categoría según score
let category;
if (score >= 80) category = 'hot';
else if (score >= 60) category = 'warm';
else if (score >= 40) category = 'cold';
else category = 'very_cold';

return [{
  json: {
    ...property,
    score: score,
    category: category,
    scored_at: new Date().toISOString()
  }
}];
```

## 📊 Workflow de Monitoreo de Cambios

### Detectar Cambios de Precio

```javascript
// Nodo: Compare Prices (Function)
const currentProperty = items[0].json;
const previousProperty = $('NocoDB').first().json;

if (!previousProperty) {
  return [{
    json: {
      ...currentProperty,
      is_new: true,
      price_change: 0,
      price_change_percent: 0
    }
  }];
}

const priceDiff = currentProperty.price - previousProperty.price;
const priceChangePercent = (priceDiff / previousProperty.price) * 100;

return [{
  json: {
    ...currentProperty,
    is_new: false,
    price_change: priceDiff,
    price_change_percent: priceChangePercent.toFixed(2),
    previous_price: previousProperty.price,
    changed_at: new Date().toISOString()
  }
}];
```

## 🔔 Notificaciones Inteligentes

### Notificación Solo para Propiedades "Hot"

```javascript
// Nodo: Filter Hot Properties (IF Node)
Condición:
  {{ $json.category }} equals "hot"
  AND
  {{ $json.score }} greater than 75

// Si TRUE → Enviar notificación prioritaria
// Si FALSE → Guardar sin notificar
```

### Template de Mensaje WhatsApp Avanzado

```
🔥 *PROPIEDAD PRIORITARIA* 🔥

📍 *Ubicación:* {{ $json.location }}
💰 *Precio:* {{ $json.price_formatted }}
📐 *€/m²:* {{ $json.price_per_sqm }}€

⭐ *Score:* {{ $json.score }}/100
🏷️ *Categoría:* {{ $json.category }}

📞 *Contacto:* {{ $json.phone }}

{{ $json.description.substring(0, 150) }}...

🔗 Ver más: {{ $json.url }}

---
Captada: {{ $json.scraped_at }}
```

## 🕐 Workflows Programados

### Scraping Masivo Nocturno

```
Schedule Trigger (Cron: 0 2 * * *)  # 2:00 AM diario
  → Google Sheets (Leer URLs)
  → Loop Over Items
    → HTTP Request (Scraper)
    → Delay (5 segundos)
    → Save to Database
  → Email Report (Resumen)
```

### Configuración del Schedule:

```
Modo: Cron
Expresión: 0 2 * * *
Zona horaria: Europe/Madrid
```

## 📈 Workflow de Reporting

### Resumen Diario

```javascript
// Nodo: Generate Daily Report (Function)
const properties = items;
const today = new Date().toISOString().split('T')[0];

const stats = {
  date: today,
  total_scraped: properties.length,
  hot_properties: properties.filter(p => p.json.category === 'hot').length,
  warm_properties: properties.filter(p => p.json.category === 'warm').length,
  average_price: Math.round(
    properties.reduce((sum, p) => sum + p.json.price, 0) / properties.length
  ),
  properties_with_phone: properties.filter(
    p => p.json.phone && p.json.phone !== 'No disponible'
  ).length
};

// Generar mensaje
const message = `
📊 *REPORTE DIARIO DE CAPTACIÓN*
📅 ${stats.date}

📈 *Estadísticas:*
• Total captadas: ${stats.total_scraped}
• 🔥 Prioritarias: ${stats.hot_properties}
• 🌡️ Interesantes: ${stats.warm_properties}
• 💰 Precio medio: ${stats.average_price.toLocaleString()}€
• 📞 Con teléfono: ${stats.properties_with_phone}

---
Sistema automático de captación
`;

return [{
  json: {
    ...stats,
    message: message
  }
}];
```

## 🔗 Integraciones con Otros Servicios

### Guardar en Google Sheets

```
Nodo: Google Sheets
Operación: Append
Spreadsheet: Propiedades Captadas
Hoja: 2026
Datos:
  - Fecha: {{ $json.scraped_at }}
  - URL: {{ $json.url }}
  - Título: {{ $json.title }}
  - Precio: {{ $json.price }}
  - Teléfono: {{ $json.phone }}
  - Score: {{ $json.score }}
  - Categoría: {{ $json.category }}
```

### Crear Tarea en Chatwoot

```
Nodo: HTTP Request
Método: POST
URL: http://propertyscraper_chatwoot_web:3000/api/v1/accounts/1/contacts
Headers:
  api_access_token: [tu_token_de_chatwoot]
Body:
{
  "name": "Lead - {{ $json.title }}",
  "phone_number": "{{ $json.phone }}",
  "custom_attributes": {
    "property_url": "{{ $json.url }}",
    "price": "{{ $json.price }}",
    "score": "{{ $json.score }}"
  }
}
```

### Enviar a Slack

```
Nodo: Slack
Canal: #propiedades-hot
Mensaje:
🏠 Nueva propiedad captada

*{{ $json.title }}*
Precio: {{ $json.price_formatted }}
Score: {{ $json.score }}/100

Ver: {{ $json.url }}
```

## 🐛 Manejo de Errores

### Nodo Error Trigger

```javascript
// Capturar errores del workflow
const error = $input.item.json.error;
const originalData = $input.item.json;

const errorMessage = `
⚠️ *ERROR EN SCRAPING*

URL: ${originalData.url || 'No disponible'}
Error: ${error.message}
Timestamp: ${new Date().toISOString()}

Se requiere revisión manual.
`;

return [{
  json: {
    error_type: error.name,
    error_message: error.message,
    original_data: originalData,
    notification_message: errorMessage,
    logged_at: new Date().toISOString()
  }
}];
```

### Reintentos Automáticos

```
HTTP Request Node:
  Retry On Fail: true
  Max Retries: 3
  Retry Interval: 5000 (ms)
  Wait Between Tries: 2000 (ms)
```

## 📝 Mejores Prácticas

1. **Usa Variables de Entorno**: Para URLs, tokens y configuraciones
2. **Implementa Rate Limiting**: No sobrecargues el scraper
3. **Registra Todo**: Usa nodos de log para debugging
4. **Divide Workflows Complejos**: Crea sub-workflows reutilizables
5. **Testea con Datos Reales**: Antes de automatizar
6. **Monitorea Errores**: Configura alertas para fallos
7. **Documenta Workflows**: Añade notas a los nodos
8. **Versionado**: Exporta y guarda versiones de workflows

## 🔧 Comandos Útiles de n8n

### Exportar Workflow

```bash
# Desde n8n UI: Settings → Export
# O usar CLI:
docker-compose exec n8n n8n export:workflow --id=1 --output=/tmp/workflow.json
```

### Importar Workflow

```bash
# Desde n8n UI: Settings → Import
# O arrastra el archivo JSON a la interfaz
```

## 📚 Recursos

- [Documentación de n8n](https://docs.n8n.io/)
- [Plantillas de Workflows](https://n8n.io/workflows)
- [Comunidad n8n](https://community.n8n.io/)

---

**Tip**: Comienza con workflows simples y ve añadiendo complejidad gradualmente. Prueba cada nodo individualmente antes de conectarlos todos.
