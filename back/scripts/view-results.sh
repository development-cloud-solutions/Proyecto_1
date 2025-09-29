#!/bin/bash

# Script para visualizar resultados de Artillery

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/load-test-reports"

echo -e "${BLUE}📊 Visualizador de Resultados Artillery${NC}"
echo -e "${BLUE}=====================================${NC}"

# Si se proporciona un archivo específico
if [ "$1" ]; then
    JSON_FILE="$1"
    if [ ! -f "$JSON_FILE" ]; then
        echo -e "${RED}❌ Archivo no encontrado: $JSON_FILE${NC}"
        exit 1
    fi
else
    # Buscar el archivo más reciente
    if [ -d "$REPORTS_DIR" ]; then
        JSON_FILE=$(find "$REPORTS_DIR" -name "*.json" -type f | sort -r | head -1)
        if [ -z "$JSON_FILE" ]; then
            echo -e "${RED}❌ No se encontraron archivos JSON en $REPORTS_DIR${NC}"
            echo -e "${YELLOW}💡 Ejecute primero una prueba de carga${NC}"
            exit 1
        fi
        echo -e "${YELLOW}📁 Usando archivo más reciente: $(basename "$JSON_FILE")${NC}"
    else
        echo -e "${RED}❌ Directorio de reportes no encontrado: $REPORTS_DIR${NC}"
        exit 1
    fi
fi

echo ""

# Mostrar opciones
echo -e "${BLUE}Opciones disponibles:${NC}"
echo -e "  1) 📝 Ver resumen en consola"
echo -e "  2) 💾 Generar reporte Markdown"
echo -e "  3) 🌐 Información sobre Artillery Cloud"
echo -e "  4) 📋 Ver JSON completo (raw)"
echo -e "  5) 📂 Listar todos los resultados disponibles"
echo ""

read -p "Seleccione una opción (1-5): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo -e "${GREEN}📝 Generando resumen en consola...${NC}"
        echo ""
        node "$SCRIPT_DIR/generate-report.js" "$JSON_FILE"
        ;;
    2)
        REPORT_FILE="${JSON_FILE%.*}_report_$(date +%Y%m%d_%H%M%S).md"
        echo -e "${GREEN}💾 Generando reporte Markdown...${NC}"
        node "$SCRIPT_DIR/generate-report.js" "$JSON_FILE" "$REPORT_FILE"
        echo -e "${BLUE}📄 Reporte guardado en: $REPORT_FILE${NC}"

        # Intentar abrir en Windows
        if command -v cmd.exe > /dev/null 2>&1; then
            echo -e "${YELLOW}🔄 Intentando abrir reporte...${NC}"
            cmd.exe /c start "$REPORT_FILE" 2>/dev/null || true
        fi
        ;;
    3)
        echo -e "${BLUE}🌐 Artillery Cloud - Reportes Visuales${NC}"
        echo -e "${BLUE}====================================${NC}"
        echo ""
        echo -e "Artillery ha migrado a Artillery Cloud para reportes visuales:"
        echo -e ""
        echo -e "🔗 ${YELLOW}https://app.artillery.io${NC}"
        echo -e ""
        echo -e "Características:"
        echo -e "  ✅ Dashboards interactivos"
        echo -e "  ✅ Gráficos en tiempo real"
        echo -e "  ✅ Comparación de resultados"
        echo -e "  ✅ Compartir con el equipo"
        echo -e "  ✅ Análisis de tendencias"
        echo -e ""
        echo -e "Para usar:"
        echo -e "  1. Regístrese en Artillery Cloud"
        echo -e "  2. Importe su archivo JSON: $(basename "$JSON_FILE")"
        echo -e "  3. Explore los reportes visuales"
        echo ""
        ;;
    4)
        echo -e "${GREEN}📋 Mostrando JSON completo...${NC}"
        echo -e "${YELLOW}Archivo: $JSON_FILE${NC}"
        echo ""
        if command -v jq > /dev/null 2>&1; then
            jq '.' "$JSON_FILE"
        else
            cat "$JSON_FILE"
        fi
        ;;
    5)
        echo -e "${GREEN}📂 Resultados disponibles:${NC}"
        echo ""
        if [ -d "$REPORTS_DIR" ]; then
            find "$REPORTS_DIR" -name "*.json" -type f -exec basename {} \; | sort -r | nl -b a -s ') '
        else
            echo -e "${YELLOW}  No hay resultados disponibles${NC}"
        fi
        echo ""
        echo -e "📁 Directorio: $REPORTS_DIR"
        ;;
    *)
        echo -e "${RED}❌ Opción no válida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}✨ Operación completada${NC}"