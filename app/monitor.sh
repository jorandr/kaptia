#!/bin/bash

# =============================================================================
# Script de Monitoreo - Property Scraper
# =============================================================================
# Este script verifica el estado de todos los servicios
# =============================================================================

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "==================================="
echo "   MONITOREO DEL SISTEMA"
echo "==================================="
echo -e "${NC}"

# Estado de contenedores
echo -e "${YELLOW}📦 Estado de Contenedores:${NC}"
echo ""
docker-compose ps
echo ""

# Uso de recursos
echo -e "${YELLOW}💻 Uso de Recursos:${NC}"
echo ""
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
echo ""

# Espacio en disco
echo -e "${YELLOW}💾 Espacio en Disco:${NC}"
echo ""
df -h | grep -E "Filesystem|/$"
echo ""
echo "Docker volumes:"
docker system df -v | grep -A 10 "Local Volumes"
echo ""

# Verificar conectividad de servicios
echo -e "${YELLOW}🔗 Verificando Conectividad:${NC}"
echo ""

# PostgreSQL
if docker-compose exec -T postgres pg_isready -U ${POSTGRES_USER} &>/dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL: OK"
else
    echo -e "${RED}✗${NC} PostgreSQL: ERROR"
fi

# Redis
if docker-compose exec -T redis redis-cli ping &>/dev/null; then
    echo -e "${GREEN}✓${NC} Redis: OK"
else
    echo -e "${RED}✗${NC} Redis: ERROR"
fi

# n8n
if curl -s http://localhost:${N8N_PORT:-5678} &>/dev/null; then
    echo -e "${GREEN}✓${NC} n8n: OK"
else
    echo -e "${RED}✗${NC} n8n: ERROR"
fi

echo ""

# Logs recientes de errores
echo -e "${YELLOW}⚠️  Errores Recientes (últimos 5 minutos):${NC}"
echo ""
docker-compose logs --since=5m 2>&1 | grep -i "error\|exception\|failed" | tail -10 || echo "No se encontraron errores recientes"

echo ""
echo -e "${BLUE}==================================="
echo "Monitoreo completado: $(date)"
echo "===================================${NC}"
echo ""
