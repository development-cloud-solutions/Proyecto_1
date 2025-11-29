# ANB Rising Stars - Infraestructura con Terraform

Esta configuración de Terraform es equivalente al stack de CloudFormation en `aws-deployment/`.

## Requisitos Previos

### 1. Instalar Terraform

**Windows (con Chocolatey):**
```powershell
choco install terraform
```

**Windows (con Scoop):**
```powershell
scoop install terraform
```

**Windows (manual):**
1. Descargar desde: https://developer.hashicorp.com/terraform/downloads
2. Extraer el archivo zip en una carpeta (ej: `C:\terraform`)
3. Agregar la carpeta anterior al PATH del sistema:
   - Buscar "Variables de entorno" en Windows
   - Editar la variable `Path` del sistema
   - Agregar la ruta donde está `terraform.exe`

**Mac:**
```bash
brew install terraform
```

**Linux(Debian/Ubuntu/Mint):**
```bash
# Install dependencies.
sudo apt-get update
sudo apt-get install -y software-properties-common gnupg2 curl

# Add HashiCorp GPG key.
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository.
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install Terraform.
sudo apt-get update
sudo apt-get install -y terraform
```

**Linux(RHEL/CentOS):**
```bash
# Install dependencies.
sudo yum install -y yum-utils

# Add HashiCorp repository
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Install Terraform.
sudo yum install -y terraform
```

**Verificar instalación:**
```bash
terraform version
```

### 2. Instalar AWS CLI

Descargar e instalar desde: https://aws.amazon.com/cli/

**Verificar instalación:**
```bash
aws --version
```

### 3. Configurar Credenciales AWS

**Opción A - AWS Configure (recomendado):**
```bash
aws configure
```
Diligenciar los parámetros solicitados:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (ej: `us-east-1`)
- Default output format (dejar en blanco o `json`)

**Opción B - Variables de entorno:**
```bash
export AWS_ACCESS_KEY_ID="tu-access-key"
export AWS_SECRET_ACCESS_KEY="tu-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 4. Crear Key Pair en AWS

- Verificar si existe el Key pair
```bash
# Verificar que existe el key pair
aws ec2 describe-key-pairs --key-names anb-keypair --region us-east-1
```

- Si no existe, crearlo:
```bash
# Crear el key pair
aws ec2 create-key-pair \
  --key-name anb-keypair \
  --query 'KeyMaterial' \
  --output text > anb-keypair.pem

# Establecer permisos (Linux/Mac)
chmod 400 anb-keypair.pem

```

## Despliegue automático 

Para el despliegue, se debe estar en la raíz del proyecto `Proyecto_1`

- Generar variables de password:
```bash
# Generar JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Generar DB password (Modificar para producción)
DB_PASSWORD="MySecurePassword123!"
```

- Asignar permisos de ejecución a los archivos:
```bash
# Dar permisos de ejecución (Linux/Mac)
chmod +x ./aws-terraform/deploy.sh ./aws-terraform/cleanup.sh
```

- Para el despliegue de Terraform en AWS, se ha creado el script `deploy.sh`, el cual automatiza todo el proceso:
```bash
# Ejecutar despliegue
./aws-terraform/deploy.sh anb-production anb-keypair "$DB_PASSWORD" "$JWT_SECRET"
```

## Estructura de archivos de Terraform

```
aws-terraform/
├── main.tf                    # Orquestador principal
├── variables.tf               # Definición de variables
├── outputs.tf                 # Outputs del stack
├── terraform.tfvars.example   # Ejemplo de configuración
├── deploy.sh                  # Script de despliegue automático
├── cleanup.sh                 # Script de limpieza
├── README.md                  # Esta documentación
└── modules/
    ├── vpc/                   # Red y seguridad
    ├── s3-iam/                # Almacenamiento y logs
    ├── sqs/                   # Cola de mensajes
    ├── rds/                   # Base de datos PostgreSQL
    ├── alb-autoscaling/       # API y Load Balancer
    └── workers/               # Procesamiento de videos
```

## Arquitectura

```
                    ┌─────────────────────────────────────────────────┐
                    │                     VPC                         │
                    │  ┌─────────────┐         ┌─────────────┐        │
Internet ──────────►│  │   ALB       │         │   SQS       │        │
                    │  │  (HTTP:80)  │         │   Queue     │        │
                    │  └──────┬──────┘         └──────┬──────┘        │
                    │         │                       │               │
                    │  ┌──────▼──────┐         ┌──────▼──────┐        │
                    │  │  API ASG    │         │ Worker ASG  │        │
                    │  │  (EC2)      │────────►│   (EC2)     │        │
                    │  └──────┬──────┘         └──────┬──────┘        │
                    │         │                       │               │
                    │         └───────────┬───────────┘               │
                    │                     │                           │
                    │              ┌──────▼──────┐                    │
                    │              │     RDS     │                    │
                    │              │ (PostgreSQL)│                    │
                    │              └─────────────┘                    │
                    └─────────────────────────────────────────────────┘
                                          │
                                   ┌──────▼──────┐
                                   │     S3      │
                                   │  (Videos)   │
                                   └─────────────┘
```

## Comandos Útiles

```bash
# Ver estado actual
terraform show

# Ver solo outputs
terraform output

# Ver un output específico
terraform output load_balancer_dns

# Actualizar infraestructura (después de cambiar tfvars)
terraform apply
```


## Destrucción de ambiente

Para eliminar los servicios creados, ejecutar
```bash
# Destruir todo
./aws-terraform/cleanup.sh anb-production
```