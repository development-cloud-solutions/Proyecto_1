#!/bin/bash
# =============================================================================
# Script de limpieza para ANB Rising Stars - Terraform
# Destruye toda la infraestructura creada
# =============================================================================

set -e

# ==========================================
# CONFIGURACIÓN
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
# VERIFICACIONES
# ==========================================
cd "${SCRIPT_DIR}"

if [ ! -f "terraform.tfstate" ]; then
    log_error "No se encontró terraform.tfstate en ${SCRIPT_DIR}"
    log_error "¿Estás seguro de que Terraform fue ejecutado en este directorio?"
    exit 1
fi

# Obtener información actual
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
ENVIRONMENT=$(terraform output -raw environment_name 2>/dev/null || echo "")

echo ""
echo "=========================================="
log_warning "DESTRUCCIÓN DE INFRAESTRUCTURA"
echo "=========================================="
echo ""

if [ -n "$S3_BUCKET" ]; then
    log_info "S3 Bucket: ${S3_BUCKET}"
fi
if [ -n "$ENVIRONMENT" ]; then
    log_info "Environment: ${ENVIRONMENT}"
fi

echo ""
log_warning "Esta acción DESTRUIRÁ todos los recursos de AWS creados por Terraform:"
echo "  - VPC y subnets"
echo "  - Security Groups"
echo "  - RDS Database (TODOS LOS DATOS SE PERDERÁN)"
echo "  - Application Load Balancer"
echo "  - Auto Scaling Groups e instancias EC2"
echo "  - SQS Queues"
echo "  - CloudWatch Alarms y Log Groups"
echo ""
log_warning "El bucket S3 NO será eliminado automáticamente (contiene videos)"
echo ""

read -p "¿Estás SEGURO de que deseas continuar? (escribe 'yes' para confirmar): " -r
echo ""

if [ "$REPLY" != "yes" ]; then
    log_info "Operación cancelada"
    exit 0
fi

# ==========================================
# BACKUP OPCIONAL DEL BUCKET S3
# ==========================================
if [ -n "$S3_BUCKET" ]; then
    echo ""
    read -p "¿Deseas hacer un backup del bucket S3 antes de continuar? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_DIR="${SCRIPT_DIR}/s3-backup-$(date +%Y%m%d-%H%M%S)"
        log_info "Creando backup en: ${BACKUP_DIR}"
        mkdir -p "${BACKUP_DIR}"
        aws s3 sync "s3://${S3_BUCKET}" "${BACKUP_DIR}/" || true
        log_success "Backup completado"
    fi
fi

# ==========================================
# DESTRUIR INFRAESTRUCTURA CON TERRAFORM
# ==========================================
echo ""
log_info "Ejecutando terraform destroy..."
echo ""

terraform destroy -auto-approve

log_success "Infraestructura de Terraform destruida"

# ==========================================
# LIMPIAR BUCKET S3 (OPCIONAL)
# ==========================================
if [ -n "$S3_BUCKET" ]; then
    echo ""
    read -p "¿Deseas VACIAR y ELIMINAR el bucket S3 ${S3_BUCKET}? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Vaciando bucket S3..."

        # Eliminar todas las versiones de objetos
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET}" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output text 2>/dev/null | while read KEY VERSION; do
            if [ -n "$KEY" ] && [ -n "$VERSION" ]; then
                aws s3api delete-object --bucket "${S3_BUCKET}" --key "$KEY" --version-id "$VERSION" 2>/dev/null || true
            fi
        done

        # Eliminar marcadores de eliminación
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET}" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output text 2>/dev/null | while read KEY VERSION; do
            if [ -n "$KEY" ] && [ -n "$VERSION" ]; then
                aws s3api delete-object --bucket "${S3_BUCKET}" --key "$KEY" --version-id "$VERSION" 2>/dev/null || true
            fi
        done

        # Eliminar objetos sin versionar
        aws s3 rm "s3://${S3_BUCKET}" --recursive 2>/dev/null || true

        # Eliminar el bucket
        log_info "Eliminando bucket..."
        aws s3 rb "s3://${S3_BUCKET}" --force 2>/dev/null || true

        if ! aws s3 ls "s3://${S3_BUCKET}" 2>/dev/null; then
            log_success "Bucket S3 eliminado: ${S3_BUCKET}"
        else
            log_warning "No se pudo eliminar el bucket. Puede que aún tenga objetos."
        fi
    else
        log_info "Bucket S3 conservado: ${S3_BUCKET}"
    fi
fi

# ==========================================
# LIMPIAR ARCHIVOS LOCALES
# ==========================================
echo ""
read -p "¿Deseas eliminar los archivos locales de Terraform (state, tfvars, etc)? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Limpiando archivos locales..."
    rm -rf "${SCRIPT_DIR}/.terraform"
    rm -f "${SCRIPT_DIR}/.terraform.lock.hcl"
    rm -f "${SCRIPT_DIR}/terraform.tfstate"
    rm -f "${SCRIPT_DIR}/terraform.tfstate.backup"
    rm -f "${SCRIPT_DIR}/terraform.tfvars"
    rm -f "${SCRIPT_DIR}/tfplan"
    rm -f "${SCRIPT_DIR}/deployment-info.txt"
    rm -rf "${SCRIPT_DIR}/../deployment-package"
    log_success "Archivos locales eliminados"
else
    log_info "Archivos locales conservados"
fi

# ==========================================
# RESUMEN
# ==========================================
echo ""
echo "=========================================="
log_success "LIMPIEZA COMPLETADA"
echo "=========================================="
echo ""
log_info "Recursos eliminados:"
echo "  - Infraestructura de AWS (Terraform)"
if [ -n "$S3_BUCKET" ]; then
    if ! aws s3 ls "s3://${S3_BUCKET}" 2>/dev/null; then
        echo "  - Bucket S3: ${S3_BUCKET}"
    else
        echo "  - Bucket S3: ${S3_BUCKET} (CONSERVADO)"
    fi
fi
echo ""
