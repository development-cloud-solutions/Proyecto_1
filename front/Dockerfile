FROM node:alpine AS build

# Argumentos de construcción para variables VITE
ARG VITE_API_URL=http://localhost
ARG VITE_VIDEOS_URL=http://localhost
ARG VITE_APP_NAME="ANB Rising Stars Showcase"
ARG VITE_APP_VERSION=1.0.0
ARG VITE_ENVIRONMENT=development

# Establecer variables de entorno durante el build
ENV VITE_API_URL=${VITE_API_URL}
ENV VITE_VIDEOS_URL=${VITE_VIDEOS_URL}
ENV VITE_APP_NAME=${VITE_APP_NAME}
ENV VITE_APP_VERSION=${VITE_APP_VERSION}
ENV VITE_ENVIRONMENT=${VITE_ENVIRONMENT}

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .

# Mostrar variables durante el build
RUN echo "Building with VITE_API_URL=${VITE_API_URL}"

RUN npm run build

FROM nginx:alpine

# Instalar tzdata para configurar zona horaria
RUN apk --no-cache add tzdata

# Establecer zona horaria
ENV TZ=America/Bogota

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
