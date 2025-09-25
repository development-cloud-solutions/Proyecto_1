FROM node:alpine AS build

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
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
