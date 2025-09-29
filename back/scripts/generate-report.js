#!/usr/bin/env node

/**
 * Generador de reportes básico para Artillery
 * Alternativa al comando "artillery report" descontinuado
 */

const fs = require('fs');
const path = require('path');

function formatNumber(num) {
    return Number(num).toLocaleString();
}

function formatTime(ms) {
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
}

function generateTextReport(jsonPath, outputPath = null) {
    try {
        const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
        const aggregate = data.aggregate || {};
        const counters = aggregate.counters || {};
        const rates = aggregate.rates || {};
        const summaries = aggregate.summaries || {};

        // Artillery v2+ usa diferentes rutas para latencia
        const responseTime = summaries['http.response_time'] || aggregate.latency || {};

        const report = `
#  Reporte de Pruebas de Carga - Artillery

**Archivo:** ${path.basename(jsonPath)}
**Generado:** ${new Date().toLocaleString()}

##  Métricas Principales

### Volumen de Requests
- **Total Requests:** ${formatNumber(counters['http.requests'] || 0)}
- **Requests Exitosos:** ${formatNumber(counters['http.responses'] || 0)}
- **RPS Promedio:** ${(rates['http.request_rate'] || 0).toFixed(2)}

### Latencias
- **Mínima:** ${formatTime(responseTime.min || 0)}
- **Mediana (P50):** ${formatTime(responseTime.p50 || responseTime.median || 0)}
- **P95:** ${formatTime(responseTime.p95 || 0)}
- **P99:** ${formatTime(responseTime.p99 || 0)}
- **Máxima:** ${formatTime(responseTime.max || 0)}

### Códigos de Estado HTTP
${Object.keys(counters)
    .filter(key => key.startsWith('http.codes.'))
    .map(key => {
        const code = key.replace('http.codes.', '');
        return `- **${code}:** ${formatNumber(counters[key])}`;
    })
    .join('\n')}

### Errores
- **Timeouts:** ${formatNumber(counters['errors.ETIMEDOUT'] || 0)}
- **Conexión Rechazada:** ${formatNumber(counters['errors.ECONNREFUSED'] || 0)}
- **DNS:** ${formatNumber(counters['errors.ENOTFOUND'] || 0)}
- **Otros Errores:** ${formatNumber(Object.keys(counters).filter(k => k.startsWith('errors.') && !['errors.ETIMEDOUT', 'errors.ECONNREFUSED', 'errors.ENOTFOUND'].includes(k)).reduce((sum, k) => sum + counters[k], 0))}

### Usuarios Virtuales
- **Completados:** ${formatNumber(counters['vusers.completed'] || 0)}
- **Fallidos:** ${formatNumber(counters['vusers.failed'] || 0)}

##  Evaluación de Performance

### Criterios de Éxito
${evaluatePerformance(responseTime, rates, counters).map(item => `- ${item}`).join('\n')}

##  Detalles Técnicos

### Configuración
- **Target:** ${data.config?.target || 'No especificado'}
- **Duración Total:** ${calculateTotalDuration(data)} segundos
- **Fases:** ${data.config?.phases?.length || 0}

### Archivos de Entrada
${data.config?.payload?.path ? `- **CSV Data:** ${data.config.payload.path}` : '- Sin archivo CSV'}
${data.config?.processor ? `- **Processor:** ${data.config.processor}` : '- Sin processor personalizado'}

---

 **Para reportes visuales más detallados:**
- Visite [Artillery Cloud](https://app.artillery.io)
- Importe este archivo JSON: \`${path.basename(jsonPath)}\`

 **Datos completos disponibles en:** \`${jsonPath}\`
`;

        if (outputPath) {
            fs.writeFileSync(outputPath, report);
            console.log(`  Reporte generado: ${outputPath}`);
        } else {
            console.log(report);
        }

        // Forzar salida inmediata para evitar colgado
        process.nextTick(() => {
            if (require.main === module) {
                process.exit(0);
            }
        });

        return report;
    } catch (error) {
        console.error('  Error generando reporte:', error.message);
        // Forzar salida inmediata en caso de error
        process.nextTick(() => process.exit(1));
    }
}

function evaluatePerformance(responseTime, rates, counters) {
    const p95 = responseTime.p95 || 0;
    const rps = rates['http.request_rate'] || 0;
    const totalRequests = counters['http.requests'] || 0;
    const successRequests = counters['http.responses'] || 0;
    const successRate = totalRequests > 0 ? (successRequests / totalRequests) * 100 : 0;

    const results = [];

    // P95 Latency
    if (p95 < 500) {
        results.push('  **Latencia P95 < 500ms:** PASÓ (' + formatTime(p95) + ')');
    } else {
        results.push('  **Latencia P95 < 500ms:** FALLÓ (' + formatTime(p95) + ')');
    }

    // Throughput
    if (rps > 100) {
        results.push('  **Throughput > 100 RPS:** PASÓ (' + rps.toFixed(2) + ' RPS)');
    } else if (rps > 50) {
        results.push('  **Throughput:** ACEPTABLE (' + rps.toFixed(2) + ' RPS)');
    } else {
        results.push('  **Throughput > 100 RPS:** FALLÓ (' + rps.toFixed(2) + ' RPS)');
    }

    // Success Rate
    if (successRate > 99) {
        results.push('  **Tasa de Éxito > 99%:** PASÓ (' + successRate.toFixed(1) + '%)');
    } else if (successRate > 95) {
        results.push('  **Tasa de Éxito:** ACEPTABLE (' + successRate.toFixed(1) + '%)');
    } else {
        results.push('  **Tasa de Éxito > 99%:** FALLÓ (' + successRate.toFixed(1) + '%)');
    }

    return results;
}

function calculateTotalDuration(data) {
    if (!data.config?.phases) return 0;
    return data.config.phases.reduce((total, phase) => total + (phase.duration || 0), 0);
}

// CLI Usage
if (require.main === module) {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log(`
 Generador de Reportes Artillery

Uso:
  node generate-report.js <archivo.json> [archivo-salida.md]

Ejemplos:
  node generate-report.js results.json
  node generate-report.js results.json report.md

Opciones:
  - Sin archivo de salida: Muestra el reporte en consola
  - Con archivo de salida: Guarda el reporte en archivo Markdown
`);
        process.exit(1);
    }

    const jsonPath = args[0];
    const outputPath = args[1];

    if (!fs.existsSync(jsonPath)) {
        console.error(`  Archivo no encontrado: ${jsonPath}`);
        process.nextTick(() => process.exit(1));
        return;
    }

    generateTextReport(jsonPath, outputPath);
}

module.exports = { generateTextReport };