#!/bin/bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Obtener el directorio raíz del proyecto
# Si se ejecuta desde la raíz del proyecto, usar el directorio actual
# Si se ejecuta desde otro lugar, calcular la ruta relativa
if [ -f "collections/anb.json" ]; then
    # Estamos en la raíz del proyecto
    PROJECT_ROOT="$(pwd)"
else
    # Intentar encontrar la raíz del proyecto (2 niveles arriba desde /back/scripts)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

echo "- Directorio del proyecto: $PROJECT_ROOT"
echo "- Ejecutando tests de API con Newman..."

# Verificar que Newman está instalado
if ! command -v newman &> /dev/null; then
    echo -e "${YELLOW}- Instalando Newman...${NC}"
    npm install newman newman-reporter-html
fi

# Verificar que los archivos existen
COLLECTION="$PROJECT_ROOT/collections/anb.json"
ENVIRONMENT="$PROJECT_ROOT/collections/postman_environment.json"
TEST_VIDEO="$PROJECT_ROOT/docs/Video/Test_Video.mp4"

echo "- Colección: $COLLECTION"
echo "- Entorno: $ENVIRONMENT"
echo "- Video de prueba: $TEST_VIDEO"

if [ ! -f "$COLLECTION" ]; then
    echo -e "${RED} ERROR: No se encontró la colección de Postman en $COLLECTION ${NC}"
    exit 1
fi

if [ ! -f "$ENVIRONMENT" ]; then
    echo -e "${RED} ERROR: No se encontró el archivo de entorno en $ENVIRONMENT ${NC}"
    exit 1
fi

if [ ! -f "$TEST_VIDEO" ]; then
    echo -e "${RED} ERROR: No se encontró el video de prueba en $TEST_VIDEO ${NC}"
    echo " Asegúrese de que el archivo Test_Video.mp4 esté en la carpeta docs/Video/"
    exit 1
fi

# Esperar que la API esté disponible (health check)
echo "- Esperando que la API esté disponible..."
echo ""

MAX_RETRIES=30
RETRY_COUNT=0
PORT=80

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:${PORT}/health > /dev/null 2>&1; then
        echo -e "${GREEN} API está disponible ${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo " API no está disponible después de $MAX_RETRIES intentos"
        echo " Verifique que la aplicación esté ejecutándose en el puerto ${PORT}"
        echo " Puede iniciar la aplicación con: docker-compose up -d"
        exit 1
    fi
    
    echo " Intento $RETRY_COUNT/$MAX_RETRIES - Esperando 2 segundos..."
    sleep 2
done

# Crear directorio para reportes si no existe
REPORTS_DIR="$PROJECT_ROOT/test-reports"
mkdir -p "$REPORTS_DIR"

# Ejecutar tests de Postman
REPORT_HTML="$REPORTS_DIR/newman-report-$(date +%Y%m%d-%H%M%S).html"
REPORT_JSON="$REPORTS_DIR/newman-report-$(date +%Y%m%d-%H%M%S).json"

echo ""
echo -e "${BLUE} Ejecutando colección de Postman...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Cambiar al directorio del proyecto para que Newman pueda acceder a los archivos relativos
cd "$PROJECT_ROOT"

# Ejecutar Newman con reportes múltiples
newman run "$COLLECTION" \
    --environment "$ENVIRONMENT" \
    --reporters cli,html,json \
    --reporter-html-export "$REPORT_HTML" \
    --reporter-json-export "$REPORT_JSON" \
    --working-dir "$PROJECT_ROOT" \
    --insecure \
    --timeout-request 15000 \
    --timeout-script 5000 \
    --delay-request 1000

# Verificar el resultado
NEWMAN_EXIT_CODE=$?

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $NEWMAN_EXIT_CODE -eq 0 ]; then
    echo " Tests de API completados exitosamente!"
else
    echo " Algunos tests fallaron (código de salida: $NEWMAN_EXIT_CODE)"
fi

echo ""
echo "- Reportes generados:"
echo "  - HTML: $REPORT_HTML"
echo "  - JSON: $REPORT_JSON"
echo ""

exit $NEWMAN_EXIT_CODE