# Backend - Video Processing API

Backend del sistema de procesamiento de videos construido con Go, Gin, PostgreSQL y Redis.

## Arquitectura

- **Framework**: Gin (Go)
- **Base de datos**: PostgreSQL
- **Cache/Cola de tareas**: Redis
- **Procesamiento asíncrono**: Asynq
- **Autenticación**: JWT
- **Almacenamiento**: Sistema de archivos local

## Estructura del proyecto

```
back/
├── cmd/                    # Puntos de entrada de la aplicación
│   ├── api/               # Servidor API principal
│   └── worker/            # Worker para procesamiento de videos
├── internal/              # Código interno de la aplicación
│   ├── api/               # Rutas y controladores HTTP
│   ├── config/            # Configuración de la aplicación
│   ├── database/          # Conexión y manejo de base de datos
│   ├── services/          # Lógica de negocio
│   ├── utils/             # Utilidades generales
│   └── workers/           # Workers para tareas asíncronas
├── assets/                # Recursos estáticos
├── build/                 # Archivos compilados
├── nginx/                 # Configuración de Nginx
├── scripts/               # Scripts de testing (load-test.sh, newman-test.sh)
├── uploads/               # Archivos subidos por usuarios
├── processed/             # Videos procesados
├── Dockerfile.api         # Docker para API
├── Dockerfile.worker      # Docker para Worker
├── artillery-config.yml   # Configuración para pruebas de carga
├── go.mod                # Dependencias de Go
└── .env.example          # Variables de entorno de ejemplo
```

## Inicio rápido

### Prerrequisitos

- Go 1.21+
- PostgreSQL
- Redis
- Docker

### Configuración inicial

1. **Configurar variables de entorno**:
   ```bash
   cp .env.example .env
   ```

2. **Iniciar servicios con Docker**:
   ```bash
   docker-compose up -d
   ```

3. **Ejecutar en modo desarrollo**:
   ```bash
   go run cmd/api/main.go
   ```

4. **Ejecutar worker (en otra terminal)**:
   ```bash
   WORKER_MODE=true go run cmd/worker/main.go
   ```

## 🔧 Variables de entorno

| Variable | Descripción | Valor por defecto |
|----------|-------------|------------------|
| `PORT` | Puerto del servidor API | `8080` |
| `DB_HOST` | Host de PostgreSQL | `postgres` |
| `DB_NAME` | Nombre de la base de datos | `proyecto_1` |
| `REDIS_URL` | URL de Redis | `redis:6379` |
| `JWT_SECRET` | Clave secreta para JWT | `local-development-secret-key` |
| `UPLOAD_PATH` | Directorio de uploads | `./uploads` |
| `MAX_FILE_SIZE` | Tamaño máximo de archivo (bytes) | `104857600` |
| `WORKER_CONCURRENCY` | Concurrencia del worker | `5` |

Ver `.env.example` para la lista completa.

## API Endpoints

### Autenticación
- `POST /api/auth/register` - Registro de usuarios
- `POST /api/auth/login` - Inicio de sesión
- `POST /api/auth/refresh` - Renovar token

### Videos
- `GET /api/videos` - Listar videos
- `POST /api/videos/upload` - Subir video
- `GET /api/videos/:id` - Obtener video específico
- `DELETE /api/videos/:id` - Eliminar video

### Estado
- `GET /api/health` - Estado de la aplicación

## Procesamiento de videos

El sistema utiliza un worker asíncrono para procesar videos:

1. **Upload**: El video se sube a través de la API
2. **Cola**: Se crea una tarea en Redis usando Asynq
3. **Worker**: Procesa el video en segundo plano
4. **Resultado**: El video procesado se guarda y se actualiza el estado

### Configuración de procesamiento

- **Duración máxima**: 30 segundos
- **Resolución de salida**: 1280x720
- **Aspect ratio**: 16:9
- **Concurrencia**: 5 workers simultáneos

## Testing

### Pruebas unitarias
```bash
go test ./...
```

### Pruebas de API con Newman
```bash
./scripts/newman-test.sh
```

### Pruebas de carga
```bash
./scripts/load-test.sh
```

## Desarrollo

### Estructura de código

- **cmd/**: Puntos de entrada separados para API y worker
- **internal/api/**: Controladores HTTP y middleware
- **internal/services/**: Lógica de negocio
- **internal/workers/**: Procesamiento asíncrono
- **internal/database/**: Modelos y queries de base de datos

### Convenciones

- Usar `gofmt` para formateo
- Seguir las convenciones de Go
- Documentar funciones públicas
- Incluir tests para nueva funcionalidad

### Scripts útiles

- `scripts/load-test.sh`: Pruebas de carga con Artillery
- `scripts/newman-test.sh`: Pruebas de API con Newman

## Monitoreo

### Logs
```bash
docker-compose logs -f  # Ver logs de Docker Compose
```

### Métricas
- El servidor expone métricas básicas de salud en `/api/health`
- Los workers reportan su estado en los logs
