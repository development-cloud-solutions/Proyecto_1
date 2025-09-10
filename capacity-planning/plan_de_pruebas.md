# Plan de Pruebas de Carga — Entrega 1

## 1. Objetivo
Validar el desempeño y escalabilidad de la plataforma **ANB Rising Stars** midiendo:
- **Throughput** (transacciones por minuto)
- **Tiempo de respuesta** promedio y p95
- **Utilización de recursos** (CPU, RAM, I/O)

El objetivo es garantizar que la aplicación pueda manejar la concurrencia definida en los escenarios sin degradar la experiencia del usuario.

---

## 2. Entorno de Pruebas

| Componente        | Configuración |
|------------------|-------------|
| **SO**           | Ubuntu 24.04 LTS |
| **API/Worker**   | Contenedores Docker, Go 1.22 |
| **Base de datos**| PostgreSQL 16 |
| **Broker**       | Redis 7 (Asynq) |
| **Cliente de prueba** | EC2 `m5.large` (2 vCPU, 8 GB RAM) en us-east-1 |
| **Herramienta**  | [Apache JMeter](https://jmeter.apache.org/) (alternativamente Apache Bench para pruebas rápidas) |

Monitoreo:
- `docker stats` y `pg_stat_activity` para métricas de CPU/memoria/IO.
- Grafana + InfluxDB (opcional) para visualizar métricas en vivo.

---

## 3. Criterios de Aceptación

| Métrica | Objetivo |
|--------|-----------|
| **Tiempo de respuesta promedio** | `< 500ms` para rutas críticas |
| **Throughput** | `> 200 req/min` en escenario de carga normal |
| **Errores HTTP** | `< 1%` del total de peticiones |
| **CPU** | `< 75%` uso sostenido |
| **Memoria** | Sin OOM ni leaks después de 10 min de carga |

---

## 4. Escenarios de Prueba

### Escenario 1 — Ruta Crítica de Usuario
**Flujo:**  
`POST /auth/signup` → `POST /auth/login` → `POST /videos/upload` → `GET /videos`  
**Objetivo:** Validar tiempos de respuesta en operaciones más usadas por el usuario.  
- Usuarios concurrentes: **10, 50, 100, 200, 500**
- Ramp-up: **30s**
- Métricas: tiempo de respuesta promedio y p95, throughput, tasa de errores.

### Escenario 2 — Procesamiento Batch
**Flujo:**  
Encolar **100 tareas de procesamiento de video** simultáneamente y esperar hasta que todas pasen a estado `processed`.  
- Medir tiempo total de procesamiento.
- Medir consumo de CPU y memoria del worker.
- Validar que no existan fallos de procesamiento (DLQ vacío al final).

---

## 5. Estrategia de Pruebas
- **Prueba de humo:** 10 usuarios concurrentes, confirmar que endpoints responden 2xx.
- **Prueba de carga progresiva:** Escalar 10 → 500 usuarios concurrentes, medir degradación.
- **Prueba de estrés:** Aumentar usuarios hasta que la latencia p95 supere 1s para encontrar el punto de saturación.

---

## 6. Parámetros de Configuración
- **JMeter:** Thread Group con usuarios configurables, ramp-up 30s, loop 1.
- **Apache Bench (smoke test):**

**ab** → Apache Bench, herramienta de benchmarking.  
**-n 500** → Número total de solicitudes que se van a enviar (500 requests en total).  
**-c 50** → Número de solicitudes concurrentes (50 usuarios simultáneos).  

`http://localhost:8080/api/public/videos` → URL del endpoint que se va a probar (en tu caso, listar videos).  

---

## 7. Topología de Prueba

```text
[JMeter/AB Client] --> [Nginx] --> [API (Gin)] --> [PostgreSQL + Redis]
                                     |
                                     --> [Worker Asynq] --> [ffmpeg processing]
