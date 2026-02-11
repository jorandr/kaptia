#!/bin/bash

# Script para generar secrets de GitHub Actions
# Uso: ./generate-secrets.sh CLIENTE2

set -e

CLIENTE=${1:-CLIENTE2}
PROJECT_NAME=$(echo "$CLIENTE" | tr '[:upper:]' '[:lower:]')

echo "═══════════════════════════════════════════════════════"
echo "  🔐 Generador de Secrets para GitHub Actions"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Cliente: $CLIENTE"
echo "Project Name: $PROJECT_NAME"
echo ""

echo "📋 COPIA ESTOS VALORES A GITHUB SECRETS"
echo "═══════════════════════════════════════════════════════"
echo ""

echo "## 1. PostgreSQL Password"
POSTGRES_PASSWORD=$(openssl rand -base64 32)
echo "${CLIENTE}_POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
echo ""

echo "## 2. Chatwoot Secret Key"
CHATWOOT_SECRET=$(openssl rand -hex 64)
echo "${CLIENTE}_CHATWOOT_SECRET_KEY_BASE=${CHATWOOT_SECRET}"
echo ""

echo "═══════════════════════════════════════════════════════"
echo ""
echo "✅ Secrets generados correctamente"
echo ""
echo "📝 PRÓXIMOS PASOS:"
echo ""
echo "1. Crea estos 4 secrets en GitHub:"
echo "   ${CLIENTE}_PROJECT_NAME → ${PROJECT_NAME}"
echo "   ${CLIENTE}_DOMAIN → tudominio.com (ej: cliente2.com)"
echo "   ${CLIENTE}_POSTGRES_PASSWORD → (valor generado arriba)"
echo "   ${CLIENTE}_CHATWOOT_SECRET_KEY_BASE → (valor generado arriba)"
echo ""
echo "2. Los valores de WAHA se generarán automáticamente en el deployment"
echo ""
echo "═══════════════════════════════════════════════════════"
