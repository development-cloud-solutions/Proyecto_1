#!/bin/bash
# =============================================================================
# Script de despliegue automatizado para ANB Rising Stars usando Terraform
# Equivalente al deploy.sh de CloudFormation
# =============================================================================

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

show_usage() {
    echo ""
    echo "Uso: $0 <environment-name> <key-pair-name> <db-password> [jwt-secret]"
    echo ""
    echo "Parámetros:"
    echo "  environment-name  Nombre del entorno (ej: anb-production)"
    echo "  key-pair-name     Nombre del Key Pair EC2 (debe existir en AWS)"
    echo "  db-password       Contraseña de la base de datos (mín 8 caracteres)"
    echo "  jwt-secret        Secreto JWT (opcional, se genera automáticamente)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 anb-production my-keypair MySecurePass123!"
    echo "  $0 anb-production my-keypair MySecurePass123! \$(openssl rand -hex 32)"
    echo ""
    echo "Modo Quick Fix (re-subir deployment package):"
    echo "  $0 --fix"
    echo ""
}

# ==========================================
# VERIFICAR PREREQUISITOS
# ==========================================
check_prerequisites() {
    log_info "Verificando prerequisitos..."

    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform no está instalado."
        echo ""
        echo "Para instalar Terraform:"
        echo ""
        echo "  Windows (con Chocolatey):"
        echo "    choco install terraform"
        echo ""
        echo "  Windows (con Scoop):"
        echo "    scoop install terraform"
        echo ""
        echo "  Windows (manual):"
        echo "    1. Descarga desde: https://developer.hashicorp.com/terraform/downloads"
        echo "    2. Extrae el archivo zip"
        echo "    3. Agrega la carpeta al PATH del sistema"
        echo ""
        echo "  Linux/Mac:"
        echo "    brew install terraform"
        echo ""
        exit 1
    fi
    log_success "Terraform instalado: $(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"

    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no está instalado."
        echo ""
        echo "Para instalar AWS CLI:"
        echo "  https://aws.amazon.com/cli/"
        echo ""
        exit 1
    fi
    log_success "AWS CLI instalado: $(aws --version | cut -d' ' -f1)"

    # Verificar credenciales AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "No hay credenciales AWS configuradas."
        echo ""
        echo "Configura tus credenciales con:"
        echo "  aws configure"
        echo ""
        echo "O exporta las variables de entorno:"
        echo "  export AWS_ACCESS_KEY_ID=<tu-access-key>"
        echo "  export AWS_SECRET_ACCESS_KEY=<tu-secret-key>"
        echo "  export AWS_DEFAULT_REGION=us-east-1"
        echo ""
        exit 1
    fi

    # Obtener información de AWS
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")

    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"
        log_warning "No hay región configurada, usando: ${AWS_REGION}"
    fi

    log_success "Prerequisitos verificados"
    log_info "Cuenta AWS: ${AWS_ACCOUNT_ID}"
    log_info "Región AWS: ${AWS_REGION}"
    echo ""
}

# ==========================================
# MODO QUICK FIX
# ==========================================
fix_deployment() {
    log_info "Modo Quick Fix: Re-subiendo deployment package..."
    echo ""

    # Leer el bucket desde terraform output
    cd "${SCRIPT_DIR}"

    if [ ! -f "terraform.tfstate" ]; then
        log_error "No se encontró terraform.tfstate. ¿Ya ejecutaste terraform apply?"
        exit 1
    fi

    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)

    if [ -z "$S3_BUCKET" ]; then
        log_error "No se pudo obtener el nombre del bucket S3 desde Terraform"
        exit 1
    fi

    log_info "S3 Bucket: ${S3_BUCKET}"

    # Preparar y subir package
    prepare_deployment_package
    upload_deployment_package "$S3_BUCKET"

    # Mostrar comando para reiniciar instancias
    ENVIRONMENT_NAME=$(terraform output -raw environment_name 2>/dev/null || echo "anb-production")
    ASG_NAME="${ENVIRONMENT_NAME}-api-asg"

    echo ""
    log_success "Deployment package actualizado"
    echo ""
    log_warning "Para reiniciar las instancias y aplicar los cambios, ejecuta:"
    echo ""
    echo "  aws autoscaling start-instance-refresh \\"
    echo "    --auto-scaling-group-name \"${ASG_NAME}\" \\"
    echo "    --preferences '{\"MinHealthyPercentage\": 0}'"
    echo ""

    exit 0
}

# ==========================================
# PREPARAR DEPLOYMENT PACKAGE
# ==========================================
prepare_deployment_package() {
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

    # Crear tarball
    PACKAGE_FILE="${DEPLOYMENT_DIR}/app.tar.gz"
    log_info "Creando tarball..."
    cd "${DEPLOYMENT_DIR}"
    tar -czf app.tar.gz back/ front/ db/ docker-compose.api.yml docker-compose.worker.yml
    cd "${SCRIPT_DIR}"

    log_success "Deployment package creado: $(du -h ${PACKAGE_FILE} | cut -f1)"
}

# ==========================================
# CREAR BUCKET S3 PARA VIDEOS
# ==========================================
create_s3_bucket() {
    local BUCKET_NAME="$1"
    local REGION="$2"

    log_info "Verificando bucket S3: ${BUCKET_NAME}"

    if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
        log_info "Bucket ya existe: ${BUCKET_NAME}"
        return 0
    fi

    log_info "Creando bucket S3: ${BUCKET_NAME}"

    # Crear bucket
    if [ "$REGION" == "us-east-1" ]; then
        aws s3 mb "s3://${BUCKET_NAME}"
    else
        aws s3 mb "s3://${BUCKET_NAME}" --region "${REGION}"
    fi

    # Habilitar versionado
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled

    # Bloquear acceso público
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Habilitar encriptación
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
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
        --bucket "${BUCKET_NAME}" \
        --cors-configuration file:///tmp/cors.json
    rm -f /tmp/cors.json

    log_success "Bucket creado y configurado: ${BUCKET_NAME}"
}

# ==========================================
# SUBIR DEPLOYMENT PACKAGE
# ==========================================
upload_deployment_package() {
    local BUCKET_NAME="$1"
    local PACKAGE_FILE="${PROJECT_ROOT}/deployment-package/app.tar.gz"

    log_info "Subiendo deployment package a S3..."
    log_info "Destino: s3://${BUCKET_NAME}/deployments/latest/app.tar.gz"

    aws s3 cp "${PACKAGE_FILE}" "s3://${BUCKET_NAME}/deployments/latest/app.tar.gz"

    # Verificar que se subió
    if aws s3 ls "s3://${BUCKET_NAME}/deployments/latest/app.tar.gz" &> /dev/null; then
        log_success "Deployment package subido exitosamente"
    else
        log_error "Error al subir el deployment package"
        exit 1
    fi
}

# ==========================================
# CREAR ARCHIVO terraform.tfvars
# ==========================================
create_tfvars() {
    local ENV_NAME="$1"
    local KEY_PAIR="$2"
    local DB_PASS="$3"
    local JWT="$4"
    local BUCKET="$5"
    local REGION="$6"

    log_info "Creando archivo terraform.tfvars..."

    cat > "${SCRIPT_DIR}/terraform.tfvars" << EOF
# =============================================================================
# ANB Rising Stars - Terraform Variables
# Generado automáticamente por deploy.sh - $(date)
# =============================================================================

# AWS Configuration
aws_region = "${REGION}"

# Environment Configuration
environment_name = "${ENV_NAME}"
key_pair_name    = "${KEY_PAIR}"

# Database Configuration
db_instance_class       = "db.t3.micro"
db_name                 = "proyecto_1"
db_username             = "postgres"
db_password             = "${DB_PASS}"
allocated_storage       = 20
backup_retention_period = 0
multi_az                = false

# Application Configuration
jwt_secret                = "${JWT}"
deployment_package_s3_key = "deployments/latest/app.tar.gz"

# API Auto Scaling Configuration
api_instance_type    = "t3.small"
api_min_size         = 1
api_max_size         = 3
api_desired_capacity = 1
cpu_target_value     = 70

# Worker Auto Scaling Configuration
worker_instance_type    = "t3.small"
worker_min_size         = 1
worker_max_size         = 3
worker_desired_capacity = 1
worker_concurrency      = 4
target_queue_depth      = 10

# SQS Queue Configuration
message_retention_period = 345600
visibility_timeout       = 900
max_receive_count        = 3

# Network Configuration
vpc_cidr              = "10.0.0.0/16"
public_subnet_1_cidr  = "10.0.1.0/24"
public_subnet_2_cidr  = "10.0.2.0/24"
private_subnet_1_cidr = "10.0.11.0/24"
private_subnet_2_cidr = "10.0.12.0/24"

# S3 Configuration - Bucket ya creado por este script
video_storage_bucket_name = "${BUCKET}"
create_s3_bucket          = false
EOF

    log_success "Archivo terraform.tfvars creado"
}

# ==========================================
# MAIN
# ==========================================

# Mostrar ayuda
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Modo Quick Fix
if [ "$1" = "--fix" ] || [ "$1" = "fix" ]; then
    check_prerequisites
    fix_deployment
fi

# Verificar parámetros
ENVIRONMENT_NAME="${1:-}"
KEY_PAIR_NAME="${2:-}"
DB_PASSWORD="${3:-}"
JWT_SECRET="${4:-}"

if [ -z "$ENVIRONMENT_NAME" ] || [ -z "$KEY_PAIR_NAME" ] || [ -z "$DB_PASSWORD" ]; then
    log_error "Faltan parámetros requeridos"
    show_usage
    exit 1
fi

# Generar JWT_SECRET si no se proporcionó
if [ -z "$JWT_SECRET" ]; then
    log_warning "JWT_SECRET no proporcionado, generando uno automáticamente..."
    JWT_SECRET=$(openssl rand -hex 32)
    log_info "JWT_SECRET generado"
fi

# Verificar prerequisitos
check_prerequisites

# Verificar que el KeyPair existe
log_info "Verificando Key Pair: ${KEY_PAIR_NAME}"
if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" &> /dev/null; then
    log_error "El Key Pair '${KEY_PAIR_NAME}' no existe en tu cuenta AWS"
    echo ""
    echo "Para crear un Key Pair:"
    echo "  aws ec2 create-key-pair --key-name ${KEY_PAIR_NAME} --query 'KeyMaterial' --output text > ${KEY_PAIR_NAME}.pem"
    echo "  chmod 400 ${KEY_PAIR_NAME}.pem"
    echo ""
    exit 1
fi
log_success "Key Pair verificado: ${KEY_PAIR_NAME}"
echo ""

# Preparar deployment package
prepare_deployment_package
echo ""

# Crear bucket S3 para videos
VIDEOS_BUCKET="anb-videos-${AWS_ACCOUNT_ID}-${AWS_REGION}"
create_s3_bucket "$VIDEOS_BUCKET" "$AWS_REGION"
echo ""

# Subir deployment package
upload_deployment_package "$VIDEOS_BUCKET"
echo ""

# Crear terraform.tfvars
create_tfvars "$ENVIRONMENT_NAME" "$KEY_PAIR_NAME" "$DB_PASSWORD" "$JWT_SECRET" "$VIDEOS_BUCKET" "$AWS_REGION"
echo ""

# ==========================================
# INICIALIZAR Y APLICAR TERRAFORM
# ==========================================
cd "${SCRIPT_DIR}"

log_info "Inicializando Terraform..."
terraform init

echo ""
log_info "Validando configuración de Terraform..."
terraform validate

echo ""
log_info "Generando plan de Terraform..."
terraform plan -out=tfplan

echo ""
echo "=========================================="
log_warning "REVISIÓN DEL PLAN"
echo "=========================================="
echo ""
echo "Terraform ha generado un plan de ejecución."
echo "Revisa los cambios que se van a realizar."
echo ""
read -p "¿Deseas aplicar este plan? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Despliegue cancelado por el usuario"
    rm -f tfplan
    exit 0
fi

echo ""
log_info "Aplicando Terraform (esto puede tomar 10-15 minutos)..."
terraform apply tfplan

rm -f tfplan

log_success "Terraform aplicado exitosamente!"
echo ""

# ==========================================
# OBTENER OUTPUTS
# ==========================================
log_info "Obteniendo información del despliegue..."

S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "N/A")
ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "N/A")
DB_ENDPOINT=$(terraform output -raw db_endpoint 2>/dev/null || echo "N/A")
SQS_QUEUE=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "N/A")

# ==========================================
# VERIFICAR ESTADO DE INSTANCIAS
# ==========================================
echo ""
log_info "Verificando estado del Auto Scaling Group..."

ASG_NAME="${ENVIRONMENT_NAME}-api-asg"

# Esperar un momento para que las instancias se registren
sleep 5

HEALTHY_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`] | length(@)' \
    --output text 2>/dev/null || echo "0")

TOTAL_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    --query 'AutoScalingGroups[0].Instances | length(@)' \
    --output text 2>/dev/null || echo "0")

log_info "Instancias en ASG: ${HEALTHY_INSTANCES}/${TOTAL_INSTANCES} healthy"

if [ "$TOTAL_INSTANCES" -gt "0" ] && [ "$HEALTHY_INSTANCES" -eq "0" ]; then
    log_warning "Las instancias aún se están inicializando (esto es normal)"
    log_info "Las instancias estarán healthy en ~5-10 minutos"
fi

# ==========================================
# RESUMEN FINAL
# ==========================================
echo ""
echo "=========================================="
log_success "DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
log_info "Environment:        ${ENVIRONMENT_NAME}"
log_info "S3 Bucket:          ${S3_BUCKET}"
log_info "Application URL:    http://${ALB_DNS}"
log_info "Database Endpoint:  ${DB_ENDPOINT}"
log_info "SQS Queue:          ${SQS_QUEUE}"
echo ""
log_info "Próximos pasos:"
echo "  1. Esperar ~5-10 minutos a que las instancias se inicialicen"
echo "  2. Ejecutar migraciones de base de datos (ingresar al EC2):"
echo "     cd /opt/anb-app/"
echo "     for file in db/*.up.sql; do "
echo "        psql -h ${DB_ENDPOINT} -U postgres -d proyecto_1 -f \"\$file\""
echo "     done"
echo "  3. Verificar health checks:"
echo "     curl http://${ALB_DNS}/health"
echo "  4. Acceder a la aplicación:"
echo "     http://${ALB_DNS}"
echo ""
log_info "Para ver el estado de Terraform:"
echo "  cd ${SCRIPT_DIR}"
echo "  terraform show"
echo ""
log_info "Para destruir toda la infraestructura:"
echo "  ./cleanup.sh"
echo ""
echo "=========================================="

# ==========================================
# GUARDAR INFORMACIÓN DEL DESPLIEGUE
# ==========================================
DEPLOYMENT_INFO_FILE="${SCRIPT_DIR}/deployment-info.txt"
cat > "${DEPLOYMENT_INFO_FILE}" << EOF
ANB Rising Stars - Información de Despliegue (Terraform)
========================================================
Fecha: $(date)
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
SQS Queue: ${SQS_QUEUE}

Credenciales (GUARDAR DE FORMA SEGURA):
---------------------------------------
DB_PASSWORD: ${DB_PASSWORD}
JWT_SECRET: ${JWT_SECRET}

Comandos útiles:
----------------
Ver estado:     cd ${SCRIPT_DIR} && terraform show
Ver outputs:    cd ${SCRIPT_DIR} && terraform output
Destruir:       cd ${SCRIPT_DIR} && ./cleanup.sh
Quick Fix:      cd ${SCRIPT_DIR} && ./deploy.sh --fix
EOF

log_success "Información guardada en: ${DEPLOYMENT_INFO_FILE}"
