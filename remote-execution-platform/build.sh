#!/bin/bash

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[PASO $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🏗️ CONSTRUYENDO PLATAFORMA                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    print_error "No se encontró docker-compose.yml. Ejecuta desde el directorio raíz del proyecto."
    exit 1
fi

# Cargar variables de entorno
if [ -f ".env" ]; then
    source .env
    print_success "Variables de entorno cargadas"
else
    print_warning "Archivo .env no encontrado, usando valores por defecto"
fi

print_step "1" "Creando estructura de archivos faltantes..."

# Crear archivos básicos del backend si no existen
mkdir -p backend/routers backend/models backend/services
mkdir -p frontend/src frontend/public
mkdir -p code-executor/executors
mkdir -p notification-service
mkdir -p nginx/sites-available
mkdir -p monitoring/grafana/dashboards monitoring/grafana/datasources
mkdir -p puppet/manifests puppet/modules

print_success "Estructura de directorios creada"

print_step "2" "Generando archivos de configuración..."

# Crear archivo de inicialización de base de datos
cat > database/init.sql << 'EOF'
-- Inicialización de base de datos
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de sesiones
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    telegram_user_id BIGINT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de ejecuciones
CREATE TABLE IF NOT EXISTS code_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    language VARCHAR(20) NOT NULL,
    code TEXT NOT NULL,
    output TEXT,
    error_output TEXT,
    execution_time FLOAT,
    memory_used INTEGER,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Tabla de notificaciones
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_telegram ON user_sessions(telegram_user_id);
CREATE INDEX IF NOT EXISTS idx_executions_user_id ON code_executions(user_id);
CREATE INDEX IF NOT EXISTS idx_executions_status ON code_executions(status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Usuario administrador por defecto
INSERT INTO users (username, email, password_hash, is_admin) 
VALUES ('admin', 'admin@platform.local', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj3L3jzjvG4e', true)
ON CONFLICT (username) DO NOTHING;
EOF

# Crear configuración de Nginx
cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
    
    # Upstream backends
    upstream backend_api {
        server backend:8000;
    }
    
    upstream frontend_app {
        server frontend:80;
    }
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$server_name$request_uri;
    }
    
    # Main HTTPS server
    server {
        listen 443 ssl http2;
        server_name _;
        
        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/certificate.crt;
        ssl_certificate_key /etc/nginx/ssl/private.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
        
        # API routes
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend_api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Auth routes with stricter limits
        location /api/auth/ {
            limit_req zone=login burst=5 nodelay;
            proxy_pass http://backend_api/auth/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # WebSocket for real-time updates
        location /ws/ {
            proxy_pass http://backend_api/ws/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Frontend
        location / {
            proxy_pass http://frontend_app/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Health checks
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Crear Dockerfile para Nginx
cat > nginx/Dockerfile << 'EOF'
FROM nginx:alpine

# Instalar curl para health checks
RUN apk add --no-cache curl

# Copiar configuración
COPY nginx.conf /etc/nginx/nginx.conf

# Crear directorio para SSL
RUN mkdir -p /etc/nginx/ssl

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443
EOF

# Crear configuración de Prometheus
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'platform-backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'

  - job_name: 'platform-telegram-bot'
    static_configs:
      - targets: ['telegram-bot:8001']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
EOF

print_success "Archivos de configuración generados"

print_step "3" "Construyendo imágenes Docker..."

# Construir imágenes
docker-compose build --no-cache

if [ $? -eq 0 ]; then
    print_success "Imágenes construidas correctamente"
else
    print_error "Error construyendo imágenes"
    exit 1
fi

print_step "4" "Verificando configuración..."

# Verificar que las imágenes se crearon
images=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(platform|remote-execution)")
if [ -n "$images" ]; then
    print_success "Imágenes verificadas:"
    echo "$images"
else
    print_warning "No se encontraron imágenes de la plataforma"
fi

print_step "5" "Preparando datos iniciales..."

# Crear directorios de datos con permisos correctos
sudo chown -R $USER:$USER data/ logs/
chmod -R 755 data/ logs/

print_success "Permisos configurados"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ CONSTRUCCIÓN COMPLETADA                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_success "Plataforma construida correctamente"
echo ""
echo "🚀 PRÓXIMOS PASOS:"
echo ""
echo "1. Configurar bot de Telegram (si no lo has hecho):"
echo "   • Edita .env con tu TELEGRAM_BOT_TOKEN"
echo ""
echo "2. Iniciar la plataforma:"
echo "   ./start.sh"
echo ""
echo "3. Acceder a la plataforma:"
echo "   • Web: https://localhost"
echo "   • API: https://localhost/api/docs"
echo "   • Grafana: http://localhost:3001"
echo ""

print_success "¡Construcción completada! 🎉"