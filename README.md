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
│   ├── .env
│   ├── .env.example
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
│   ├── processed/
│   ├── scripts/
│   │   ├── load-test.sh
│   │   ├── newman-tests.sh
│   ├── uploads/
├── capacity-planning/
│   ├── 
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
│   │   ├── ISIS4426_Entrega_1_Req.pdf
├── front/
│   ├── .env
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
│   │   ├── App_backup.jsx
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
├── test-api.sh
```


- La carpeta `back` contiene el código correspondiente a GO, con su respectivo `README.md`
- La carpeta `db` contiene el código SQL para la creación de objetos en la base de datos
- La carpeta `docs/Entrega_1` contiene documentos referentes a la descripción de requerimientos del proyectos así como documentos de referencia.
- La carpeta `front` contiene el código correspondiente a la interfaz gráfica desarrollada en React, con su respectivo `README.md`

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

```

5. Con los servicios iniciados, proceda a ingresar a la aplicación web mediante la URL: http://localhost:3000/


## Uso de apliación

- En la carpeta `collections/` puede encontrar:
  - archivo JSON de variables de entorno `postman_environment.json`
  - Archivo JSON de pruebas en postman `anb.json`

- El vídeo de la aplicación lo puede encontrar en `sustentacion/Entrega_1\` como archivo o link externo.