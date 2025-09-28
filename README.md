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
├── back/
│   ├── .dockerignore
│   ├── .env.example
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
│   │   │   │   ├── interface.go
│   │   │   │   ├── local_storage.go
│   │   │   ├── video_service.go
│   │   ├── utils/
│   │   │   ├── jwt.go
│   │   │   ├── password.go
│   │   │   ├── video_processing.go
│   │   ├── workers/
│   │   │   ├── task_queue.go
│   │   │   ├── video_processor.go
│   ├── nginx/
│   │   ├── nginx.conf
│   ├── README.md
│   ├── scripts/
│   │   ├── generate-report.js
│   │   ├── load-test-data.csv
│   │   ├── load-test.sh
│   │   ├── newman-tests.sh
│   │   ├── processor.js
│   │   ├── README.md
│   │   ├── view-results.sh
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
├── CLAUDE.md
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
├── docker-compose.yml
├── docs/
│   ├── Entrega_1/
│   │   ├── ISIS4426_Entrega_1_Plan_Pruebas_Carga.pdf
│   │   ├── ISIS4426_Entrega_1_Req.pdf
│   ├── Entrega_2/
│   │   ├── ISIS4426_Entrega_2_Req.pdf
│   ├── Video/
│   │   ├── README.md
│   │   ├── Test_Video.mp4
├── front/
│   ├── .env.example
│   ├── .gitignore
│   ├── dist/
│   │   ├── assets/
│   │   │   ├── index-7KedNVM0.css
│   │   │   ├── index-DrXsQoys.js
│   │   ├── index.html
│   │   ├── vite.svg
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
├── README.md
├── sustentacion/
│   ├── Entrega_1/
│   │   ├── README.md
│   ├── Entrega_2/
│   │   ├── README.md
```


- La carpeta `back` contiene el código correspondiente a GO, con su respectivo `README.md`
- La carpeta `db` contiene el código SQL para la creación de objetos en la base de datos
- La carpeta `docs/Entrega_1` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
- La carpeta `docs/Entrega_2` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
- La carpeta `docs/Video` contiene un vídeo para pruebas tanto de carga como de uso en la API.
- La carpeta `front` contiene el código correspondiente a la interfaz gráfica desarrollada en React, con su respectivo `README.md`
- La carpeta `sustentacion` contiene el respectivo `README.md` en cada carpeta de entrega con el respectivo enlace del video de demostración.

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

- El vídeo de la aplicación lo puede encontrar en `sustentacion/Entrega_1\` como archivo o link externo.