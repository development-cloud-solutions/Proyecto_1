# Resumen de Pruebas de Carga - ANB Rising Stars

**Fecha de ejecución**: Fri Oct 24 21:40:48 -05 2025  
**Duración total**: 19 minutos (6 fases)  

## Configuración de Prueba

- **Target**: http://localhost/:80
- **Fases**: 6 (Warmup → Normal → Media → Alta → Pico → Recuperación)
- **Usuarios máximos**: 200 usuarios/segundo
- **Escenarios**: Navegación básica (60%), Autenticación (25%), Interacción avanzada (10%), Upload videos (5%)

## Archivos Generados

- Resultados JSON: `load-test-results-20251024-213921.json`
- Docker stats: `docker-stats-*-20251024-213921.txt`
- Análisis en consola: Ver output detallado arriba

## Próximos Pasos

1. Revisar el reporte HTML detallado
2. Analizar métricas de latencia y throughput
3. Identificar cuellos de botella en la aplicación
4. Implementar optimizaciones recomendadas
5. Repetir pruebas después de optimizaciones

## Criterios de Evaluación

-   **Latencia P95 < 500ms**
-   **Throughput > 100 RPS**
-   **Tasa de errores < 1%**
-   **Tiempo de respuesta estable**

