# CloudFormation Templates - ANB Rising Stars

Despliegue automatizado de toda la infraestructura en AWS usando AWS CloudFormation.

## Descripción General

Este directorio contiene plantillas de CloudFormation para desplegar automáticamente toda la arquitectura de ANB Rising Stars en AWS con Auto Scaling, incluyendo:

- VPC con subnets públicas y privadas en múltiples AZs
- Application Load Balancer (ALB)
- Auto Scaling Group para instancias API (min: 1, max: 3)
- Amazon RDS PostgreSQL 15
- Amazon S3 para almacenamiento de videos
- Instancias Worker para procesamiento de videos
- IAM Roles y Security Groups
- CloudWatch Alarms y Logs

## Arquitectura Desplegada

```
┌─────────────────────────────────────────┐
│          Internet Gateway               │
└─────────────┬───────────────────────────┘
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
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     └───────────┼───────────┘
                 │
                 ▼
     ┌───────────────────────┐
     │ RDS PostgreSQL 15     │
     │ (db.t3.micro)         │
     └───────────────────────┘
                 │
                 ▼
     ┌───────────────────────┐
     │ S3 Bucket             │
     │ ├─ uploads/           │
     │ └─ processed/         │
     └───────────────────────┘
                 ▲
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
   ┌─────────┐       ┌─────────┐
   │Worker #1│       │Worker #2│
   │t3.small │       │t3.small │
   └─────────┘       └─────────┘
```

## Estructura de Archivos

```
cloudformation/
├── 00-master-stack.yaml      # Stack maestro (orquesta todo)
├── 01-vpc-networking.yaml    # VPC, subnets, security groups
├── 02-rds-database.yaml      # RDS PostgreSQL
├── 03-s3-iam.yaml            # S3 bucket y roles IAM
├── 04-alb-autoscaling.yaml   # ALB y Auto Scaling Group
├── 05-workers.yaml           # Instancias Worker
├── deploy.sh                 # Script de despliegue automatizado
├── cleanup.sh                # Script de limpieza
└── README.md                 # Este archivo
```

## Prerequisitos

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

Necesitas un Key Pair para acceso SSH a las instancias:

```bash
# Crear un nuevo Key Pair
aws ec2 create-key-pair \
  --key-name anb-keypair \
  --query 'KeyMaterial' \
  --output text > anb-keypair.pem

# Proteger el archivo
chmod 400 anb-keypair.pem
```

### 3. Herramientas Adicionales (Opcional)

```bash
# jq - para parsear JSON
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # Amazon Linux

# openssl - para generar secrets
# Ya viene instalado en la mayoría de sistemas
```

## Despliegue Rápido

### Opción 1: Script Automatizado (Recomendado)

```bash
# Generar JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Generar DB password
DB_PASSWORD="MySecurePassword123!"

# Ejecutar script de despliegue
cd aws-deployment/cloudformation
chmod +x deploy.sh
./deploy.sh anb-production anb-keypair "$DB_PASSWORD" "$JWT_SECRET"
```

El script:
1. ✅ Verifica prerequisitos
2. ✅ Crea deployment package
3. ✅ Sube templates a S3
4. ✅ Despliega toda la infraestructura
5. ✅ Sube el código de la aplicación
6. ✅ Muestra información de acceso

**Tiempo estimado:** 10-15 minutos

### Opción 2: Despliegue Manual con AWS Console

1. **Subir templates a S3:**

```bash
# Crear bucket
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://anb-cf-templates-${AWS_ACCOUNT_ID}

# Subir templates
aws s3 sync . s3://anb-cf-templates-${AWS_ACCOUNT_ID}/cloudformation/
```

2. **Ir a AWS CloudFormation Console:**
   - https://console.aws.amazon.com/cloudformation

3. **Create Stack:**
   - Template: Upload `00-master-stack.yaml`
   - Stack name: `anb-production-master`
   - Completar parámetros requeridos

4. **Esperar a que se complete** (~10-15 minutos)

### Opción 3: Despliegue Manual con AWS CLI

```bash
# Preparar parámetros
cat > parameters.json << EOF
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "anb-production"
  },
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "anb-keypair"
  },
  {
    "ParameterKey": "DBPassword",
    "ParameterValue": "YourSecurePassword123!"
  },
  {
    "ParameterKey": "JWTSecret",
    "ParameterValue": "$(openssl rand -hex 32)"
  }
]
EOF

# Crear stack
aws cloudformation create-stack \
  --stack-name anb-production-master \
  --template-body file://00-master-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Monitorear progreso
aws cloudformation wait stack-create-complete \
  --stack-name anb-production-master

# Ver outputs
aws cloudformation describe-stacks \
  --stack-name anb-production-master \
  --query 'Stacks[0].Outputs'
```

## Parámetros de Configuración

### Parámetros Requeridos

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `EnvironmentName` | Nombre del ambiente | `anb-production` |
| `KeyPairName` | Key Pair de EC2 | `anb-keypair` |
| `DBPassword` | Contraseña de RDS | `MySecurePass123!` |
| `JWTSecret` | Secret para JWT | `openssl rand -hex 32` |

### Parámetros Opcionales

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| `DBInstanceClass` | `db.t3.micro` | Tipo de instancia RDS |
| `APIInstanceType` | `t3.small` | Tipo de instancia API |
| `WorkerInstanceType` | `t3.small` | Tipo de instancia Worker |
| `MinSize` | `1` | Mínimo de instancias en ASG |
| `MaxSize` | `3` | Máximo de instancias en ASG |
| `DesiredCapacity` | `1` | Capacidad deseada en ASG |
| `CPUTargetValue` | `70` | CPU objetivo para auto scaling (%) |
| `NumberOfWorkers` | `1` | Número de workers (1-3) |
| `WorkerConcurrency` | `4` | Tareas concurrentes por worker |

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

2. **Auto Scaling Group:**
   - High CPU (>80%)
   - Unhealthy Hosts
   - High Response Time (>500ms)

3. **Workers:**
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

### Opción 1: Script Automatizado

```bash
cd aws-deployment/cloudformation
chmod +x cleanup.sh
./cleanup.sh anb-production
```

El script:
- ✅ Vacía el bucket S3 (con opción de backup)
- ✅ Elimina el stack de CloudFormation
- ✅ Verifica recursos huérfanos
- ✅ Limpia volúmenes EBS no utilizados

### Opción 2: Manual

```bash
STACK_NAME="anb-production-master"

# 1. Vaciar bucket S3
S3_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

aws s3 rm s3://${S3_BUCKET} --recursive

# 2. Eliminar stack
aws cloudformation delete-stack --stack-name ${STACK_NAME}

# 3. Esperar eliminación
aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}
```

## Troubleshooting

### Stack en estado CREATE_FAILED

```bash
# Ver eventos del stack
aws cloudformation describe-stack-events \
  --stack-name ${STACK_NAME} \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'

# Eliminar stack fallido
aws cloudformation delete-stack --stack-name ${STACK_NAME}
```

### Instancias no pasan Health Check

```bash
# Ver logs de user-data
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

aws ec2 get-console-output --instance-id ${INSTANCE_ID} --output text

# Conectar via SSH para debugging
ssh -i anb-keypair.pem ec2-user@<INSTANCE_PUBLIC_IP>

# Ver logs de Docker
sudo docker-compose -f /opt/anb-app/docker-compose.api.yml logs
```

### RDS Connection Issues

```bash
# Verificar security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=anb-production-rds-sg" \
  --query 'SecurityGroups[0].IpPermissions'

# Test de conexión desde instancia API
ssh -i anb-keypair.pem ec2-user@<API_INSTANCE_IP>
telnet ${DB_ENDPOINT} 5432
```

## Costos Estimados

Configuración por defecto (us-east-1):

| Recurso | Tipo | Cantidad | Costo/mes |
|---------|------|----------|-----------|
| EC2 API | t3.small | 1-3 | $15-45 |
| EC2 Worker | t3.small | 1 | $15 |
| RDS | db.t3.micro | 1 | $15 |
| ALB | - | 1 | $16 |
| S3 | Standard | Variable | $1-5 |
| **Total** | | | **~$62-96/mes** |

**IMPORTANTE:** Para evitar costos, elimina todos los recursos cuando no los uses:
```bash
./cleanup.sh anb-production
```

## Referencias

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Auto Scaling Groups](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Amazon RDS for PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)

## Soporte

Para problemas o preguntas:
1. Revisa la sección de Troubleshooting arriba
2. Verifica los logs de CloudWatch
3. Consulta la documentación en `docs/Entrega_3/`
4. Revisa el archivo `aws-deployment/README.md`
