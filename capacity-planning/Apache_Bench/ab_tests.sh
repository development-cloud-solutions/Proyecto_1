#!/bin/bash

set -e

# Obtener el directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COLLECTIONS_DIR="$PROJECT_ROOT/collections"

echo "🧪 Ejecutando tests de API con Newman..."

# Verificar que Newman está instalado
if ! command -v newman &> /dev/null; then
    echo "📦 Instalando Newman..."
    npm install -g newman
fi

# Verificar que los archivos de colección y entorno existen
if [ ! -f "$COLLECTIONS_DIR/anb.json" ]; then
    echo "❌ Archivo de colección no encontrado: $COLLECTIONS_DIR/anb.json"
    exit 1
fi

if [ ! -f "$COLLECTIONS_DIR/postman_environment.json" ]; then
    echo "❌ Archivo de entorno no encontrado: $COLLECTIONS_DIR/postman_environment.json"
    exit 1
fi

# Verificar que el archivo de video de prueba existe (necesario para la prueba de upload)
TEST_VIDEO="$COLLECTIONS_DIR/test-video.mp4"
if [ ! -f "$TEST_VIDEO" ]; then
    echo "⚠️  Advertencia: Archivo de video de prueba no encontrado: $TEST_VIDEO"
    echo "   La prueba de subida de video fallará sin este archivo."
    echo "   Creando un archivo de prueba pequeño..."
    # Crear un pequeño archivo de prueba (1MB)
    dd if=/dev/zero of="$TEST_VIDEO" bs=1024 count=1024 2>/dev/null
fi

# Esperar que la API esté disponible
echo "⏳ Esperando que la API esté disponible..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ API está disponible"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "❌ API no está disponible después de $MAX_ATTEMPTS intentos"
        echo "💡 Verifica que el servidor esté ejecutándose en localhost:8080"
        exit 1
    fi
    
    echo "⏳ Intento $ATTEMPT/$MAX_ATTEMPTS - Esperando API..."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

# Crear directorio para resultados de tests si no existe
RESULTS_DIR="$PROJECT_ROOT/test-results"
mkdir -p "$RESULTS_DIR"

# Ejecutar tests de Postman
echo "🚀 Ejecutando colección de Postman..."
newman run "$COLLECTIONS_DIR/anb.json" \
    -e "$COLLECTIONS_DIR/postman_environment.json" \
    --reporters cli,html,json \
    --reporter-html-export "$RESULTS_DIR/test-report.html" \
    --reporter-json-export "$RESULTS_DIR/test-results.json" \
    --delay-request 1000

# Verificar el resultado de los tests
if [ $? -eq 0 ]; then
    echo "✅ ¡Todos los tests pasaron exitosamente!"
    echo "📊 Reporte HTML: $RESULTS_DIR/test-report.html"
    echo "📊 Reporte JSON: $RESULTS_DIR/test-results.json"
else
    echo "❌ Algunos tests fallaron"
    echo "📊 Reporte HTML: $RESULTS_DIR/test-report.html"
    echo "📊 Reporte JSON: $RESULTS_DIR/test-results.json"
    exit 1
fi
