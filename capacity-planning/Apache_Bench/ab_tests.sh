#!/bin/bash

set -e

# Obtener el directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/load-test-results"
mkdir -p "$RESULTS_DIR"

echo "Ejecutando pruebas de carga con Apache Bench..."

# Verificar que Apache Bench está instalado
if ! command -v ab &> /dev/null; then
    echo "Apache Bench no está instalado"
    echo "Instalando Apache Bench..."
    # Para Ubuntu/Debian
    sudo apt-get update && sudo apt-get install -y apache2-utils
    # Para CentOS/RHEL
    # sudo yum install -y httpd-tools
fi

# Variables de configuración de pruebas
CONCURRENT_USERS=100
TOTAL_REQUESTS=1000
TEST_DURATION=30

# URLs basadas en la colección Postman
BASE_URL="http://localhost"
BASE_URL_HEALTH="http://localhost"

# Headers comunes
CONTENT_TYPE_HEADER="Content-Type: application/json"
AUTH_HEADER="Authorization: Bearer {{access_token}}"

# Función para ejecutar prueba y guardar resultados
run_bench_test() {
    local test_name=$1
    local url=$2
    local method=$3
    local body_file=$4
    local headers=$5
    
    echo ""
    echo "Ejecutando prueba: $test_name"
    echo "URL: $url"
    echo "Usuarios concurrentes: $CONCURRENT_USERS"
    echo "Total de requests: $TOTAL_REQUESTS"
    
    # Construir comando ab
    local ab_cmd="ab -n $TOTAL_REQUESTS -c $CONCURRENT_USERS"
    
    # Agregar headers si existen
    if [ ! -z "$headers" ]; then
        ab_cmd="$ab_cmd -H '$headers'"
    fi
    
    # Agregar método POST y body si es necesario
    if [ "$method" = "POST" ] && [ ! -z "$body_file" ]; then
        ab_cmd="$ab_cmd -p $body_file -T application/json"
    fi
    
    # Ejecutar prueba
    local result_file="$RESULTS_DIR/${test_name// /_}_results.txt"
    echo "Guardando resultados en: $result_file"
    
    eval "$ab_cmd $url" > "$result_file" 2>&1
    
    # Mostrar resumen
    echo "Prueba completada: $test_name"
    grep -E "(Time taken|Requests per second|Time per request|Transfer rate|Failed requests)" "$result_file"
    echo ""
}

# Esperar que la API esté disponible
echo "Esperando que la API esté disponible..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -f "$BASE_URL_HEALTH/health" > /dev/null 2>&1; then
        echo "API está disponible"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "API no está disponible después de $MAX_ATTEMPTS intentos"
        exit 1
    fi
    
    echo "Intento $ATTEMPT/$MAX_ATTEMPTS - Esperando API..."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

# Crear archivos de datos para pruebas POST
echo "Preparando datos de prueba..."

# Datos para registro de usuario
cat > "$RESULTS_DIR/register_data.json" << EOF
{
  "first_name": "Test",
  "last_name": "User",
  "email": "test.user.\$(date +%s)@example.com",
  "password1": "StrongPass123",
  "password2": "StrongPass123",
  "city": "Bogotá",
  "country": "TestCountry"
}
EOF

# Datos para login
cat > "$RESULTS_DIR/login_data.json" << EOF
{
  "email": "test.user@example.com",
  "password": "StrongPass123"
}
EOF

# Datos para upload (simplificado para pruebas de carga)
cat > "$RESULTS_DIR/upload_data.txt" << EOF
{
  "title": "Test Video Load"
}
EOF

echo "Iniciando pruebas de carga..."

# 1. Health Check (GET)
run_bench_test "Health Check" "$BASE_URL_HEALTH/health" "GET" "" ""

# 2. Register User (POST)
run_bench_test "User Registration" "$BASE_URL/api/auth/signup" "POST" "$RESULTS_DIR/register_data.json" "$CONTENT_TYPE_HEADER"

# 3. Login User (POST)
run_bench_test "User Login" "$BASE_URL/api/auth/login" "POST" "$RESULTS_DIR/login_data.json" "$CONTENT_TYPE_HEADER"

# 4. Get Profile (GET) - Nota: Requiere token, esta prueba será básica
run_bench_test "Get Profile" "$BASE_URL/api/auth/profile" "GET" "" "$CONTENT_TYPE_HEADER"

# 5. Get Videos (GET)
run_bench_test "Get Videos" "$BASE_URL/api/videos" "GET" "" "$CONTENT_TYPE_HEADER"

# 6. Pruebas con diferentes niveles de concurrencia
echo "Ejecutando pruebas con diferentes niveles de concurrencia..."

CONCURRENCY_LEVELS=(10 50 100 200)
for conc in "${CONCURRENCY_LEVELS[@]}"; do
    echo ""
    echo "Probando con $conc usuarios concurrentes en Health Check"
    ab -n 1000 -c $conc "$BASE_URL_HEALTH/health" > "$RESULTS_DIR/health_${conc}_users.txt" 2>&1
    
    echo "Health Check con $conc usuarios completado"
    grep "Requests per second" "$RESULTS_DIR/health_${conc}_users.txt"
done

# Generar reporte consolidado
echo "Generando reporte consolidado..."

cat > "$RESULTS_DIR/load_test_summary.md" << EOF
# Resumen de Pruebas de Carga
## Fecha: $(date)

### Configuración
- Total de requests por prueba: $TOTAL_REQUESTS
- Usuarios concurrentes: $CONCURRENT_USERS
- URL base: $BASE_URL

### Resultados por Endpoint

EOF

# Agregar resultados de cada prueba al reporte
for result_file in "$RESULTS_DIR"/*_results.txt; do
    if [ -f "$result_file" ]; then
        test_name=$(basename "$result_file" | sed 's/_results.txt//' | tr '_' ' ')
        echo "### $test_name" >> "$RESULTS_DIR/load_test_summary.md"
        echo '```' >> "$RESULTS_DIR/load_test_summary.md"
        grep -E "(Requests per second|Time per request|Transfer rate|Failed requests|Time taken)" "$result_file" >> "$RESULTS_DIR/load_test_summary.md"
        echo '```' >> "$RESULTS_DIR/load_test_summary.md"
        echo "" >> "$RESULTS_DIR/load_test_summary.md"
    fi
done

echo "¡Todas las pruebas de carga completadas!"
echo "Resultados guardados en: $RESULTS_DIR/"
echo " Resumen: $RESULTS_DIR/load_test_summary.md"

# Mostrar resumen final
echo ""
echo "RESUMEN FINAL:"
echo "=================="
for result_file in "$RESULTS_DIR"/*_results.txt; do
    if [ -f "$result_file" ]; then
        test_name=$(basename "$result_file" | sed 's/_results.txt//' | tr '_' ' ')
        rps=$(grep "Requests per second" "$result_file" | awk '{print $4}')
        echo "$test_name: $rps requests/segundo"
    fi
done