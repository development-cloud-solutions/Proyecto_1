# Proyecto 1: ANB Rising Stars

## Integrantes

Nombre | Correo |
---|---|
Jheisson Orlando Cabezas Vera | j.cabezasv@uniandes.edu.co        |
Diego Alberto Rodríguez Cruz  | da.rodriguezc123@uniandes.edu.co |

## Estructura del proyecto

```
Proyecto_1/
├── .gitignore
├── aws-deployment/
│   ├── .gitignore
│   ├── 00-master-stack.yaml
│   ├── 01-vpc-networking.yaml
│   ├── 02-s3-iam.yaml
│   ├── 03-elasticache.yaml
│   ├── 03-elasticache.yaml.backup
│   ├── 04-rds-database.yaml
│   ├── 05-alb-autoscaling.yaml
│   ├── 06-workers.yaml
│   ├── anb-keypair.pem
│   ├── cleanup.sh
│   ├── deploy copy.sh
│   ├── deploy.sh
│   ├── parameters.example.json
│   ├── README.md
├── back/
│   ├── .dockerignore
│   ├── .env.example
│   ├── artillery-config-simple.yml
│   ├── artillery-config-video.yml
│   ├── artillery-config.yml
│   ├── assets/
│   │   ├── anb_watermark.png
│   ├── cmd/
│   │   ├── api/
│   │   │   ├── main.go
│   │   ├── worker/
│   │   │   ├── main.go
│   ├── Dockerfile.api
│   ├── Dockerfile.worker
│   ├── docs/
│   │   ├── docs.go
│   │   ├── swagger.json
│   │   ├── swagger.yaml
│   ├── go.mod
│   ├── go.sum
│   ├── internal/
│   │   ├── api/
│   │   │   ├── handlers/
│   │   │   │   ├── auth.go
│   │   │   │   ├── rankings.go
│   │   │   │   ├── videos.go
│   │   │   ├── middleware/
│   │   │   │   ├── auth_middleware.go
│   │   │   ├── routes.go
│   │   ├── config/
│   │   │   ├── config.go
│   │   ├── database/
│   │   │   ├── connection.go
│   │   │   ├── models/
│   │   │   │   ├── models.go
│   │   ├── services/
│   │   │   ├── auth_service.go
│   │   │   ├── ranking_service.go
│   │   │   ├── storage/
│   │   │   │   ├── factory.go
│   │   │   │   ├── interface.go
│   │   │   │   ├── local_storage.go
│   │   │   │   ├── s3_storage.go
│   │   │   ├── video_service.go
│   │   ├── utils/
│   │   │   ├── jwt.go
│   │   │   ├── password.go
│   │   │   ├── video_processing.go
│   │   ├── workers/
│   │   │   ├── task_queue.go
│   │   │   ├── video_processor.go
│   ├── Makefile
│   ├── nginx/
│   │   ├── nginx.conf
│   ├── README.md
├── capacity-planning/
│   ├── Apache_Bench/
│   │   ├── ab_tests.sh
│   │   ├── load-test-results/
│   │   │   ├── Get_Profile_results.txt
│   │   │   ├── Get_Videos_results.txt
│   │   │   ├── health_100_users.txt
│   │   │   ├── health_10_users.txt
│   │   │   ├── health_200_users.txt
│   │   │   ├── health_50_users.txt
│   │   │   ├── Health_Check_results.txt
│   │   │   ├── login_data.json
│   │   │   ├── README.md
│   │   │   ├── register_data.json
│   │   │   ├── upload_data.txt
│   │   │   ├── User_Login_results.txt
│   │   │   ├── User_Registration_results.txt
│   ├── jmeter/
│   │   ├── anb_rising_stars_test.jmx
│   ├── README.md
├── collections/
│   ├── anb.json
│   ├── postman_environment.json
├── db/
│   ├── 001_create_users.down.sql
│   ├── 001_create_users.up.sql
│   ├── 002_create_videos.down.sql
│   ├── 002_create_videos.up.sql
│   ├── 003_create_votes.down.sql
│   ├── 003_create_votes.up.sql
│   ├── 004_create_task_results.down.sql
│   ├── 004_create_task_results.up.sql
│   ├── 005_create_user_sessions.down.sql
│   ├── 005_create_user_sessions.up.sql
│   ├── 006_create_views.down.sql
│   ├── 006_create_views.up.sql
│   ├── 007_create_triggers.down.sql
│   ├── 007_create_triggers.up.sql
├── docker-compose.api.yml
├── docker-compose.bd.yml
├── docker-compose.worker.yml
├── docker-compose.yml
├── docs/
│   ├── Entrega_1/
│   │   ├── ISIS4426_Entrega_1_Plan_Pruebas_Carga.pdf
│   │   ├── ISIS4426_Entrega_1_Req.pdf
│   ├── Entrega_2/
│   │   ├── 001_Proyecto-Entrega_2.pdf
│   │   ├── 002_Análisis_Capacidad.pdf
│   │   ├── ISIS4426_Entrega_2_Req.pdf
│   ├── Entrega_3/
│   │   ├── 001_ISIS4426_Entrega_3_Req.pdf
│   │   ├── 002_Proyecto_Entrega_3.pdf
│   │   ├── README.md
│   ├── Video/
│   │   ├── README.md
│   │   ├── Test_Video.mp4
├── front/
│   ├── .dockerignore
│   ├── .env.example
│   ├── .gitignore
│   ├── Dockerfile
│   ├── eslint.config.js
│   ├── index.html
│   ├── nginx.conf
│   ├── package-lock.json
│   ├── package.json
│   ├── postcss.config.js
│   ├── public/
│   │   ├── vite.svg
│   ├── README.md
│   ├── src/
│   │   ├── App.jsx
│   │   ├── index.css
│   │   ├── main.jsx
│   │   ├── services/
│   │   │   ├── api.js
│   ├── tailwind.config.js
│   ├── vite.config.js
├── load-test-reports/
│   ├── docker-stats-end-20251009-013832.txt
│   ├── docker-stats-start-20251009-013832.txt
│   ├── load-test-summary-20251009-013832.md
│   ├── simple-test-20251009-013832.log
├── README.md
├── sustentacion/
│   ├── Entrega_1/
│   │   ├── README.md
│   ├── Entrega_2/
│   │   ├── README.md
│   ├── Entrega_3/
│   │   ├── README.md
```


- La carpeta `back` contiene el código correspondiente a GO, con su respectivo `README.md`
- La carpeta `db` contiene el código SQL para la creación de objetos en la base de datos
- La carpeta `docs/Entrega_1` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
- La carpeta `docs/Entrega_2` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
- La carpeta `docs/Entrega_3` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
  - `docs\Entrega_2\001_Proyecto-Entrega_2.pdf` contiene la información del despliegue del proyecto en AWS
  - `docs\Entrega_2\002_Análisis_Capacidad.pdf` contiene la información correspondiente a las pruebas de carga realizadas.
  - `docs\Entrega_2\ISIS4426_Entrega_2_Req.pdf` documento de requerimientos para la entrega 2.
  - `docs\Entrega_2\ISIS4426_Entrega_3_Req.pdf` documento de requerimientos para la entrega 3.
- La carpeta `docs/Video` contiene un vídeo para pruebas tanto de carga como de uso en la API.
- La carpeta `front` contiene el código correspondiente a la interfaz gráfica desarrollada en React, con su respectivo `README.md`
- La carpeta `sustentacion` contiene el respectivo `README.md` en cada carpeta de entrega con el respectivo enlace del video de demostración.
  - `sustentacion\Entrega_1\README.md` contiene el link de sustenación al video de la entrega 1.
  - `sustentacion\Entrega_2\README.md` contiene el link de sustenación al video de la entrega 2.
  - `sustentacion\Entrega_2\README.md` contiene el link de sustenación al video de la entrega 3.

## Ejecución del proyecto

En una ventana de comandos/terminal:

1. Clonar el repositorio: Primero, asegúrese de tener git instalado en su máquina. Luego, clone el repositorio en su entorno local:
```bash
git clone https://github.com/development-cloud-solutions/Proyecto_1.git
```

2. Ingrese a la carpeta donde clono el respositorio
```bash
cd Proyecto_1
```

> Configurar el archivo `.env` con las variables de entornor según corresponda:
   ```bash
   cp back/.env.example back/.env
   ```

3. Ejecutar el docker compose para el despligue de la aplicación web
```bash
docker compose -f docker-compose.local.yml up -d
```

4. Una vez iniciado y culminado el despliegue, se presentara una salida similar a la siguiente:
```bash
[+] Running 14/14
 ✔ proyecto_1-api                     Built                   0.0s 
 ✔ proyecto_1-frontend                Built                   0.0s 
 ✔ proyecto_1-worker1                 Built                   0.0s 
 ✔ Network proyecto_1_anb_network     Created                 0.5s 
 ✔ Volume proyecto_1_postgres_data    Created                 0.3s 
 ✔ Volume proyecto_1_redis_data       Created                 0.1s 
 ✔ Volume proyecto_1_video_uploads    Created                 0.1s 
 ✔ Volume proyecto_1_video_processed  Created                 0.1s 
 ✔ Container anb_redis                Healthy                15.1s 
 ✔ Container anb_postgres             Healthy                26.1s 
 ✔ Container anb_worker_1             Started                25.7s 
 ✔ Container anb_api                  Started                26.1s 
 ✔ Container anb_frontend             Started                27.2s 
 ✔ Container anb_nginx                Started                31.0s
```

5. Con los servicios iniciados, proceda a ingresar a la aplicación web mediante la URL: http://localhost:3000/


## Uso de apliación

- En la carpeta `collections/` puede encontrar:
  - Archivo JSON de variables de entorno `postman_environment.json`
  - Archivo JSON de pruebas en postman `anb.json`


# Entrega 2 :: Despliegue en AWS

> Para la Entrega 2, se realizo el uso de AWS mediante servicios de EC2, en los cuales se desplegaron los servicios de la aplicación.

Con el fin de crear los objetos necesarios en EC2, se segmento el docker compose en archivos separados:
- Para la base de datos, se creo el archivo `docker-compose.bd.yml` con la creación de objetos para el funcionamiento de la aplicación.
```
docker compose -f docker-compose.bd.yml --env-file back/.env up -d
```

- Para el despliegue del backend, se creo el archivo `docker-compose.api.yml` con la información y objetos necesarios para la misma.
```
docker compose -f docker-compose.api.yml --env-file back/.env up -d
```

- Para el despligue del worker, se creo el archivo `docker-compose.worker.yml` con los recursos respectivos para la ejecución de este.
```
docker compose -f docker-compose.worker.yml --env-file back/.env up -d
```

# Entrega 3 :: Despliegue en AWS

> Para la entrega 3, se realizo el uso de servicios de AWS como EC2, ALB, RDS, S3.

Con el fin de facilitar el despliegue se creo un script automatizado en `CloudFormation`, con el cual se crean los servicios necesarios para el despliegue.

**NOTA** Se debe tener instalado AWS CLI en la máquina de despliegue

- Generar la llave para conexión
```bash
# Crear un nuevo Key Pair
aws ec2 create-key-pair \
  --key-name anb-keypair \
  --query 'KeyMaterial' \
  --output text > anb-keypair.pem

# Proteger el archivo
chmod 400 anb-keypair.pem
```

> Si al generar la anterior llave se presenta un mensaje como el siguiente: `An error occurred (InvalidKeyPair.Duplicate) when calling the CreateKeyPair operation: The keypair already exists`, se debe eliminar la llave previa o cambiar el nombre de la llave a utilizar.
```bash 
# Verificar las llaves existentes
aws ec2 describe-key-pairs --query "KeyPairs[*].KeyName"

# eliminar llave existente
aws ec2 delete-key-pair --key-name anb-keypair
```

- Generar password
```bash
# Generar JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Generar DB password (Modificar para producción)
DB_PASSWORD="MySecurePassword123!"
```

- Ejecutar desde la raíz del proyecto `Proyecto_1`:
```bash
./aws-deployment/deploy.sh anb-production anb-keypair "$DB_PASSWORD" "$JWT_SECRET"
```

Al finalizar el despligue se debe presentar un mensaje similar al siguiente:
```bash
[INFO] Desplegando CloudFormation stack: anb-production-master
[INFO] Stack Name: anb-production-master
[INFO] Templates Bucket: anb-cf-templates-xxxxx-us-east-1
[INFO] Region: us-east-1
[INFO] Creando nuevo stack...
{
    "StackId": "arn:aws:cloudformation:us-east-1:xxxxx:stack/anb-production-master/xxxxx-af18-11f0-b155-xxxxx"
}
[INFO] Esperando a que el stack se cree (esto puede tomar 10-15 minutos)...
[SUCCESS] Stack desplegado exitosamente!

[INFO] Obteniendo información del stack...
[INFO] Verificando estado del Auto Scaling Group...
[INFO] Instancias en ASG: 1/1 healthy
[SUCCESS] ✓ Instancias healthy: 1/1
[INFO] Para ejecutar las migraciones de base de datos, conéctate a RDS y ejecuta:
[INFO] Endpoint: anb-production-postgres.xxxxx.us-east-1.rds.amazonaws.com
[INFO] Database: proyecto_1
[INFO] User: postgres
[INFO]
[INFO] Comando:
[INFO]   for file in db/*.up.sql; do
[INFO]     psql -h anb-production-postgres.xxxxx.us-east-1.rds.amazonaws.com -U postgres -d proyecto_1 -f "$file"
[INFO]   done


==========================================
[SUCCESS] DESPLIEGUE COMPLETADO
==========================================

[INFO] Stack Name: anb-production-master
[INFO] S3 Bucket: anb-videos-xxxxx-us-east-1
[INFO] Application URL: http://anb-production-alb-xxxxx.us-east-1.elb.amazonaws.com
[INFO] Database Endpoint: anb-production-postgres.xxxxx.us-east-1.rds.amazonaws.com

```

Una vez la infraestructura se ha desplegado correctamente se evidencia en el log, el acceso a las diferentes URL. Ingresar a la máquina EC2 del API y ejecutar (cuando se solicite el password de la base de datos es la configurada en el paso anterior en la variable `DB_PASSWORD`)
```bash
# EC2 - Ingresar a la carpeta de la aplicacíón
cd /opt/anb-app/

# Ejecutar la instalación de scripts en RDS, reemplazar URL_RDS por la conexión a BD
for file in db/*.up.sql; do
  psql -h anb-production-postgres.xxxx.us-east-1.rds.amazonaws.com -U postgres -d proyecto_1 -f "$file"
done
```

- Para la eliminación de la infraestructura creada ejecutar, desde la raíz del proyecto `Proyecto_1` 
```bash
./aws-deployment/cleanup.sh anb-production
```

> Para más información sobre el despliegue automatica remitirse al `README.md` de la carpeta `aws-deployment`

# Entrega 4 :: Escalabilidad capa worker

> Ejecutar los mismos pasos de la [Entrega 3](#entrega-3--despliegue-en-aws) con el fin de desplegar los servicios de la presente entrega

# Sustentación

Vídeos de sustentación
- Entrega 1 => `sustentacion\Entrega_1\README.md`
- Entrega 2 => `sustentacion\Entrega_2\README.md`
- Entrega 3 => `sustentacion\Entrega_3\README.md`
- Entrega 4 => `sustentacion\Entrega_4\README.md`