# Reporte Newman - ANB Rising Stars API

## Información General

- **Colección**: ANB Rising Stars API
- **Descripción**: API para la plataforma ANB Rising Stars Showcase
- **Tiempo de ejecución**: Tue Sep 09 2025 20:37:12 GMT-0500 (Colombia Standard Time)
- **Exportado con**: Newman v6.2.1

## Métricas

| Categoría | Total | Fallidos |
|-----------|-------|----------|
| Iteraciones | 1 | 0 |
| Requests | 6 | 0 |
| Scripts Previos | 1 | 0 |
| Scripts de Test | 6 | 0 |
| Aserciones | 13 | 0 |

## Resumen de Rendimiento

- **Duración total**: 331ms
- **Datos recibidos**: 1.08KB (approx)
- **Tiempo promedio de respuesta**: 34ms
- **Total de fallos**: 0

---

## Requests Detallados

### Authentication

#### Register User
- **Método**: POST
- **URL**: http://localhost/api/auth/signup
- **Tiempo promedio**: 75ms
- **Tamaño promedio**: 39B
- **Status code**: 201
- **Tests pasados**: 2/2
  - Status code is 201
  - Response has message

#### Login User
- **Método**: POST
- **URL**: http://localhost/api/auth/login
- **Tiempo promedio**: 54ms
- **Tamaño promedio**: 363B
- **Status code**: 200
- **Tests pasados**: 3/3
  - Status code is 200
  - Response has access token
  - Token type is Bearer

#### Get Profile
- **Método**: GET
- **URL**: http://localhost/api/auth/profile
- **Tiempo promedio**: 4ms
- **Tamaño promedio**: 213B
- **Status code**: 200
- **Tests pasados**: 2/2
  - Status code is 200
  - Response has user data

### Videos Management

#### Upload Video
- **Método**: POST
- **URL**: http://localhost/api/videos/upload
- **Tiempo promedio**: 64ms
- **Tamaño promedio**: 114B
- **Status code**: 201
- **Tests pasados**: 2/2
  - Status code is 201
  - Response has task_id

#### Get My Videos
- **Método**: GET
- **URL**: http://localhost/api/videos
- **Tiempo promedio**: 4ms
- **Tamaño promedio**: 303B
- **Status code**: 200
- **Tests pasados**: 2/2
  - Status code is 200
  - Response is an array

### Health Check

#### Health Check
- **Método**: GET
- **URL**: http://localhost/health
- **Tiempo promedio**: 3ms
- **Tamaño promedio**: 73B
- **Status code**: 200
- **Tests pasados**: 2/2
  - Status code is 200
  - Health status is healthy

---

## Conclusión

- La API está funcionando correctamente en todas las áreas probadas: autenticación, gestión de videos y verificación de salud del sistema.
