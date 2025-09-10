#!/bin/bash

set -e

# Obtener el directorio raíz del proyecto (2 niveles arriba de /back/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Ejecutando tests de API con Newman..."

# Verificar que Newman está instalado
if ! command -v newman &> /dev/null; then
    echo "📦 Instalando Newman..."
    sudo npm install -g newman
fi

# Esperar que la API esté disponible
echo "⏳ Esperando que la API esté disponible..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ API está disponible"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ API no está disponible después de 30 intentos"
        exit 1
    fi
    sleep 2
done

# Ejecutar tests de Postman
COLLECTION="$PROJECT_ROOT/collections/anb.json"
ENVIRONMENT="$PROJECT_ROOT/collections/postman_environment.json"
REPORT="$PROJECT_ROOT/test-results.html"

echo "🚀 Ejecutando colección de Postman..."
newman run "$COLLECTION" \
    -e "$ENVIRONMENT" \
    --reporters cli,html \
    --reporter-html-export "$REPORT"

echo "✅ Tests de API completados!"
echo "📊 Reporte de tests: $REPORT"