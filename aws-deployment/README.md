# CloudFormation Templates - ANB Rising Stars

Despliegue automatizado de toda la infraestructura en AWS usando AWS CloudFormation.

## Descripción General

Este directorio contiene plantillas de CloudFormation para desplegar automáticamente toda la arquitectura de ANB Rising Stars en AWS con Auto Scaling, incluyendo:

- VPC con subnets públicas y privadas en múltiples AZs
- Application Load Balancer (ALB)
- Auto Scaling Group para instancias API (min: 1, max: 3)
- Redis en EC2 (Docker) para cola de tareas asíncronas (alternativa a ElastiCache para AWS Academy)
- Amazon RDS PostgreSQL 15
- Amazon S3 para almacenamiento de videos
- Instancias Worker para procesamiento de videos
- IAM Roles y Security Groups
- CloudWatch Alarms y Logs

## Arquitectura Desplegada

```
                    ┌─────────────────────────────────────────┐
                    │          Internet Gateway               │
                    └──────────────┬──────────────────────────┘
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │ Application Load    │
                         │ Balancer (ALB)      │
                         └──────────┬──────────┘
                                    │
                          ┌─────────┼─────────┐
                          │         │         │
                          ▼         ▼         ▼
                     ┌─────────┐ ┌─────────┐ ┌─────────┐
                     │ API #1  │ │ API #2  │ │ API #3  │
                     │ t3.small│ │ t3.small│ │ t3.small│
                     │ (ASG)   │ │ (ASG)   │ │ (ASG)   │
                     └────┬────┘ └────┬────┘ └────┬────┘
                          │           │           │
                          └───────────┼───────────┘
                                      │
                     ┌────────────────┼────────────────┐
                     │                │                │
                     ▼                ▼                ▼
          ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
          │ Redis EC2        │  │ RDS PostgreSQL 15│  │ S3 Bucket        │
          │ (t3.micro)       │  │ (db.t3.micro)    │  │ ├─ uploads/      │
          │ Docker Redis 7   │  │ Multi-AZ (opt)   │  │ └─ processed/    │
          └────────┬─────────┘  └──────────────────┘  └────────▲─────────┘
                   │                                           │
                   │    ┌──────────────────────────────────────┘
                   │    │
                   ▼    ▼
              ┌─────────────┐       ┌─────────────┐
              │  Worker #1  │       │  Worker #2  │
              │  t3.small   │       │  t3.small   │
              │  (EC2)      │       │  (EC2)      │
              └─────────────┘       └─────────────┘

Flujo de Procesamiento de Videos:
1. Usuario sube video → API recibe → Guarda en S3 (uploads/)
2. API encola tarea en Redis (via Asynq)
3. Worker toma tarea de Redis → Descarga de S3 → Procesa con ffmpeg
4. Worker sube resultado a S3 (processed/) → Actualiza DB
5. Usuario consulta estado → API responde desde DB
```

## Estructura de Archivos

```
aws-deployment/
├── 00-master-stack.yaml        # Stack maestro (orquesta todos los nested stacks)
├── 01-vpc-networking.yaml      # VPC, subnets (públicas y privadas)
├── 02-s3-iam.yaml              # S3 bucket y roles IAM para EC2
├── 03-elasticache.yaml         # Redis on EC2 (Docker) - alternativa a ElastiCache
├── 04-rds-database.yaml        # RDS PostgreSQL 15
├── 05-alb-autoscaling.yaml     # ALB + Auto Scaling Group (API)
├── 06-workers.yaml             # Instancias Worker (procesamiento de videos)
├── deploy.sh                   # Script de despliegue automatizado
├── cleanup.sh                  # Script de limpieza (elimina toda la infraestructura)
├── README.md                   # Este archivo
└── parameters.example.json     # Ejemplo de parámetros
```

## Prerequisitos

Para el uso del script de despliegue automatico, se requiere:

### 1. AWS CLI Instalado y Configurado

```bash
# Instalar AWS CLI (si no está instalado)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configurar credenciales
aws configure
```

### 2. Key Pair de EC2

Para uso de SSH y acceso a las instancias, se requiere un par de llaves (Key Pair), por lo cual se debe crear:

```bash
# Crear un nuevo Key Pair
aws ec2 create-key-pair \
  --key-name anb-keypair \
  --query 'KeyMaterial' \
  --output text > anb-keypair.pem

# Proteger el archivo
chmod 400 anb-keypair.pem
```

## Despliegue AWS

### Script Automatizado

Configurar las variables para despliegue

```bash
# Generar JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Generar DB password
DB_PASSWORD="MySecurePassword123!"

# Ejecutar script de despliegue
cd aws-deployment/
chmod +x deploy.sh
./deploy.sh anb-production anb-keypair "$DB_PASSWORD" "$JWT_SECRET"
```

El anterior script:
1. Verifica prerequisitos
2. Crea deployment package
3. Sube templates a S3
4. Despliega toda la infraestructura
5. Sube el código de la aplicación
6. Muestra información de acceso

**Tiempo estimado:** 10-15 minutos


## Post-Despliegue

### 1. Obtener Información del Stack

```bash
STACK_NAME="anb-production-master"

# Ver todos los outputs
aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs' \
  --output table

# Obtener URL de la aplicación
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

echo "Application URL: http://${ALB_DNS}"
```

### 2. Ejecutar Migraciones de Base de Datos

```bash
# Obtener endpoint de RDS
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
  --output text)

# Conectar y ejecutar migraciones
for file in ../../db/*.up.sql; do
  psql -h ${DB_ENDPOINT} -U postgres -d proyecto_1 -f "$file"
done
```

### 3. Verificar Servicios

```bash
# Health check
curl http://${ALB_DNS}/health

# API status
curl http://${ALB_DNS}/api/health

# Ver información de Redis EC2
REDIS_URL=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`RedisUrl`].OutputValue' \
  --output text)

REDIS_INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`RedisInstance`].OutputValue' \
  --output text)

echo "Redis Endpoint: ${REDIS_URL}"
echo "Redis Instance ID: ${REDIS_INSTANCE_ID}"

# Verificar estado de la instancia Redis
aws ec2 describe-instances \
  --instance-ids ${REDIS_INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].{State:State.Name,PrivateIP:PrivateIpAddress,Type:InstanceType}'

# SSH a Redis y verificar contenedor Docker
REDIS_PRIVATE_IP=$(echo ${REDIS_URL} | cut -d: -f1)
ssh -i anb-keypair.pem ec2-user@${REDIS_PRIVATE_IP} << 'ENDSSH'
  echo "=== Docker Redis Status ==="
  docker ps | grep redis
  echo ""
  echo "=== Redis Ping Test ==="
  docker exec redis redis-cli ping
  echo ""
  echo "=== Redis Info ==="
  docker exec redis redis-cli info server | head -20
ENDSSH

# Ver instancias en Auto Scaling Group
ASG_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`AutoScalingGroupName`].OutputValue' \
  --output text)

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --query 'AutoScalingGroups[0].Instances[].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}'
```

### 4. Ver Logs

```bash
# Logs de user-data de una instancia
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

aws ec2 get-console-output --instance-id ${INSTANCE_ID} --output text

# CloudWatch Logs
aws logs tail /aws/ec2/anb-api --follow
aws logs tail /aws/ec2/anb-worker --follow
```

## Monitoreo y Auto Scaling

### CloudWatch Alarms Creadas

1. **RDS:**
   - High CPU (>80%)
   - Low Storage (<2GB)
   - High Connections (>80)

2. **Redis EC2:**
   - High CPU (>80%)
   - Status Check Failed
   - Instance unreachable
   - Docker container health

3. **Auto Scaling Group:**
   - High CPU (>80%)
   - Unhealthy Hosts
   - High Response Time (>500ms)

4. **Workers:**
   - High CPU (>85%)
   - Status Check Failed

### Ver Métricas

```bash
# CPU del Auto Scaling Group
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=${ASG_NAME} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Número de instancias en el ASG
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]'

# Métricas de Redis EC2 Instance
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=${REDIS_INSTANCE_ID} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Verificar estado de Redis via SSH y redis-cli
ssh -i anb-keypair.pem ec2-user@${REDIS_PRIVATE_IP} << 'ENDSSH'
  docker exec redis redis-cli info stats | grep -E "total_connections|instantaneous_ops"
  docker exec redis redis-cli info memory | grep -E "used_memory_human|maxmemory_human"
  docker exec redis redis-cli dbsize
ENDSSH
```

### Forzar Scaling Manual

```bash
# Escalar a 3 instancias
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ${ASG_NAME} \
  --desired-capacity 3

# Volver a 1 instancia
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ${ASG_NAME} \
  --desired-capacity 1
```

## Actualización del Stack

### Actualizar Configuración

```bash
# Modificar parámetros (ej: cambiar DesiredCapacity)
aws cloudformation update-stack \
  --stack-name ${STACK_NAME} \
  --use-previous-template \
  --parameters \
    ParameterKey=EnvironmentName,UsePreviousValue=true \
    ParameterKey=KeyPairName,UsePreviousValue=true \
    ParameterKey=DBPassword,UsePreviousValue=true \
    ParameterKey=JWTSecret,UsePreviousValue=true \
    ParameterKey=DesiredCapacity,ParameterValue=2 \
  --capabilities CAPABILITY_IAM

# Esperar actualización
aws cloudformation wait stack-update-complete \
  --stack-name ${STACK_NAME}
```

### Actualizar Código de la Aplicación

```bash
# Crear nuevo deployment package
cd ../..
tar -czf app.tar.gz back/ front/ docker-compose.api.yml docker-compose.worker.yml

# Subir a S3
S3_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

aws s3 cp app.tar.gz s3://${S3_BUCKET}/deployments/latest/app.tar.gz

# Terminar instancias para que se recreen con el nuevo código
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name ${ASG_NAME}
```

## Limpieza y Eliminación

### Script Automatizado

Ejecutar el script para eliminar la infraestructura creada:

```bash
cd aws-deployment/
chmod +x cleanup.sh
./cleanup.sh anb-production
```

El anterior script:
- Vacía el bucket S3 (con opción de backup)
- Elimina el stack de CloudFormation
- Verifica recursos huérfanos
- Limpia volúmenes EBS no utilizados

## Referencias

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Auto Scaling Groups](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Amazon RDS for PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
