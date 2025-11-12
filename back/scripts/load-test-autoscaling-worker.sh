#!/bin/bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configurar signal handlers para limpieza en caso de interrupción
cleanup() {
    echo -e "\n${YELLOW} Señal de interrupción recibida. Limpiando procesos...${NC}"
    pkill -f "artillery" 2>/dev/null || true
    pkill -f "node.*parse_results" 2>/dev/null || true
    if [ -n "$TEMP_PARSER" ] && [ -f "$TEMP_PARSER" ]; then
        rm -f "$TEMP_PARSER"
    fi
    if [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ Limpieza completada${NC}"
    exit 130
}

trap cleanup SIGINT SIGTERM

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "collections/anb.json" ]; then
    PROJECT_ROOT="$(pwd)"
    BACK_DIR="$PROJECT_ROOT/back"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    BACK_DIR="$PROJECT_ROOT/back"
fi

REPORTS_DIR="$PROJECT_ROOT/load-test-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ANB Rising Stars - Prueba de Autoscaling del Worker          ║${NC}"
echo -e "${MAGENTA}║  Objetivo: SQS Queue > 10 mensajes para escalar 1 → 3 workers ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN} Directorio del proyecto:${NC} $PROJECT_ROOT"
echo -e "${CYAN} Directorio de backend:${NC} $BACK_DIR"
echo -e "${CYAN} Directorio de reportes:${NC} $REPORTS_DIR"
echo

# Crear directorio de reportes
mkdir -p "$REPORTS_DIR"

# Verificar dependencias
echo -e "${YELLOW} Verificando dependencias...${NC}"
if ! command -v artillery &> /dev/null; then
    echo -e "${YELLOW}⚙ Instalando Artillery...${NC}"
    npm install artillery
fi

if [ ! -d "node_modules/form-data" ]; then
    echo -e "${YELLOW}⚙ Instalando form-data...${NC}"
    npm install form-data
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js no está disponible${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Node.js disponible $(node --version)${NC}"

# Limpiar procesos Artillery previos
if pgrep -f "artillery" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Detectados procesos Artillery previos. Limpiando...${NC}"
    pkill -f "artillery" 2>/dev/null || true
    sleep 2
fi

# Configurar URL del target
if [ -z "$API_TARGET_URL" ]; then
    API_TARGET_URL="http://localhost"
    echo -e "${BLUE} Usando URL por defecto: ${API_TARGET_URL}${NC}"
else
    echo -e "${BLUE} Usando URL personalizada (AWS): ${API_TARGET_URL}${NC}"
fi

export API_TARGET_URL

# Verificar que la API está disponible
echo -e "${YELLOW} Verificando que la API esté disponible...${NC}"
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f ${API_TARGET_URL}/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API está disponible en ${API_TARGET_URL}${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}✗ API no está disponible después de $MAX_RETRIES intentos${NC}"
        echo -e "${RED} Para AWS: export API_TARGET_URL='http://your-elb.amazonaws.com'${NC}"
        exit 1
    fi
    echo -e "${YELLOW} Intento $RETRY_COUNT/$MAX_RETRIES - Esperando 3 segundos...${NC}"
    sleep 3
done

cd "$BACK_DIR"

# Verificar archivos necesarios
echo -e "${YELLOW} Verificando archivos de configuración...${NC}"
CONFIG_FILE="artillery-autoscaling-worker.yml"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo -e "${RED}✗ Archivo ${CONFIG_FILE} no encontrado${NC}"
    exit 1
fi

if [ ! -f "scripts/load-test-data.csv" ]; then
    echo -e "${RED}✗ Archivo load-test-data.csv no encontrado${NC}"
    exit 1
fi

# Verificar archivo de video
VIDEO_PATH="../docs/Video/Test_Video.mp4"
if [ ! -f "$VIDEO_PATH" ]; then
    echo -e "${RED}✗ Archivo de video no encontrado: $VIDEO_PATH${NC}"
    echo -e "${RED}Las pruebas de upload fallarán sin el video${NC}"
    exit 1
else
    VIDEO_SIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH" 2>/dev/null || echo "0")
    echo -e "${GREEN}✓ Video encontrado - Tamaño: $(($VIDEO_SIZE / 1024 / 1024))MB${NC}"
fi

# Configurar archivos de salida
RESULTS_JSON="$REPORTS_DIR/worker-autoscaling-results-$TIMESTAMP.json"
RESULTS_HTML="$REPORTS_DIR/worker-autoscaling-report-$TIMESTAMP.html"
MONITOR_LOG="$REPORTS_DIR/worker-autoscaling-monitor-$TIMESTAMP.log"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN} Plan de Pruebas de Autoscaling - Worker${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${CYAN}⏱  Duración total estimada: ~48 minutos${NC}"
echo
echo -e "${YELLOW}Fase 1 (3 min):${NC}  Warmup - 1 usuario/s (Preparar usuarios)"
echo -e "${YELLOW}Fase 2 (5 min):${NC}  Initial Load - 1→4 usuarios/s (Comenzar a llenar cola)"
echo -e "${YELLOW}Fase 3 (12 min):${NC}  Sustained Upload - 5 usuarios/s (TRIGGER WORKER AUTOSCALING)"
echo -e "${YELLOW}Fase 4 (8 min):${NC}  Peak Load - 8 usuarios/s (Probar múltiples workers)"
echo -e "${YELLOW}Fase 5 (5 min):${NC}  Ramp Down - 8→2 usuarios/s (Drenar cola)"
echo -e "${YELLOW}Fase 6 (15 min):${NC}  Recovery - 0 usuarios/s (VERIFICAR WORKER DOWNSCALING)"
echo
echo -e "${CYAN} Escenarios de Prueba:${NC}"
echo -e "  • Video Upload (35%): Llenar cola SQS con videos (balanceado)"
echo -e "  • Check Status (40%): Polling de estado mientras procesan"
echo -e "  • Browse Videos (25%): Baseline de navegación"
echo
echo -e "${CYAN} Métrica Objetivo:${NC}"
echo -e "  ${MAGENTA} ApproximateNumberOfMessagesVisible > 10 para activar autoscaling${NC}"
echo
echo -e "${CYAN} Estrategia:${NC}"
echo -e "  Worker capacity: ~4-8 videos/min por worker"
echo -e "  Upload rate objetivo: ~5-8 uploads/min (Fase 3), ~10-15 uploads/min (Fase 4)"
echo -e "  Cola esperada: 15-50 mensajes sostenidos para activar autoscaling"
echo -e "  ${YELLOW}⚠ Timeouts HTTP: 300s (5 min) - uploads de video ${NC}"
echo
echo -e "${CYAN} Monitoreo en tiempo real:${NC}"
if [ -n "$AWS_PROFILE" ] || aws sts get-caller-identity &> /dev/null; then
    echo -e "  ${GREEN}✓ AWS CLI configurado - Se monitoreará SQS y ASG${NC}"
    MONITOR_AWS=true
else
    echo -e "  ${YELLOW}⚠ AWS CLI no configurado - Monitoreo manual recomendado${NC}"
    MONITOR_AWS=false
fi
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Preguntar al usuario si desea continuar
read -p "$(echo -e ${CYAN}¿Desea continuar con la prueba de autoscaling del Worker? \(y/N\): ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠ Pruebas canceladas por el usuario${NC}"
    exit 0
fi

# Iniciar monitoreo de SQS y Worker ASG en background
if [ "$MONITOR_AWS" = true ]; then
    echo -e "${YELLOW} Iniciando monitoreo de SQS y Worker ASG...${NC}"
    (
        ASG_NAME="anb-production-worker-asg"
        SQS_QUEUE_NAME="anb-production-video-processing"

        # Intentar obtener la URL de la cola
        QUEUE_URL=$(aws sqs get-queue-url --queue-name "$SQS_QUEUE_NAME" --query 'QueueUrl' --output text 2>/dev/null || echo "")

        echo "=== Monitoreo de Worker Autoscaling ===" > "$MONITOR_LOG"
        echo "Inicio: $(date)" >> "$MONITOR_LOG"
        echo "ASG: $ASG_NAME" >> "$MONITOR_LOG"
        echo "SQS Queue: $SQS_QUEUE_NAME" >> "$MONITOR_LOG"
        echo "Queue URL: $QUEUE_URL" >> "$MONITOR_LOG"
        echo >> "$MONITOR_LOG"

        while true; do
            TIMESTAMP_LOG=$(date '+%Y-%m-%d %H:%M:%S')

            # Obtener info del ASG
            ASG_INFO=$(aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$ASG_NAME" \
                --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]' \
                --output text 2>/dev/null || echo "Error ASG")

            # Obtener mensajes en cola SQS
            if [ -n "$QUEUE_URL" ]; then
                QUEUE_DEPTH=$(aws sqs get-queue-attributes \
                    --queue-url "$QUEUE_URL" \
                    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
                    --query 'Attributes.{Visible:ApproximateNumberOfMessages,InFlight:ApproximateNumberOfMessagesNotVisible}' \
                    --output text 2>/dev/null || echo "Error SQS")
            else
                QUEUE_DEPTH="Queue URL not found"
            fi

            echo "[$TIMESTAMP_LOG] ASG: $ASG_INFO | SQS: $QUEUE_DEPTH" >> "$MONITOR_LOG"
            echo "[$TIMESTAMP_LOG] ASG (Desired/Min/Max): $ASG_INFO | SQS (Visible/InFlight): $QUEUE_DEPTH"

            sleep 30
        done
    ) &
    MONITOR_PID=$!
    echo -e "${GREEN}✓ Monitor iniciado (PID: $MONITOR_PID)${NC}"
    echo -e "${CYAN} Ver en tiempo real: tail -f $MONITOR_LOG${NC}"
    echo
fi

# Iniciar monitoreo de recursos
echo -e "${YELLOW} Capturando snapshot de Docker stats...${NC}"
docker stats --no-stream > "$REPORTS_DIR/docker-stats-start-$TIMESTAMP.txt" 2>/dev/null || echo "Docker stats not available"

# Ejecutar pruebas de carga
echo
echo -e "${GREEN} Iniciando prueba de autoscaling del Worker...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

artillery run "$CONFIG_FILE" \
    --output "$RESULTS_JSON" 2>&1 | tee "$REPORTS_DIR/worker-autoscaling-test-$TIMESTAMP.log"

ARTILLERY_EXIT_CODE=$?

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Detener monitoreo
if [ -n "$MONITOR_PID" ]; then
    kill $MONITOR_PID 2>/dev/null || true
    echo -e "${GREEN}✓ Monitor detenido${NC}"
fi

# Obtener stats finales de Docker
docker stats --no-stream > "$REPORTS_DIR/docker-stats-end-$TIMESTAMP.txt" 2>/dev/null || echo "Docker stats not available"

# Análisis de resultados
echo
echo -e "${CYAN} Análisis de Resultados:${NC}"
if [ -f "$RESULTS_JSON" ]; then
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
    const responseTime = summaries['http.response_time'] || aggregate.latency || {};

    console.log('TOTAL_REQUESTS=' + (counters['http.requests'] || 0));
    console.log('SUCCESS_REQUESTS=' + (counters['http.responses'] || 0));
    console.log('UPLOAD_SUCCESS=' + (counters['http.codes.201'] || 0));
    console.log('UPLOAD_ERRORS=' + (counters['http.codes.400'] || 0));
    console.log('TIMEOUTS=' + (counters['errors.ETIMEDOUT'] || 0));
    console.log('RPS=' + (rates['http.request_rate'] || 0));
    console.log('P50=' + (responseTime.p50 || 0));
    console.log('P95=' + (responseTime.p95 || 0));
    console.log('P99=' + (responseTime.p99 || 0));
    console.log('STATUS_5XX=' + Object.keys(counters).filter(k => k.startsWith('http.codes.5')).reduce((sum, k) => sum + counters[k], 0));
    console.log('COMPLETED=' + (counters['vusers.completed'] || 0));
    console.log('FAILED=' + (counters['vusers.failed'] || 0));
} catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
}
EOF

    if PARSE_OUTPUT=$(timeout 30s node "$TEMP_PARSER" "$RESULTS_JSON" 2>/dev/null); then
        eval "$PARSE_OUTPUT"

        echo -e "${BLUE}▶ Métricas Principales:${NC}"
        echo -e "  Total de requests: ${GREEN}$TOTAL_REQUESTS${NC}"
        echo -e "  Requests exitosos: ${GREEN}$SUCCESS_REQUESTS${NC}"
        echo -e "  Uploads exitosos (201): ${GREEN}$UPLOAD_SUCCESS${NC}"
        echo -e "  Errores de upload (400): ${YELLOW}$UPLOAD_ERRORS${NC}"
        echo -e "  Errores de servidor (5xx): ${RED}$STATUS_5XX${NC}"
        echo -e "  Timeouts: ${YELLOW}$TIMEOUTS${NC}"
        echo -e "  RPS promedio: ${GREEN}$RPS${NC}"
        echo -e "  Latencia P50: ${GREEN}${P50}ms${NC}"
        echo -e "  Latencia P95: ${GREEN}${P95}ms${NC}"
        echo -e "  Latencia P99: ${GREEN}${P99}ms${NC}"
        echo -e "  Usuarios completados: ${GREEN}$COMPLETED${NC}"
        echo -e "  Usuarios fallidos: ${RED}$FAILED${NC}"

        echo
        echo -e "${BLUE}▶ Evaluación de Video Upload:${NC}"
        if [ "$UPLOAD_SUCCESS" -gt 0 ] 2>/dev/null; then
            echo -e "  Uploads exitosos: ${GREEN}✓ PASÓ${NC} ($UPLOAD_SUCCESS videos)"
        else
            echo -e "  Uploads exitosos: ${RED}✗ FALLÓ${NC} (0 videos)"
        fi

        if [ "$TIMEOUTS" -lt 50 ] 2>/dev/null; then
            echo -e "  Timeouts < 50: ${GREEN}✓ PASÓ${NC} ($TIMEOUTS)"
        else
            echo -e "  Timeouts < 50: ${YELLOW}⚠ ADVERTENCIA${NC} ($TIMEOUTS)"
        fi
    fi

    rm -f "$TEMP_PARSER"
    pkill -f "node.*parse_results.js" 2>/dev/null || true
fi

echo
echo -e "${CYAN} Archivos Generados:${NC}"
echo -e "   Resultados JSON: $RESULTS_JSON"
echo -e "   Monitor SQS/ASG: $MONITOR_LOG"
echo -e "   Docker stats: $REPORTS_DIR/docker-stats-*-$TIMESTAMP.txt"
echo

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║     Prueba de Autoscaling del Worker completada                ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN} Verificar Autoscaling:${NC}"
echo -e "  1. Revisar monitor: ${YELLOW}cat $MONITOR_LOG${NC}"
echo -e "  2. AWS Console SQS: https://console.aws.amazon.com/sqs/"
echo -e "  3. AWS Console ASG: EC2 → Auto Scaling Groups → anb-production-worker-asg"
echo -e "  4. CloudWatch: Métricas de ApproximateNumberOfMessagesVisible"
echo

exit $ARTILLERY_EXIT_CODE
