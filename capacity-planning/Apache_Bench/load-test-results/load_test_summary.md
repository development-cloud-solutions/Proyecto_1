# Resumen de Pruebas de Carga
## Fecha: Tue Sep  9 23:39:43 -05 2025

### Configuración
- Total de requests por prueba: 1000
- Usuarios concurrentes: 100
- URL base: http://localhost:8080/api

### Resultados por Endpoint

### Get Profile
```
Time taken for tests:   0.172 seconds
Failed requests:        0
Requests per second:    5812.43 [#/sec] (mean)
Time per request:       17.204 [ms] (mean)
Time per request:       0.172 [ms] (mean, across all concurrent requests)
Transfer rate:          2525.91 [Kbytes/sec] received
```

### Get Videos
```
Time taken for tests:   0.173 seconds
Failed requests:        0
Requests per second:    5785.53 [#/sec] (mean)
Time per request:       17.285 [ms] (mean)
Time per request:       0.173 [ms] (mean, across all concurrent requests)
Transfer rate:          2514.22 [Kbytes/sec] received
```

### Health Check
```
Time taken for tests:   0.194 seconds
Failed requests:        0
Requests per second:    5149.01 [#/sec] (mean)
Time per request:       19.421 [ms] (mean)
Time per request:       0.194 [ms] (mean, across all concurrent requests)
Transfer rate:          2282.86 [Kbytes/sec] received
```

### User Login
```
Time taken for tests:   0.195 seconds
Failed requests:        0
Requests per second:    5118.78 [#/sec] (mean)
Time per request:       19.536 [ms] (mean)
Time per request:       0.195 [ms] (mean, across all concurrent requests)
Transfer rate:          2174.48 [Kbytes/sec] received
```

### User Registration
```
Time taken for tests:   0.177 seconds
Failed requests:        0
Requests per second:    5645.86 [#/sec] (mean)
Time per request:       17.712 [ms] (mean)
Time per request:       0.177 [ms] (mean, across all concurrent requests)
Transfer rate:          2894.60 [Kbytes/sec] received
```

