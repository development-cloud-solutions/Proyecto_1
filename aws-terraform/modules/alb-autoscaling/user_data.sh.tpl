#!/bin/bash
# IMPORTANTE: NO usar 'set -e' porque queremos que el script continúe
# incluso si hay errores, para poder hacer debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Iniciando configuración de instancia API"
echo "Hora: $(date)"
echo "Región: ${aws_region}"
echo "S3 Bucket: ${s3_bucket_name}"
echo "=========================================="

# Actualizar sistema
yum update -y
yum install -y docker git wget telnet

# Instalar cliente de postgres
yum install -y postgresql15

# Iniciar Docker
systemctl enable docker
systemctl start docker

# Agregar ec2-user al grupo docker para evitar 'permission denied'
usermod -aG docker ec2-user

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Crear directorio de aplicación
APP_DIR="/opt/anb-app"
mkdir -p $APP_DIR
cd $APP_DIR

# Esperar a que IAM Instance Profile esté disponible
echo "Esperando a que las credenciales de IAM estén disponibles..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if aws sts get-caller-identity --region ${aws_region} > /dev/null 2>&1; then
        echo "✓ Credenciales de IAM disponibles"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "Intento $ATTEMPT/$MAX_ATTEMPTS - Esperando credenciales..."
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "✗ ERROR: No se pudieron obtener credenciales de IAM después de $MAX_ATTEMPTS intentos"
    exit 1
fi

# Descargar código desde S3
S3_BUCKET="${s3_bucket_name}"
S3_KEY="${deployment_package_s3_key}"

echo "Verificando que app.tar.gz existe en S3..."
if aws s3 ls "s3://$S3_BUCKET/$S3_KEY" --region ${aws_region} > /dev/null 2>&1; then
    echo "✓ Archivo encontrado en s3://$S3_BUCKET/$S3_KEY"
    aws s3 cp "s3://$S3_BUCKET/$S3_KEY" app.tar.gz --region ${aws_region}
    tar -xzf app.tar.gz
    rm app.tar.gz
    echo "✓ Código descargado y extraído correctamente"
else
    echo "✗ ERROR CRÍTICO: app.tar.gz NO existe en S3"
    echo "Ubicación esperada: s3://$S3_BUCKET/$S3_KEY"
    echo ""
    echo "SOLUCIÓN:"
    echo "  1. Ejecuta: cd /path/to/proyecto && ./aws-deployment/cloudformation/deploy.sh --fix anb-production-master"
    echo "  2. O sube manualmente: aws s3 cp app.tar.gz s3://$S3_BUCKET/$S3_KEY"
    echo ""
    echo "La instancia permanecerá activa para debugging. Revisa este log en:"
    echo "  tail -f /var/log/user-data.log"
    echo ""
    echo "Terminando script user-data (instancia quedará unhealthy)..."
    exit 0  # Exit 0 para que la instancia no se marque como 'failed to launch'
fi

# Crear red Docker
docker network create anb_network || true

# Configurar variables de entorno
cat > $APP_DIR/.env << 'EOF'
# AWS Configuration
AWS_REGION=${aws_region}
S3_BUCKET_NAME=${s3_bucket_name}
S3_UPLOAD_PREFIX=uploads
S3_PROCESSED_PREFIX=processed

# Database Configuration
DB_HOST=${db_host}
DB_PORT=5432
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_SSL_MODE=require

# Queue Configuration - SQS para AWS
QUEUE_TYPE=sqs
SQS_REGION=${aws_region}
SQS_QUEUE_URL=${sqs_queue_url}

# JWT Configuration
JWT_SECRET=${jwt_secret}
JWT_EXPIRATION=24h

# Application Configuration
STORAGE_TYPE=s3
GIN_MODE=release
ENVIRONMENT=production
WORKER_CONCURRENCY=0
WORKER_MODE=false

# ELB Configuration
ELB_DNS_NAME=http://${alb_dns_name}

# Limits
MAX_FILE_SIZE=104857600
MAX_VIDEO_DURATION=30
OUTPUT_RESOLUTION=1280x720
OUTPUT_ASPECT_RATIO=16:9
EOF

# Copiar .env a back/
mkdir -p $APP_DIR/back
cp $APP_DIR/.env $APP_DIR/back/.env

# Crear .env para frontend con variables VITE
mkdir -p $APP_DIR/front
cat > $APP_DIR/front/.env << 'FRONTEND_EOF'
# ANB Rising Stars Frontend Configuration
VITE_API_URL=http://${alb_dns_name}
VITE_VIDEOS_URL=http://${alb_dns_name}
VITE_APP_NAME=ANB Rising Stars Showcase
VITE_APP_VERSION=1.0.0
VITE_ENVIRONMENT=production

# API Configuration
VITE_MAX_FILE_SIZE=104857600
VITE_ALLOWED_FILE_TYPES=video/mp4,video/mov,video/avi
VITE_MAX_VIDEO_DURATION=30

# Features
VITE_ENABLE_DEBUG=false
VITE_ENABLE_ANALYTICS=false

# Elastic Load Balancing
ELB_DNS_NAME=http://${alb_dns_name}
FRONTEND_EOF

# Construir y levantar servicios
# Deshabilitar BuildKit para compatibilidad con Amazon Linux 2023
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

docker-compose -f docker-compose.api.yml build --no-cache
docker-compose -f docker-compose.api.yml up -d

# Health check
echo "Esperando que los servicios estén listos..."
sleep 30

MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "✓ API está respondiendo correctamente"
        break
    fi
    echo "Esperando que la API esté lista... intento $((RETRY_COUNT+1))/$MAX_RETRIES"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ ERROR: La API no respondió después de $MAX_RETRIES intentos"
    echo "Mostrando logs de Docker Compose para debugging:"
    docker-compose -f docker-compose.api.yml logs --tail=100
    echo ""
    echo "ADVERTENCIA: Los servicios no están respondiendo correctamente"
    echo "La instancia permanecerá activa para debugging pero será marcada unhealthy por el ELB"
    echo "Conéctate via SSH y revisa: tail -f /var/log/user-data.log"
    # NO hacer exit 1 - dejar que la instancia viva para debugging
    # El ELB health check la marcará como unhealthy automáticamente
fi

echo "=========================================="
echo "Configuración completada exitosamente"
echo "=========================================="
