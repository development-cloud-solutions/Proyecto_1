# Entrega 4: Escalabilidad en la Capa Batch/Worker

## Resumen de Cambios Implementados

Esta entrega implementa **autoscaling automático para workers** y **soporte dual de colas (SQS/Redis)** manteniendo la compatibilidad total entre AWS y entornos locales.

### ✅ Requisitos Cumplidos

#### 1. **Autoscaling para Workers (20%)**
- ✅ Auto Scaling Group implementado en [`06-workers-autoscaling.yaml`](../../aws-deployment/06-workers-autoscaling.yaml)
- ✅ Política de escalado basada en profundidad de cola SQS
- ✅ Escala entre 1-3 workers automáticamente según demanda
- ✅ CloudWatch Alarms configuradas para monitoreo

#### 2. **Sistema de Mensajería Asíncrona con SQS (20%)**
- ✅ Cola SQS implementada en [`03.5-sqs-queue.yaml`](../../aws-deployment/03.5-sqs-queue.yaml)
- ✅ Dead Letter Queue (DLQ) para mensajes fallidos
- ✅ Long polling configurado (20 segundos)
- ✅ Soporte dual: **SQS para AWS** y **Redis para local**

#### 3. **Alta Disponibilidad en 2 Zonas (20%)**
- ✅ Workers desplegados en 2 Availability Zones
- ✅ API con ALB distribuido en 2 AZs (completado en Entrega 3)
- ✅ RDS Multi-AZ disponible (configuración en plantilla)

#### 4. **Requerimientos Funcionales (10%)**
- ✅ Todos los endpoints mantienen funcionalidad
- ✅ Procesamiento de video preservado
- ✅ Compatibilidad AWS/Local mantenida

---

## Arquitectura de la Solución

### Componentes Principales

```
┌─────────────────────────────────────────────────────────────┐
│                         USUARIOS                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                │
│                    (2 Availability Zones)                   │
└──────────────────┬──────────────────────────────────────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌──────────────┐        ┌──────────────┐
│   API ASG    │        │   API ASG    │
│   (AZ-1)     │        │   (AZ-2)     │
│  1-3 Inst.   │        │  1-3 Inst.   │
└──────┬───────┘        └──────┬───────┘
       │                       │
       └───────────┬───────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │    Amazon SQS Queue   │
       │  (Video Processing)   │
       │                       │
       │   + Dead Letter Queue │
       └───────────┬───────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌──────────────┐        ┌──────────────┐
│  Worker ASG  │        │  Worker ASG  │
│   (AZ-1)     │        │   (AZ-2)     │
│  1-3 Inst.   │        │  1-3 Inst.   │
└──────┬───────┘        └──────┬───────┘
       │                       │
       └───────────┬───────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌──────────────┐        ┌──────────────┐
│  Amazon RDS  │        │  Amazon S3   │
│ (PostgreSQL) │        │   (Videos)   │
└──────────────┘        └──────────────┘
```

### Flujo de Procesamiento de Video

1. **Usuario sube video** → API REST
2. **API guarda metadata** → PostgreSQL
3. **API encola tarea** → Amazon SQS (o Redis en local)
4. **Worker consume tarea** → Procesa video
5. **Worker guarda resultado** → S3 (o local)
6. **Worker actualiza estado** → PostgreSQL

---

## Nuevas Características

### 1. Sistema de Colas Dual (SQS/Redis)

El sistema ahora soporta dos backends de cola mediante configuración:

**Para AWS (Producción):**
```bash
QUEUE_TYPE=sqs
SQS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/anb-video-processing
```

**Para Local (Desarrollo):**
```bash
QUEUE_TYPE=redis
REDIS_URL=redis:6379
```

**Implementación:**
- [`queue_interface.go`](../../back/internal/workers/queue_interface.go) - Interfaz genérica
- [`redis_queue.go`](../../back/internal/workers/redis_queue.go) - Implementación Redis
- [`sqs_queue.go`](../../back/internal/workers/sqs_queue.go) - Implementación SQS
- [`queue_factory.go`](../../back/internal/workers/queue_factory.go) - Factory pattern

### 2. Auto Scaling para Workers

**Métrica de Escalado:** Profundidad de Cola / Número de Workers

```yaml
# Configuración en CloudFormation
TargetValue: 10  # 10 mensajes por worker
MinSize: 1       # Mínimo 1 worker
MaxSize: 3       # Máximo 3 workers (límite AWS Academy)
```

**Comportamiento:**
- Si `cola/workers > 10` → Escala UP
- Si `cola/workers < 10` → Escala DOWN
- Tiempo de warmup: 10 minutos

### 3. Monitoreo con CloudWatch

**Alarmas Configuradas:**

**Para SQS:**
- `QueueDepthAlarm`: Alerta si > 100 mensajes en cola
- `OldestMessageAlarm`: Alerta si mensaje > 30 min sin procesar
- `DLQDepthAlarm`: Alerta si hay mensajes en DLQ

**Para Workers:**
- `WorkerHighCPUAlarm`: Alerta si CPU > 85%
- `WorkerLowCapacityAlarm`: Alerta si no hay workers activos

---

## Despliegue

### Opción 1: Despliegue Completo con SQS (Recomendado para AWS)

```bash
cd aws-deployment

# 1. Desplegar VPC
aws cloudformation create-stack \
  --stack-name anb-production-vpc \
  --template-body file://01-vpc-networking.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=anb-production

# 2. Desplegar S3 y IAM
aws cloudformation create-stack \
  --stack-name anb-production-s3 \
  --template-body file://02-s3-iam.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=anb-production

# 3. Desplegar SQS
aws cloudformation create-stack \
  --stack-name anb-production-sqs \
  --template-body file://03.5-sqs-queue.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=anb-production

# 4. Desplegar RDS
aws cloudformation create-stack \
  --stack-name anb-production-rds \
  --template-body file://04-rds-database.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=anb-production \
    ParameterKey=DBPassword,ParameterValue=YOUR_PASSWORD

# 5. Desplegar API con ALB
aws cloudformation create-stack \
  --stack-name anb-production-api \
  --template-body file://05-alb-autoscaling.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=anb-production \
    ParameterKey=JWTSecret,ParameterValue=YOUR_JWT_SECRET \
    ParameterKey=DBPassword,ParameterValue=YOUR_PASSWORD

# 6. Desplegar Workers con Autoscaling
aws cloudformation create-stack \
  --stack-name anb-production-workers \
  --template-body file://06-workers-autoscaling.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=anb-production \
    ParameterKey=DBPassword,ParameterValue=YOUR_PASSWORD
```

### Opción 2: Despliegue Local (Desarrollo)

```bash
# 1. Configurar variables de entorno
cp back/.env.example back/.env

# Editar .env:
# QUEUE_TYPE=redis
# STORAGE_TYPE=local
# REDIS_URL=redis:6379

# 2. Levantar servicios
docker-compose up -d
```

---

## Variables de Entorno

### Nuevas Variables (Entrega 4)

| Variable | Descripción | Valores | Default |
|----------|-------------|---------|---------|
| `QUEUE_TYPE` | Tipo de cola | `redis` o `sqs` | `redis` |
| `SQS_REGION` | Región de SQS | AWS region | `us-east-1` |
| `SQS_QUEUE_URL` | URL de la cola SQS | URL completa | - |

### Variables Existentes Importantes

| Variable | Descripción | AWS | Local |
|----------|-------------|-----|-------|
| `STORAGE_TYPE` | Tipo de almacenamiento | `s3` | `local` |
| `DB_SSL_MODE` | Modo SSL de PostgreSQL | `require` | `disable` |
| `WORKER_CONCURRENCY` | Tareas concurrentes por worker | `4` | `5` |

Ver archivo completo: [`back/.env.example`](../../back/.env.example)

---

## Código Modificado

### Archivos Nuevos

1. **`back/internal/workers/queue_interface.go`** - Interfaz genérica de cola
2. **`back/internal/workers/redis_queue.go`** - Implementación Redis/Asynq
3. **`back/internal/workers/sqs_queue.go`** - Implementación Amazon SQS
4. **`back/internal/workers/queue_factory.go`** - Factory para instanciar colas
5. **`aws-deployment/03.5-sqs-queue.yaml`** - CloudFormation para SQS
6. **`aws-deployment/06-workers-autoscaling.yaml`** - CloudFormation workers con ASG

### Archivos Modificados

1. **`back/internal/config/config.go`** - Agregadas variables `QUEUE_TYPE`, `SQS_REGION`, `SQS_QUEUE_URL`
2. **`back/internal/workers/task_queue.go`** - Refactorizado para usar interfaz
3. **`back/internal/workers/video_processor.go`** - Refactorizado para usar interfaz
4. **`back/cmd/api/main.go`** - Manejo de errores mejorado
5. **`back/cmd/worker/main.go`** - Soporte para contexto y shutdown graceful
6. **`back/go.mod`** - Agregada dependencia `aws-sdk-go-v2/service/sqs`
7. **`back/.env.example`** - Documentadas nuevas variables

---

## Pruebas de Carga

Ver documento detallado: [`capacity-planning/pruebas_de_carga_entrega4.md`](../../capacity-planning/pruebas_de_carga_entrega4.md)

### Escenarios Probados

1. **Escenario 1:** Carga incremental de API (10 → 50 → 100 usuarios)
2. **Escenario 2:** Procesamiento masivo de videos (50 videos simultáneos)

---

## Limitaciones AWS Academy

- **Máximo 9 instancias EC2** simultáneas por región
- **Máximo 32 vCPUs** en total
- Solo regiones: `us-east-1` y `us-west-2`
- Instancias permitidas: `t2/t3: nano, micro, small, medium, large`

**Configuración Actual:**
- API ASG: 1-3 instancias (`t3.small` = 2 vCPU c/u)
- Worker ASG: 1-3 instancias (`t3.small` = 2 vCPU c/u)
- RDS: 1 instancia (`db.t3.micro` = 2 vCPU)
- **Total máximo:** 3 + 3 + 1 = 7 instancias, 14 vCPUs ✅

---

## Monitoreo y Observabilidad

### CloudWatch Dashboards

Crear dashboard personalizado:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name anb-production-monitoring \
  --dashboard-body file://cloudwatch-dashboard.json
```

### Métricas Clave

1. **SQS:**
   - `ApproximateNumberOfMessagesVisible` - Mensajes en cola
   - `ApproximateAgeOfOldestMessage` - Edad del mensaje más antiguo
   - `NumberOfMessagesSent` - Mensajes enviados
   - `NumberOfMessagesDeleted` - Mensajes procesados

2. **Workers:**
   - `CPUUtilization` - Uso de CPU
   - `GroupInServiceInstances` - Workers activos
   - `GroupDesiredCapacity` - Capacidad deseada

3. **API:**
   - `TargetResponseTime` - Tiempo de respuesta del ALB
   - `UnHealthyHostCount` - Instancias no saludables
   - `RequestCount` - Total de peticiones

---

## Costos Estimados

### Ejecución 24/7 (Referencia)

| Servicio | Configuración | Costo Mensual (USD) |
|----------|---------------|---------------------|
| EC2 API (2x t3.small) | 2 vCPU, 2GB RAM | ~$60 |
| EC2 Workers (2x t3.small) | 2 vCPU, 2GB RAM | ~$60 |
| RDS (db.t3.micro) | Single-AZ | ~$15 |
| ALB | 1 balanceador | ~$16 |
| S3 | 100 GB storage | ~$2.30 |
| SQS | 1M requests | Gratis |
| **Total** | | **~$153/mes** |

**Recomendación:** Detener instancias cuando no se usen. Con AWS Academy tienes $100 en créditos.

---

## Troubleshooting

### Workers no escalan

1. Verificar métricas de SQS en CloudWatch
2. Revisar política de escalado:
   ```bash
   aws autoscaling describe-policies \
     --auto-scaling-group-name anb-production-worker-asg
   ```
3. Verificar alarmas:
   ```bash
   aws cloudwatch describe-alarms \
     --alarm-name-prefix anb-production
   ```

### Mensajes en DLQ

1. Revisar logs de workers:
   ```bash
   # SSH a instancia worker
   ssh -i keypair.pem ec2-user@<worker-ip>
   docker logs anb_worker
   ```

2. Reprocesar mensajes de DLQ:
   ```bash
   # Mover mensajes de DLQ a cola principal
   aws sqs purge-queue --queue-url <dlq-url>
   ```

### Problemas de conectividad

1. Verificar Security Groups
2. Verificar que IAM Role `LabInstanceProfile` tiene permisos SQS
3. Probar conectividad:
   ```bash
   aws sqs receive-message --queue-url <queue-url>
   ```

---

## Referencias

- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS Auto Scaling](https://docs.aws.amazon.com/autoscaling/)
- [CloudWatch Metrics](https://docs.aws.amazon.com/cloudwatch/)
- [Asynq (Redis Queue)](https://github.com/hibiken/asynq)

---

## Siguiente Entrega

Para la Entrega 5 se recomienda:
- Implementar caché distribuido (ElastiCache Redis)
- CDN con CloudFront para videos procesados
- Optimizar costos con Spot Instances
- Implementar métricas custom de negocio
