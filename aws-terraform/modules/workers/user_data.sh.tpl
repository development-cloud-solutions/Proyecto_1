#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Iniciando configuración de Worker"
echo "Hora: $(date)"
echo "=========================================="

# Actualizar sistema
yum update -y
yum install -y docker git wget telnet

# Instalar cliente de postgres
yum install -y postgresql15

# Iniciar Docker
systemctl enable docker
systemctl start docker
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
APP_DIR="/opt/anb-worker"
mkdir -p $APP_DIR
cd $APP_DIR

# Esperar credenciales de IAM
echo "Esperando credenciales de IAM..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if aws sts get-caller-identity --region ${aws_region} > /dev/null 2>&1; then
        echo "✓ Credenciales de IAM disponibles"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 10
done

# Descargar código desde S3
S3_BUCKET="${s3_bucket_name}"
echo "Descargando app.tar.gz desde s3://$S3_BUCKET/${deployment_package_s3_key}"
aws s3 cp s3://$S3_BUCKET/${deployment_package_s3_key} app.tar.gz --region ${aws_region}

if [ ! -f app.tar.gz ]; then
    echo "✗ ERROR: No se pudo descargar app.tar.gz"
    exit 1
fi

tar -xzf app.tar.gz
rm app.tar.gz

# Crear red Docker
docker network create anb_network || true

# Configurar variables de entorno con SQS
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

# Queue Configuration - SQS
QUEUE_TYPE=sqs
SQS_REGION=${aws_region}
SQS_QUEUE_URL=${sqs_queue_url}

# Worker Configuration
WORKER_MODE=true
WORKER_CONCURRENCY=${worker_concurrency}
ENVIRONMENT=production

# Application Configuration
STORAGE_TYPE=s3

# Limits
MAX_FILE_SIZE=104857600
MAX_VIDEO_DURATION=30
OUTPUT_RESOLUTION=1280x720
OUTPUT_ASPECT_RATIO=16:9
EOF

# Copiar .env a back/
mkdir -p $APP_DIR/back
cp $APP_DIR/.env $APP_DIR/back/.env

# Construir y levantar worker
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

docker-compose -f docker-compose.worker.yml build --no-cache
docker-compose -f docker-compose.worker.yml up -d

# Health check
echo "Verificando que el worker está en ejecución..."
sleep 20

if docker ps | grep -q anb_worker; then
    echo "✓ Worker está en ejecución"
    docker logs anb_worker --tail 50
else
    echo "✗ ERROR: El worker no se inició"
    docker-compose -f docker-compose.worker.yml logs
    exit 1
fi

echo "=========================================="
echo "Worker configurado exitosamente"
echo "=========================================="
