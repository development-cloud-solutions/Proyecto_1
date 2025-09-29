#!/bin/bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurar signal handlers para limpieza en caso de interrupción
cleanup() {
    echo -e "\n${YELLOW} Señal de interrupción recibida. Limpiando procesos...${NC}"

    # Matar procesos Artillery
    pkill -f "artillery" 2>/dev/null || true

    # Matar procesos Node.js relacionados
    pkill -f "node.*parse_results" 2>/dev/null || true
    pkill -f "node.*generate-report" 2>/dev/null || true

    # Limpiar archivos temporales
    if [ -n "$TEMP_PARSER" ] && [ -f "$TEMP_PARSER" ]; then
        rm -f "$TEMP_PARSER"
    fi

    echo -e "${GREEN} Limpieza completada${NC}"
    exit 130
}

# Verificar que estamos usando bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: Este script requiere bash, no sh"
    echo "Ejecutar con: bash load-test.sh"
    exit 1
fi

# Registrar signal handlers
trap cleanup SIGINT SIGTERM


# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detectar si estamos ejecutando desde la raíz del proyecto o desde back/scripts
if [ -f "collections/anb.json" ]; then
    # Estamos en la raíz del proyecto
    PROJECT_ROOT="$(pwd)"
    BACK_DIR="$PROJECT_ROOT/back"
else
    # Estamos en back/scripts, calcular la raíz
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    BACK_DIR="$PROJECT_ROOT/back"
fi

REPORTS_DIR="$PROJECT_ROOT/load-test-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo
echo -e "${BLUE}  ANB Rising Stars - Plan de Pruebas de Carga${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e " Directorio del proyecto: $PROJECT_ROOT"
echo -e " Directorio de backend: $BACK_DIR" 
echo -e " Directorio de reportes: $REPORTS_DIR"
echo ""

# Crear directorio de reportes
mkdir -p "$REPORTS_DIR"

# Verificar que Artillery está instalado
echo -e "${YELLOW}  Verificando dependencias...${NC}"
if ! command -v artillery &> /dev/null; then
    echo -e "${YELLOW} Instalando Artillery...${NC}"
    npm install artillery
fi

# Verificar form-data para el processor
if [ ! -d "node_modules/form-data" ]; then
    echo -e "${YELLOW} Instalando form-data...${NC}"
    npm install form-data
fi

# Verificar Node.js para parsing de JSON 
if ! command -v node &> /dev/null; then
    echo -e "${RED} Node.js no está disponible${NC}"
    echo -e "${RED} Node.js es requerido para el análisis de resultados${NC}"
    cleanup
    exit 1
else
    echo -e "${GREEN}  Node.js disponible para análisis$(node --version)${NC}"
fi

# Verificar que no haya procesos Artillery previos colgados
if pgrep -f "artillery" > /dev/null 2>&1; then
    echo -e "${YELLOW}   Detectados procesos Artillery previos. Limpiando...${NC}"
    pkill -f "artillery" 2>/dev/null || true
    sleep 2
fi

# Verificar que la API está disponible
echo -e "${YELLOW} Verificando que la API esté disponible...${NC}"
MAX_RETRIES=10
RETRY_COUNT=0
PORT=80

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:${PORT}/health > /dev/null 2>&1; then
        echo -e "${GREEN}  API está disponible${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}  API no está disponible después de $MAX_RETRIES intentos${NC}"
        echo -e "${RED}  Verifique que la aplicación esté ejecutándose en el puerto ${PORT} ${NC}"
        echo -e "${RED}  Puede iniciar la aplicación con: docker-compose up -d${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}  Intento $RETRY_COUNT/$MAX_RETRIES - Esperando 3 segundos...${NC}"
    sleep 3
done

# Cambiar al directorio de backend donde están los archivos de configuración
cd "$BACK_DIR"

# Verificar archivos necesarios
echo -e "${YELLOW} Verificando archivos de configuración...${NC}"

if [ ! -f "artillery-config.yml" ]; then
    echo -e "${RED}  Archivo artillery-config.yml no encontrado${NC}"
    exit 1
fi

if [ ! -f "scripts/load-test-data.csv" ]; then
    echo -e "${RED}  Archivo load-test-data.csv no encontrado${NC}"
    exit 1
fi

# Verificar archivo de video para las pruebas de upload
VIDEO_PATH="../docs/Video/Test_Video_Small.mp4"
if [ ! -f "$VIDEO_PATH" ]; then
    echo -e "${YELLOW}  Archivo de video no encontrado: $VIDEO_PATH${NC}"
    echo -e "${YELLOW}  Las pruebas de upload de video pueden fallar${NC}"
else
    VIDEO_SIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH" 2>/dev/null || echo "0")
    echo -e "${GREEN}  Video encontrado - Tamaño: $(($VIDEO_SIZE / 1024))KB${NC}"
fi


# Limpiar datos de pruebas anteriores 
echo -e "${YELLOW} Limpiando datos de pruebas anteriores...${NC}"
rm -rf "$REPORTS_DIR/load-test-results-*"
rm -rf "$REPORTS_DIR/load-test-report-*"
rm -rf "$REPORTS_DIR/docker-stats-start-*"
rm -rf "$REPORTS_DIR/docker-stats-end-*"
echo ""

# Configurar archivos de salida
RESULTS_JSON="$REPORTS_DIR/load-test-results-$TIMESTAMP.json"
RESULTS_HTML="$REPORTS_DIR/load-test-report-$TIMESTAMP.html"

echo -e "${BLUE} Plan de Pruebas de Carga - Fases:${NC}"
echo -e "    Fase 1: Warmup (2 minutos) - 5 usuarios/s"
echo -e "    Fase 2: Carga Normal (5 minutos) - 25 usuarios/s"
echo -e "    Fase 3: Carga Media (5 minutos) - 50 usuarios/s"
echo -e "    Fase 4: Carga Alta (3 minutos) - 100 usuarios/s"
echo -e "    Fase 5: Carga Pico (2 minutos) - 200 usuarios/s"
echo -e "    Fase 6: Recuperación (2 minutos) - 10 usuarios/s"
echo ""
echo -e "${BLUE} Escenarios de Prueba:${NC}"
echo -e "    Navegación Básica (60%): Health checks, videos públicos, rankings"
echo -e "    Autenticación (25%): Registro y login con emails únicos"
echo -e "    Interacción Avanzada (10%): Acciones autenticadas, votación"
echo -e "    Upload de Videos (5%): Registro, login y upload real de archivos"
echo ""
echo -e "${BLUE} Métricas Objetivo:${NC}"
echo -e "    Latencia P95: < 500ms"
echo -e "    Throughput: > 100 RPS"
echo -e "    Tasa de errores: < 1%"
echo ""

# Preguntar al usuario si desea continuar
read -p "¿Desea continuar con las pruebas de carga? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}  Pruebas canceladas por el usuario${NC}"
    exit 0
fi


# Iniciar monitoreo de recursos en background
echo -e "${YELLOW} Iniciando monitoreo de recursos...${NC}"
docker stats --no-stream > "$REPORTS_DIR/docker-stats-start-$TIMESTAMP.txt" 2>/dev/null || echo "Docker stats not available"

# Ejecutar pruebas de carga
echo -e "${GREEN} Iniciando pruebas de carga...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Ejecutar Artillery con configuración completa
artillery run artillery-config.yml \
    --output "$RESULTS_JSON" \
    --overrides '{
        "config": {
            "statsInterval": 10,
            "ensure": {
                "maxErrorRate": 5,
                "p99": 2000
            }
        }
    }'

ARTILLERY_EXIT_CODE=$?

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Obtener stats finales de Docker
docker stats --no-stream > "$REPORTS_DIR/docker-stats-end-$TIMESTAMP.txt" 2>/dev/null || echo "Docker stats not available"

# NOTA: artillery report fue descontinuado - los resultados están disponibles en JSON
echo -e "${YELLOW}- Resultados disponibles en formato JSON${NC}"
echo -e "${YELLOW}  Para análisis visual, considere Artillery Cloud: https://app.artillery.io${NC}"

# Análisis básico de resultados
echo -e "${BLUE} Análisis de Resultados:${NC}"
if [ -f "$RESULTS_JSON" ]; then
    # Crear script Node.js para parsear JSON (más confiable que jq en Windows)
    TEMP_PARSER="$REPORTS_DIR/parse_results.js"
    cat > "$TEMP_PARSER" << 'EOF'
const fs = require('fs');
const path = process.argv[2];

try {
    const data = JSON.parse(fs.readFileSync(path, 'utf8'));
    const aggregate = data.aggregate || {};
    const counters = aggregate.counters || {};
    const rates = aggregate.rates || {};
    const summaries = aggregate.summaries || {};

    // Artillery v2+ usa diferentes rutas para latencia
    const responseTime = summaries['http.response_time'] || aggregate.latency || {};

    console.log('TOTAL_REQUESTS=' + (counters['http.requests'] || counters['http.request_rate'] || 0));
    console.log('SUCCESS_REQUESTS=' + (counters['http.responses'] || counters['http.codes.200'] || 0));
    console.log('RPS=' + (rates['http.request_rate'] || 0));
    console.log('P50=' + (responseTime.p50 || responseTime.median || 0));
    console.log('P95=' + (responseTime.p95 || 0));
    console.log('P99=' + (responseTime.p99 || 0));
    console.log('MAX_LATENCY=' + (responseTime.max || 0));
    console.log('MIN_LATENCY=' + (responseTime.min || 0));
    console.log('ERRORS=' + (counters['errors.ECONNREFUSED'] || counters['errors.ETIMEDOUT'] || 0));
    console.log('STATUS_CODES_4XX=' + Object.keys(counters).filter(k => k.startsWith('http.codes.4')).reduce((sum, k) => sum + counters[k], 0));
    console.log('STATUS_CODES_5XX=' + Object.keys(counters).filter(k => k.startsWith('http.codes.5')).reduce((sum, k) => sum + counters[k], 0));
} catch (err) {
    console.error('Error parsing JSON:', err.message);
    process.exit(1);
}
EOF

    # Ejecutar el parser y capturar variables (con timeout para evitar colgado)
    if PARSE_OUTPUT=$(timeout 30s node "$TEMP_PARSER" "$RESULTS_JSON" 2>/dev/null); then
        # Extraer variables del output
        eval "$PARSE_OUTPUT"

        echo -e "${BLUE} Métricas Principales:${NC}"
        echo -e "    Total de requests: $TOTAL_REQUESTS"
        echo -e "    Requests exitosos: $SUCCESS_REQUESTS"
        echo -e "    RPS promedio: $RPS"
        echo -e "    Latencia P50: ${P50}ms"
        echo -e "    Latencia P95: ${P95}ms"
        echo -e "    Latencia P99: ${P99}ms"
        echo -e "    Errores de conexión: $ERRORS"
        echo -e "    Códigos 4xx: $STATUS_CODES_4XX"
        echo -e "    Códigos 5xx: $STATUS_CODES_5XX"

        # Evaluación de criterios de éxito usando comparación aritmética de bash
        echo -e "\n${BLUE} Evaluación de Criterios de Éxito:${NC}"

        # Convertir a números enteros para comparación
        P95_INT=${P95%.*}  # Remover decimales
        RPS_INT=${RPS%.*}  # Remover decimales

        if [ "$P95_INT" -lt 500 ] 2>/dev/null; then
            echo -e "    Latencia P95 < 500ms: ${GREEN}PASÓ${NC} (${P95}ms)"
        else
            echo -e "    Latencia P95 < 500ms: ${RED}FALLÓ${NC} (${P95}ms)"
        fi

        if [ "$RPS_INT" -gt 100 ] 2>/dev/null; then
            echo -e "    Throughput > 100 RPS: ${GREEN}PASÓ${NC} (${RPS} RPS)"
        else
            echo -e "    Throughput > 100 RPS: ${RED}FALLÓ${NC} (${RPS} RPS)"
        fi

        # Calcular tasa de éxito
        if [ "$TOTAL_REQUESTS" -gt 0 ] 2>/dev/null; then
            SUCCESS_RATE=$(node -e "console.log(Math.round($SUCCESS_REQUESTS * 100 / $TOTAL_REQUESTS))")
            echo -e "    Tasa de éxito: ${SUCCESS_RATE}%"

            if [ "$SUCCESS_RATE" -gt 99 ] 2>/dev/null; then
                echo -e "    Tasa de éxito > 99%: ${GREEN}PASÓ${NC} (${SUCCESS_RATE}%)"
            else
                echo -e "    Tasa de éxito > 99%: ${RED}FALLÓ${NC} (${SUCCESS_RATE}%)"
            fi
        fi

    else
        echo -e "${RED}   Error al parsear resultados de Artillery${NC}"
        echo -e "${YELLOW}   Resultado disponible en: $RESULTS_JSON${NC}"
    fi

    # Limpiar archivo temporal y forzar limpieza de procesos Node.js
    rm -f "$TEMP_PARSER"

    # Asegurar que no queden procesos Node.js colgados
    pkill -f "node.*parse_results.js" 2>/dev/null || true
else
    echo -e "${RED}   Archivo de resultados no encontrado: $RESULTS_JSON${NC}"
fi

# Verificar el resultado de Artillery
if [ $ARTILLERY_EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}  Pruebas de carga completadas exitosamente!${NC}"
else
    echo -e "\n${RED}  Las pruebas fallaron (código de salida: $ARTILLERY_EXIT_CODE)${NC}"
fi

echo -e "\n${BLUE} Archivos Generados:${NC}"
echo -e "    Resultados JSON: $RESULTS_JSON"
echo -e "    Docker stats (inicio): $REPORTS_DIR/docker-stats-start-$TIMESTAMP.txt"
echo -e "    Docker stats (final): $REPORTS_DIR/docker-stats-end-$TIMESTAMP.txt"
echo -e "    Resumen detallado: Ver análisis arriba o importar JSON a Artillery Cloud"
echo ""

# Generar resumen en Markdown
SUMMARY_FILE="$REPORTS_DIR/load-test-summary-$TIMESTAMP.md"
cat > "$SUMMARY_FILE" << EOF
# Resumen de Pruebas de Carga - ANB Rising Stars

**Fecha de ejecución**: $(date)  
**Duración total**: 19 minutos (6 fases)  

## Configuración de Prueba

- **Target**: http://localhost:8080
- **Fases**: 6 (Warmup → Normal → Media → Alta → Pico → Recuperación)
- **Usuarios máximos**: 200 usuarios/segundo
- **Escenarios**: Navegación básica (60%), Autenticación (25%), Interacción avanzada (10%), Upload videos (5%)

## Archivos Generados

- Resultados JSON: \`load-test-results-$TIMESTAMP.json\`
- Docker stats: \`docker-stats-*-$TIMESTAMP.txt\`
- Análisis en consola: Ver output detallado arriba
- Para reportes visuales: Importar JSON a [Artillery Cloud](https://app.artillery.io)

## Próximos Pasos

1. Revisar el reporte HTML detallado
2. Analizar métricas de latencia y throughput
3. Identificar cuellos de botella en la aplicación
4. Implementar optimizaciones recomendadas
5. Repetir pruebas después de optimizaciones

## Criterios de Evaluación

-   **Latencia P95 < 500ms**
-   **Throughput > 100 RPS**
-   **Tasa de errores < 1%**
-   **Tiempo de respuesta estable**

EOF

echo -e "    Resumen Markdown: $SUMMARY_FILE"
echo ""

echo -e "\n${GREEN} Plan de pruebas de carga completado!${NC}"
echo -e "${BLUE} Para más detalles, consulte el documento: capacity-planning/plan_de_pruebas.md${NC}"

echo -e "${BLUE} Consultar logs en: $REPORTS_DIR${NC}"

# Forzar limpieza final de procesos antes del exit
echo -e "${YELLOW} Limpiando procesos en segundo plano...${NC}"
pkill -f "artillery" 2>/dev/null || true
pkill -f "node.*generate-report" 2>/dev/null || true

# Pequeña pausa para permitir limpieza
sleep 2

echo -e "${GREEN} Script terminado limpiamente${NC}"
exit $ARTILLERY_EXIT_CODE