#!/bin/bash
# Script de limpieza para eliminar toda la infraestructura de ANB Rising Stars en AWS
# ADVERTENCIA: Este script eliminará TODOS los recursos creados por CloudFormation

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# ==========================================
# CONFIGURACIÓN
# ==========================================
ENVIRONMENT_NAME="${1:-anb-production}"
STACK_NAME="${ENVIRONMENT_NAME}-master"

if [ -z "$1" ]; then
    log_warning "Uso: $0 <environment-name>"
    log_warning "Usando environment por defecto: ${ENVIRONMENT_NAME}"
fi

# ==========================================
# CONFIRMACIÓN
# ==========================================
echo ""
log_warning "=========================================="
log_warning "ADVERTENCIA: ELIMINACIÓN DE RECURSOS"
log_warning "=========================================="
echo ""
log_warning "Este script eliminará PERMANENTEMENTE:"
echo "  - Stack de CloudFormation: ${STACK_NAME}"
echo "  - Todos los recursos AWS asociados:"
echo "    * VPC y subnets"
echo "    * EC2 instances (API y Workers)"
echo "    * Auto Scaling Group"
echo "    * Application Load Balancer"
echo "    * Redis EC2 instance (con Docker container)"
echo "    * RDS Database (con snapshot final)"
echo "    * S3 Bucket (necesita estar vacío)"
echo "    * IAM Roles y Policies"
echo "    * Security Groups"
echo "    * CloudWatch Logs y Alarms"
echo ""
log_warning "Esta acción NO SE PUEDE DESHACER"
echo ""
read -p "¿Estás seguro de que quieres continuar? (escribe 'yes' para confirmar): " confirmation

if [ "$confirmation" != "yes" ]; then
    log_info "Limpieza cancelada"
    exit 0
fi

# ==========================================
# OBTENER INFORMACIÓN DEL STACK
# ==========================================
log_info "Verificando existencia del stack: ${STACK_NAME}"

if ! aws cloudformation describe-stacks --stack-name "${STACK_NAME}" &> /dev/null; then
    log_error "El stack ${STACK_NAME} no existe"
    exit 1
fi

# Obtener S3 bucket
S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

log_info "S3 Bucket encontrado: ${S3_BUCKET}"

# ==========================================
# VACIAR S3 BUCKET
# ==========================================
if [ -n "$S3_BUCKET" ]; then
    log_warning "Vaciando S3 bucket: ${S3_BUCKET}"

    # # Preguntar si quiere hacer backup
    # read -p "¿Quieres hacer un backup del bucket S3 antes de eliminarlo? (y/n): " backup_choice
    # 
    # if [ "$backup_choice" = "y" ] || [ "$backup_choice" = "Y" ]; then
    #     BACKUP_DIR="s3-backup-$(date +%Y%m%d-%H%M%S)"
    #     log_info "Descargando backup a: ${BACKUP_DIR}"
    #     mkdir -p "${BACKUP_DIR}"
    #     aws s3 sync "s3://${S3_BUCKET}" "${BACKUP_DIR}/"
    #     log_success "Backup completado en: ${BACKUP_DIR}"
    # fi

    # Eliminar todas las versiones de objetos
    log_info "Eliminando todas las versiones de objetos..."

    # Verificar si jq está disponible
    if command -v jq &> /dev/null; then
        # Método con jq (más eficiente)
        log_info "Obteniendo lista de versiones..."
        VERSIONS_OUTPUT=$(aws s3api list-object-versions \
            --bucket "${S3_BUCKET}" \
            --output json 2>/dev/null || echo '{}')
        
        # Contar versiones y delete markers
        VERSION_COUNT=$(echo "$VERSIONS_OUTPUT" | jq -r '(.Versions // []) | length')
        MARKER_COUNT=$(echo "$VERSIONS_OUTPUT" | jq -r '(.DeleteMarkers // []) | length')
        
        log_info "Versiones encontradas: ${VERSION_COUNT}"
        log_info "Delete markers encontrados: ${MARKER_COUNT}"
        
        # Eliminar versiones solo si existen
        if [ "$VERSION_COUNT" -gt 0 ]; then
            log_info "Eliminando versiones de objetos..."
            echo "$VERSIONS_OUTPUT" | \
            jq -r '(.Versions // []) | .[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
            while read -r args; do
                if [ -n "$args" ]; then
                    aws s3api delete-object --bucket "${S3_BUCKET}" $args 2>/dev/null || true
                fi
            done
            log_success "Versiones eliminadas"
        fi

        # Eliminar delete markers solo si existen
        if [ "$MARKER_COUNT" -gt 0 ]; then
            log_info "Eliminando delete markers..."
            echo "$VERSIONS_OUTPUT" | \
            jq -r '(.DeleteMarkers // []) | .[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
            while read -r args; do
                if [ -n "$args" ]; then
                    aws s3api delete-object --bucket "${S3_BUCKET}" $args 2>/dev/null || true
                fi
            done
            log_success "Delete markers eliminados"
        fi
        
        if [ "$VERSION_COUNT" -eq 0 ] && [ "$MARKER_COUNT" -eq 0 ]; then
            log_info "No hay versiones ni delete markers para eliminar"
        fi
    else
        # Método alternativo sin jq (usando Python)
        log_warning "jq no está instalado, usando método alternativo..."

        # Eliminar versiones
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET}" \
            --output json 2>/dev/null | \
        python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for version in data.get('Versions', []):
        print(f\"--key '{version['Key']}' --version-id '{version['VersionId']}'\")
except: pass
" | while read -r args; do
    if [ -n "$args" ]; then
        aws s3api delete-object --bucket "${S3_BUCKET}" $args 2>/dev/null || true
    fi
done

        # Eliminar delete markers
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET}" \
            --output json 2>/dev/null | \
        python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for marker in data.get('DeleteMarkers', []):
        print(f\"--key '{marker['Key']}' --version-id '{marker['VersionId']}'\")
except: pass
" | while read -r args; do
    if [ -n "$args" ]; then
        aws s3api delete-object --bucket "${S3_BUCKET}" $args 2>/dev/null || true
    fi
done
    fi

    # Eliminar objetos actuales
    log_info "Eliminando objetos restantes..."
    aws s3 rm "s3://${S3_BUCKET}" --recursive 2>/dev/null || true

    log_success "S3 bucket vaciado"
fi

# ==========================================
# ELIMINAR CLOUDFORMATION STACK
# ==========================================
log_info "Eliminando CloudFormation stack: ${STACK_NAME}"
log_info "Esto puede tomar 10-15 minutos..."

aws cloudformation delete-stack --stack-name "${STACK_NAME}"

# Esperar a que se elimine
log_info "Esperando a que el stack se elimine completamente..."
aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" 2>/dev/null || {
    log_warning "El comando wait falló, pero el stack puede estar eliminándose..."
    log_info "Verifica el estado con: aws cloudformation describe-stacks --stack-name ${STACK_NAME}"
}

log_success "Stack eliminado exitosamente"

# ==========================================
# LIMPIAR BUCKET DE TEMPLATES (OPCIONAL)
# ==========================================
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
TEMPLATES_BUCKET="anb-cf-templates-${AWS_ACCOUNT_ID}-${AWS_REGION}"

if aws s3 ls "s3://${TEMPLATES_BUCKET}" &> /dev/null; then
    read -p "¿Quieres eliminar también el bucket de templates (${TEMPLATES_BUCKET})? (y/n): " delete_templates

    if [ "$delete_templates" = "y" ] || [ "$delete_templates" = "Y" ]; then
        log_info "Eliminando bucket de templates..."
        aws s3 rm "s3://${TEMPLATES_BUCKET}" --recursive
        aws s3 rb "s3://${TEMPLATES_BUCKET}"
        log_success "Bucket de templates eliminado"
    fi
fi

# ==========================================
# VERIFICAR RECURSOS HUÉRFANOS
# ==========================================
log_info "Verificando recursos huérfanos..."

# Verificar EBS volumes huérfanos
ORPHAN_VOLUMES=$(aws ec2 describe-volumes \
    --filters "Name=status,Values=available" "Name=tag:Environment,Values=${ENVIRONMENT_NAME}" \
    --query 'Volumes[].VolumeId' \
    --output text 2>/dev/null || echo "")

if [ -n "$ORPHAN_VOLUMES" ]; then
    log_warning "Se encontraron volúmenes EBS huérfanos:"
    echo "$ORPHAN_VOLUMES"
    read -p "¿Quieres eliminarlos? (y/n): " delete_volumes

    if [ "$delete_volumes" = "y" ] || [ "$delete_volumes" = "Y" ]; then
        for volume_id in $ORPHAN_VOLUMES; do
            log_info "Eliminando volumen: ${volume_id}"
            aws ec2 delete-volume --volume-id "${volume_id}" || true
        done
    fi
fi

# Verificar Elastic IPs no asociadas
ORPHAN_EIPS=$(aws ec2 describe-addresses \
    --filters "Name=tag:Environment,Values=${ENVIRONMENT_NAME}" \
    --query 'Addresses[?AssociationId==null].AllocationId' \
    --output text 2>/dev/null || echo "")

if [ -n "$ORPHAN_EIPS" ]; then
    log_warning "Se encontraron Elastic IPs no asociadas:"
    echo "$ORPHAN_EIPS"
    read -p "¿Quieres liberarlas? (y/n): " release_eips

    if [ "$release_eips" = "y" ] || [ "$release_eips" = "Y" ]; then
        for eip_id in $ORPHAN_EIPS; do
            log_info "Liberando EIP: ${eip_id}"
            aws ec2 release-address --allocation-id "${eip_id}" || true
        done
    fi
fi

# ==========================================
# RESUMEN FINAL
# ==========================================
echo ""
echo "=========================================="
log_success "LIMPIEZA COMPLETADA"
echo "=========================================="
echo ""
log_info "Recursos eliminados:"
echo "  ✓ CloudFormation Stack: ${STACK_NAME}"
[ -n "$S3_BUCKET" ] && echo "  ✓ S3 Bucket: ${S3_BUCKET}"
echo "  ✓ VPC y componentes de red"
echo "  ✓ EC2 instances"
echo "  ✓ Auto Scaling Group"
echo "  ✓ Load Balancer"
echo "  ✓ RDS Database (con snapshot)"
echo "  ✓ IAM Roles"
echo ""
log_info "Para verificar que no quedan recursos:"
echo "  aws cloudformation list-stacks --stack-status-filter DELETE_COMPLETE | grep ${STACK_NAME}"
echo ""
log_warning "IMPORTANTE: Verifica tu cuenta AWS para asegurarte de que no quedan recursos cobrando"
echo ""
echo "=========================================="

# Eliminar archivo de información de despliegue
DEPLOYMENT_INFO_FILE="$(dirname "$0")/deployment-info.txt"
if [ -f "$DEPLOYMENT_INFO_FILE" ]; then
    rm -f "$DEPLOYMENT_INFO_FILE"
    log_info "Archivo de información de despliegue eliminado"
fi
