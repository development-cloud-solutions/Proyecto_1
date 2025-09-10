#!/bin/bash

set -e

echo "📈 Ejecutando pruebas de carga..."

# Verificar que Artillery está instalado
if ! command -v artillery &> /dev/null; then
    echo "📦 Instalando Artillery..."
    npm install -g artillery
fi

# Crear configuración de Artillery si no existe
if [ ! -f artillery-config.yml ]; then
    cat > artillery-config.yml << 'EOF'
config:
  target: 'http://localhost:8080'
  phases:
    - duration: 60
      arrivalRate: 5
      name: "Warmup"
    - duration: 120
      arrivalRate: 10
      name: "Normal load"
    - duration: 60
      arrivalRate: 20
      name: "Peak load"

scenarios:
  - name: "Health check"
    weight: 20
    flow:
      - get:
          url: "/health"
  
  - name: "Get public videos"
    weight: 40
    flow:
      - get:
          url: "/api/public/videos"
  
  - name: "Get rankings"
    weight: 30
    flow:
      - get:
          url: "/api/public/rankings"
  
  - name: "User registration and login"
    weight: 10
    flow:
      - post:
          url: "/api/auth/signup"
          json:
            first_name: "Test"
            last_name: "User"
            email: "test{{ $randomString() }}@example.com"
            password1: "TestPass123!"
            password2: "TestPass123!"
            city: "TestCity"
            country: "TestCountry"
      - post:
          url: "/api/auth/login"
          json:
            email: "test@example.com"
            password: "TestPass123!"
EOF
fi

# Ejecutar pruebas de carga
artillery run artillery-config.yml --output load-test-results.json

# Generar reporte
artillery report load-test-results.json

echo "✅ Pruebas de carga completadas!"
echo "📊 Reporte disponible en load-test-results.json"