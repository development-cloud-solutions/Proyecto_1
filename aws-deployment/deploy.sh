#!/bin/bash
# Script de despliegue automatizado para ANB Rising Stars en AWS usando CloudFormation
# Este script despliega toda la infraestructura necesaria

set -e

# ==========================================
# CONFIGURACIÓN
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# FUNCIONES AUXILIARES
# ==========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para arreglar deployment fallido
fix_failed_deployment() {
    local STACK_NAME="$1"

    log_info "Modo Quick Fix: Reparando deployment fallido"
    echo ""

    # Obtener información del stack
    S3_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$S3_BUCKET" ]; then
        log_error "No se encontró el stack ${STACK_NAME}"
        exit 1
    fi

    log_success "Stack encontrado: ${STACK_NAME}"
    log_info "S3 Bucket: ${S3_BUCKET}"
    echo ""

    # Preparar package
    log_info "Preparando deployment package..."
    DEPLOYMENT_DIR="${PROJECT_ROOT}/deployment-package"
    rm -rf "${DEPLOYMENT_DIR}"
    mkdir -p "${DEPLOYMENT_DIR}"

    cp -r "${PROJECT_ROOT}/back" "${DEPLOYMENT_DIR}/"
    cp -r "${PROJECT_ROOT}/front" "${DEPLOYMENT_DIR}/"
    cp -r "${PROJECT_ROOT}/db" "${DEPLOYMENT_DIR}/"
    cp "${PROJECT_ROOT}/docker-compose.api.yml" "${DEPLOYMENT_DIR}/"
    cp "${PROJECT_ROOT}/docker-compose.worker.yml" "${DEPLOYMENT_DIR}/"

    PACKAGE_FILE="${DEPLOYMENT_DIR}/app.tar.gz"
    cd "${DEPLOYMENT_DIR}"
    tar -czf app.tar.gz back/ front/ docker-compose.api.yml docker-compose.worker.yml
    cd "${PROJECT_ROOT}"

    log_success "Package creado: $(du -h ${PACKAGE_FILE} | cut -f1)"
    echo ""

    # Subir a S3
    log_info "Subiendo a S3..."
    aws s3 cp "${PACKAGE_FILE}" "s3://${S3_BUCKET}/deployments/latest/app.tar.gz"

    if aws s3 ls "s3://${S3_BUCKET}/deployments/latest/app.tar.gz" &> /dev/null; then
        log_success "Deployment package subido exitosamente"
    else
        log_error "Error al subir el package"
        exit 1
    fi
    echo ""

    # Obtener ASG name
    ENVIRONMENT_NAME=$(echo "$STACK_NAME" | sed 's/-master$//')
    ASG_NAME="${ENVIRONMENT_NAME}-api-asg"

    log_info "Reiniciando instancias del Auto Scaling Group..."
    echo ""
    log_warning "Ejecuta este comando para reiniciar las instancias:"
    echo "  aws autoscaling start-instance-refresh \\"
    echo "    --auto-scaling-group-name \"${ASG_NAME}\" \\"
    echo "    --preferences '{\"MinHealthyPercentage\": 0}'"
    echo ""

    log_success "Quick Fix completado. Ahora reinicia las instancias con el comando de arriba"
    exit 0
}

check_prerequisites() {
    log_info "Verificando prerequisitos..."

    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no está instalado. Instalalo desde: https://aws.amazon.com/cli/"
        exit 1
    fi

    # Verificar credenciales AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "No hay credenciales AWS configuradas. Ejecuta: aws configure"
        exit 1
    fi

    # Verificar región
    AWS_REGION=$(aws configure get region)
    if [ -z "$AWS_REGION" ]; then
        log_error "No hay región AWS configurada. Ejecuta: aws configure"
        exit 1
    fi

    log_success "Prerequisitos verificados"
    log_info "Región AWS: ${AWS_REGION}"
    log_info "Cuenta AWS: $(aws sts get-caller-identity --query Account --output text)"
}

# ==========================================
# PARÁMETROS DE LÍNEA DE COMANDOS
# ==========================================

# Modo especial: Quick Fix para deployment fallido
if [ "$1" = "--fix" ] || [ "$1" = "fix" ]; then
    STACK_NAME="${2:-anb-production-master}"
    check_prerequisites
    fix_failed_deployment "$STACK_NAME"
fi

ENVIRONMENT_NAME="${1:-anb-production}"
KEY_PAIR_NAME="${2}"
DB_PASSWORD="${3}"
JWT_SECRET="${4}"

if [ -z "$KEY_PAIR_NAME" ]; then
    log_error "Uso normal: $0 <environment-name> <key-pair-name> <db-password> <jwt-secret>"
    log_error "Ejemplo: $0 anb-production my-keypair MySecurePass123! \$(openssl rand -hex 32)"
    echo ""
    log_error "Modo Quick Fix: $0 --fix <stack-name>"
    log_error "Ejemplo: $0 --fix anb-production-master"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    log_error "DB_PASSWORD es requerido"
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    log_warning "JWT_SECRET no proporcionado, generando uno automáticamente..."
    JWT_SECRET=$(openssl rand -hex 32)
    log_info "JWT_SECRET generado: ${JWT_SECRET}"
fi

# ==========================================
# VALIDACIONES
# ==========================================
log_info "Validando configuración..."
log_info "ENVIRONMENT_NAME: ${ENVIRONMENT_NAME}"
log_info "KEY_PAIR_NAME: ${KEY_PAIR_NAME}"

# Validar que ENVIRONMENT_NAME no esté vacío
if [ -z "$ENVIRONMENT_NAME" ]; then
    log_error "ENVIRONMENT_NAME no puede estar vacío"
    exit 1
fi

# Verificar que el KeyPair existe
if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" &> /dev/null; then
    log_error "El Key Pair '${KEY_PAIR_NAME}' no existe en tu cuenta AWS"
    log_info "Crea uno con: aws ec2 create-key-pair --key-name ${KEY_PAIR_NAME} --query 'KeyMaterial' --output text > ${KEY_PAIR_NAME}.pem"
    exit 1
fi
echo ""

# ==========================================
# PREPARAR DEPLOYMENT PACKAGE
# ==========================================
log_info "Preparando deployment package..."

DEPLOYMENT_DIR="${PROJECT_ROOT}/deployment-package"
rm -rf "${DEPLOYMENT_DIR}"
mkdir -p "${DEPLOYMENT_DIR}"

# Copiar archivos necesarios
log_info "Copiando archivos del proyecto..."
cp -r "${PROJECT_ROOT}/back" "${DEPLOYMENT_DIR}/"
cp -r "${PROJECT_ROOT}/front" "${DEPLOYMENT_DIR}/"
cp -r "${PROJECT_ROOT}/db" "${DEPLOYMENT_DIR}/"
cp "${PROJECT_ROOT}/docker-compose.api.yml" "${DEPLOYMENT_DIR}/"
cp "${PROJECT_ROOT}/docker-compose.worker.yml" "${DEPLOYMENT_DIR}/"
echo ""

# Crear tarball
PACKAGE_FILE="${DEPLOYMENT_DIR}/app.tar.gz"
log_info "Creando tarball: ${PACKAGE_FILE}"
cd "${DEPLOYMENT_DIR}"
tar -czf app.tar.gz back/ front/ db/ docker-compose.api.yml docker-compose.worker.yml
cd "${PROJECT_ROOT}"

log_success "Deployment package creado: $(du -h ${PACKAGE_FILE} | cut -f1)"
echo ""

# ==========================================
# CREAR BUCKETS S3
# ==========================================
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
TEMPLATES_BUCKET="anb-cf-templates-${AWS_ACCOUNT_ID}-${AWS_REGION}"
VIDEOS_BUCKET="anb-videos-${AWS_ACCOUNT_ID}-${AWS_REGION}"

log_info "Creando bucket S3 para templates de CloudFormation: ${TEMPLATES_BUCKET}"

if ! aws s3 ls "s3://${TEMPLATES_BUCKET}" 2>/dev/null; then
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3 mb "s3://${TEMPLATES_BUCKET}"
    else
        aws s3 mb "s3://${TEMPLATES_BUCKET}" --region "${AWS_REGION}"
    fi
    log_success "Bucket creado: ${TEMPLATES_BUCKET}"
else
    log_info "Bucket ya existe: ${TEMPLATES_BUCKET}"
fi
echo ""

# Subir templates a S3
log_info "Subiendo templates de CloudFormation a S3..."
aws s3 sync "${SCRIPT_DIR}/" "s3://${TEMPLATES_BUCKET}/" \
    --exclude "*" \
    --include "*.yaml" \
    --include "*.yml"

log_success "Templates subidos a S3"
echo ""

# ==========================================
# CREAR Y CONFIGURAR BUCKET S3 DE VIDEOS
# ==========================================
log_info "Preparando bucket S3 para videos: ${VIDEOS_BUCKET}"

BUCKET_EXISTS=false
if aws s3 ls "s3://${VIDEOS_BUCKET}" 2>/dev/null; then
    BUCKET_EXISTS=true
    log_info "Bucket ya existe: ${VIDEOS_BUCKET}"
else
    log_info "Creando bucket S3 de videos: ${VIDEOS_BUCKET}"

    # Crear bucket
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3 mb "s3://${VIDEOS_BUCKET}"
    else
        aws s3 mb "s3://${VIDEOS_BUCKET}" --region "${AWS_REGION}"
    fi

    # Habilitar versionado
    aws s3api put-bucket-versioning \
        --bucket "${VIDEOS_BUCKET}" \
        --versioning-configuration Status=Enabled

    # Bloquear acceso público
    aws s3api put-public-access-block \
        --bucket "${VIDEOS_BUCKET}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Habilitar encriptación
    aws s3api put-bucket-encryption \
        --bucket "${VIDEOS_BUCKET}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    # Configurar CORS
    cat > /tmp/cors.json << 'EOF'
{
  "CORSRules": [{
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag", "x-amz-request-id"],
    "MaxAgeSeconds": 3000
  }]
}
EOF
    aws s3api put-bucket-cors \
        --bucket "${VIDEOS_BUCKET}" \
        --cors-configuration file:///tmp/cors.json
    rm /tmp/cors.json

    log_success "Bucket creado y configurado: ${VIDEOS_BUCKET}"
fi
echo ""

# ==========================================
# SUBIR DEPLOYMENT PACKAGE A S3 (SIEMPRE)
# ==========================================
log_info "Subiendo deployment package a S3..."
log_info "Destino: s3://${VIDEOS_BUCKET}/deployments/latest/app.tar.gz"

aws s3 cp "${PACKAGE_FILE}" "s3://${VIDEOS_BUCKET}/deployments/latest/app.tar.gz" --region "${AWS_REGION}"

# Verificar que el archivo se subió correctamente
if aws s3 ls "s3://${VIDEOS_BUCKET}/deployments/latest/app.tar.gz" &> /dev/null; then
    log_success "Deployment package subido exitosamente ($(du -h ${PACKAGE_FILE} | cut -f1))"
else
    log_error "Error: No se pudo verificar que app.tar.gz se subió correctamente"
    exit 1
fi
echo ""

# ==========================================
# DESPLEGAR CLOUDFORMATION STACK
# ==========================================
STACK_NAME="${ENVIRONMENT_NAME}-master"

log_info "Desplegando CloudFormation stack: ${STACK_NAME}"

# Validar que STACK_NAME no esté vacío
if [ -z "$STACK_NAME" ]; then
    log_error "STACK_NAME está vacío. ENVIRONMENT_NAME=${ENVIRONMENT_NAME}"
    exit 1
fi

log_info "Stack Name: ${STACK_NAME}"
log_info "Templates Bucket: ${TEMPLATES_BUCKET}"
log_info "Region: ${AWS_REGION}"
#log_info "DB_PASSWORD: ${DB_PASSWORD}"
#log_info "JWT_SECRET: ${JWT_SECRET}"

# Verificar si el stack ya existe
if aws cloudformation describe-stacks --stack-name "${STACK_NAME}" &> /dev/null; then
    log_warning "Stack ${STACK_NAME} ya existe. ¿Deseas actualizarlo? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Actualizando stack..."
        aws cloudformation update-stack \
            --stack-name "${STACK_NAME}" \
            --template-url "https://${TEMPLATES_BUCKET}.s3.amazonaws.com/00-master-stack.yaml" \
            --parameters \
                ParameterKey=EnvironmentName,ParameterValue="${ENVIRONMENT_NAME}" \
                ParameterKey=KeyPairName,ParameterValue="${KEY_PAIR_NAME}" \
                ParameterKey=DBPassword,ParameterValue="${DB_PASSWORD}" \
                ParameterKey=JWTSecret,ParameterValue="${JWT_SECRET}" \
                ParameterKey=TemplateS3BucketName,ParameterValue="${TEMPLATES_BUCKET}" \
                ParameterKey=VideoStorageBucketName,ParameterValue="${VIDEOS_BUCKET}" \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

        log_info "Esperando a que el stack se actualice..."
        aws cloudformation wait stack-update-complete --stack-name "${STACK_NAME}"
    else
        log_info "Actualización cancelada"
        exit 0
    fi
else
    log_info "Creando nuevo stack..."
    aws cloudformation create-stack \
        --stack-name "${STACK_NAME}" \
        --template-url "https://${TEMPLATES_BUCKET}.s3.amazonaws.com/00-master-stack.yaml" \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue="${ENVIRONMENT_NAME}" \
            ParameterKey=KeyPairName,ParameterValue="${KEY_PAIR_NAME}" \
            ParameterKey=DBPassword,ParameterValue="${DB_PASSWORD}" \
            ParameterKey=JWTSecret,ParameterValue="${JWT_SECRET}" \
            ParameterKey=TemplateS3BucketName,ParameterValue="${TEMPLATES_BUCKET}" \
            ParameterKey=VideoStorageBucketName,ParameterValue="${VIDEOS_BUCKET}" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --on-failure DELETE

    log_info "Esperando a que el stack se cree (esto puede tomar 10-15 minutos)..."
    aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"
fi

log_success "Stack desplegado exitosamente!"
echo ""

# ==========================================
# OBTENER OUTPUTS DEL STACK
# ==========================================
log_info "Obteniendo información del stack..."

S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)

DB_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
    --output text)

# ==========================================
# VERIFICAR QUE EL BUCKET ES EL ESPERADO
# ==========================================
if [ "${S3_BUCKET}" != "${VIDEOS_BUCKET}" ]; then
    log_warning "El bucket S3 del stack (${S3_BUCKET}) no coincide con el bucket esperado (${VIDEOS_BUCKET})"
    log_warning "Esto puede indicar un problema en la configuración del template 03-s3-iam.yaml"
fi

# ==========================================
# VERIFICAR ESTADO DE INSTANCIAS
# ==========================================
log_info "Verificando estado del Auto Scaling Group..."

ASG_NAME="${ENVIRONMENT_NAME}-api-asg"

# Obtener número de instancias healthy
HEALTHY_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`] | length(@)' \
    --output text 2>/dev/null || echo "0")

TOTAL_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    --query 'AutoScalingGroups[0].Instances | length(@)' \
    --output text 2>/dev/null || echo "0")

log_info "Instancias en ASG: ${HEALTHY_INSTANCES}/${TOTAL_INSTANCES} healthy"

if [ "$TOTAL_INSTANCES" -gt "0" ]; then
    if [ "$HEALTHY_INSTANCES" -eq "0" ]; then
        log_warning "⚠️  TODAS las instancias están unhealthy"
        log_warning "Esto puede indicar un problema en el deployment"
        echo ""
        log_info "Soluciones recomendadas:"
        echo "  1. Revisar logs de una instancia:"
        echo "     ssh -i <keypair.pem> ec2-user@<instance-ip>"
        echo "     tail -f /var/log/user-data.log"
        echo ""
        echo "  2. Reiniciar instancias:"
        echo "     aws autoscaling start-instance-refresh \\"
        echo "       --auto-scaling-group-name \"${ASG_NAME}\" \\"
        echo "       --preferences '{\"MinHealthyPercentage\": 0}'"
        echo ""
    else
        log_success "✓ Instancias healthy: ${HEALTHY_INSTANCES}/${TOTAL_INSTANCES}"
    fi
fi
echo ""

# ==========================================
# EJECUTAR MIGRACIONES DE BASE DE DATOS
# ==========================================
log_info "Para ejecutar las migraciones de base de datos, conéctate a RDS y ejecuta:"
log_info "Endpoint: ${DB_ENDPOINT}"
log_info "Database: proyecto_1"
log_info "User: postgres"
log_info ""
log_info "Comando:"
log_info "  for file in /opt/anb-app/db/*.up.sql; do"
log_info "    psql -h ${DB_ENDPOINT} -U postgres -d proyecto_1 -f \"\$file\""
log_info "  done"
echo ""

# ==========================================
# RESUMEN FINAL
# ==========================================
echo ""
echo "=========================================="
log_success "DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
log_info "Stack Name: ${STACK_NAME}"
log_info "S3 Bucket: ${S3_BUCKET}"
log_info "Application URL: http://${ALB_DNS}"
log_info "Database Endpoint: ${DB_ENDPOINT}"
echo ""
log_info "Próximos pasos:"
echo "  1. Ejecutar migraciones de base de datos (ver comando arriba)"
echo "  2. Esperar ~5 minutos a que las instancias se inicialicen"
echo "  3. Verificar health checks: curl http://${ALB_DNS}/health"
echo "  4. Acceder a la aplicación: http://${ALB_DNS}"
echo ""
log_info "Para ver logs de CloudFormation:"
echo "  aws cloudformation describe-stack-events --stack-name ${STACK_NAME}"
echo ""
log_info "Para destruir toda la infraestructura:"
echo "  ./cleanup.sh ${ENVIRONMENT_NAME}"
echo ""
echo "=========================================="

# ==========================================
# GUARDAR INFORMACIÓN DEL DESPLIEGUE
# ==========================================
DEPLOYMENT_INFO_FILE="${SCRIPT_DIR}/deployment-info.txt"
cat > "${DEPLOYMENT_INFO_FILE}" << EOF
ANB Rising Stars - Información de Despliegue
================================================
Fecha: $(date)
Stack Name: ${STACK_NAME}
Environment: ${ENVIRONMENT_NAME}
Región: ${AWS_REGION}
Cuenta AWS: ${AWS_ACCOUNT_ID}

Recursos:
---------
S3 Bucket: ${S3_BUCKET}
Application URL: http://${ALB_DNS}
Database Endpoint: ${DB_ENDPOINT}
Database Name: proyecto_1
Database User: postgres

Credenciales (GUARDAR DE FORMA SEGURA):
---------------------------------------
DB_PASSWORD: ${DB_PASSWORD}
JWT_SECRET: ${JWT_SECRET}

Para destruir:
--------------
./cleanup.sh ${ENVIRONMENT_NAME}
EOF

log_success "Información de despliegue guardada en: ${DEPLOYMENT_INFO_FILE}"
