#!/bin/bash

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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

print_info() {
    echo -e "${PURPLE}ℹ️ $1${NC}"
}

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 INICIANDO PLATAFORMA DE EJECUCIÓN REMOTA              ║
║                                                              ║
║    🌐 Web + API + Telegram Bot + Monitoreo                   ║
║    🔒 Ejecución segura y sandboxeada                         ║
║    📊 Métricas y logs en tiempo real                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar prerrequisitos
print_step "1" "Verificando prerrequisitos..."

if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose no está disponible"
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml no encontrado. Ejecuta desde el directorio raíz."
    exit 1
fi

print_success "Prerrequisitos verificados"

# Cargar variables de entorno
print_step "2" "Cargando configuración..."

if [ -f ".env" ]; then
    source .env
    print_success "Variables de entorno cargadas"
else
    print_warning "Archivo .env no encontrado"
    print_info "Creando configuración básica..."
    
    # Crear .env básico
    cat > .env << EOF
# Database Configuration
POSTGRES_DB=remote_execution
POSTGRES_USER=platform_user
POSTGRES_PASSWORD=$(openssl rand -base64 32)
DATABASE_URL=postgresql://platform_user:$(openssl rand -base64 32)@postgres:5432/remote_execution

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# JWT Configuration
JWT_SECRET_KEY=$(openssl rand -base64 64)
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=1440

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN_HERE

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=false

# Security Configuration
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ORIGINS=http://localhost:3000,https://localhost

# Execution Limits
MAX_EXECUTION_TIME=300
MAX_MEMORY_MB=512
MAX_CPU_PERCENT=50
EOF
    
    print_warning "Configuración básica creada. Edita .env con tus valores."
fi

# Verificar configuración crítica
if [ "$TELEGRAM_BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    print_warning "Token de Telegram no configurado"
    print_info "El bot de Telegram no funcionará hasta que configures TELEGRAM_BOT_TOKEN en .env"
fi

# Detener servicios existentes
print_step "3" "Deteniendo servicios existentes..."
docker-compose down --remove-orphans 2>/dev/null || true
print_success "Servicios detenidos"

# Crear directorios necesarios
print_step "4" "Preparando directorios..."
mkdir -p data/{postgres,redis,grafana,prometheus,uploads}
mkdir -p logs/{backend,telegram,executor,nginx,notifications}
chmod -R 755 data/ logs/
print_success "Directorios preparados"

# Iniciar servicios base primero
print_step "5" "Iniciando servicios base (PostgreSQL, Redis)..."
docker-compose up -d postgres redis

# Esperar a que estén listos
print_info "Esperando que la base de datos esté lista..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U ${POSTGRES_USER:-platform_user} -d ${POSTGRES_DB:-remote_execution} &>/dev/null; then
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

if docker-compose exec -T postgres pg_isready -U ${POSTGRES_USER:-platform_user} -d ${POSTGRES_DB:-remote_execution} &>/dev/null; then
    print_success "Base de datos lista"
else
    print_error "Base de datos no responde"
    exit 1
fi

# Iniciar servicios de aplicación
print_step "6" "Iniciando servicios de aplicación..."
docker-compose up -d backend code-executor notification-service

# Esperar a que el backend esté listo
print_info "Esperando que el backend esté listo..."
for i in {1..30}; do
    if curl -f http://localhost:8000/health &>/dev/null; then
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

if curl -f http://localhost:8000/health &>/dev/null; then
    print_success "Backend listo"
else
    print_warning "Backend no responde en el puerto 8000"
fi

# Iniciar bot de Telegram si está configurado
print_step "7" "Iniciando bot de Telegram..."
if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN_HERE" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    docker-compose up -d telegram-bot
    print_success "Bot de Telegram iniciado"
else
    print_warning "Bot de Telegram no iniciado (token no configurado)"
fi

# Iniciar frontend y proxy
print_step "8" "Iniciando frontend y proxy..."
docker-compose up -d frontend nginx
print_success "Frontend y proxy iniciados"

# Iniciar monitoreo
print_step "9" "Iniciando servicios de monitoreo..."
docker-compose up -d prometheus grafana node-exporter
print_success "Monitoreo iniciado"

# Verificar estado de todos los servicios
print_step "10" "Verificando estado de servicios..."

services=("postgres" "redis" "backend" "nginx" "prometheus" "grafana")
failed_services=()

for service in "${services[@]}"; do
    if docker-compose ps $service | grep -q "Up"; then
        print_success "$service: Funcionando"
    else
        print_error "$service: No funciona"
        failed_services+=($service)
    fi
done

# Verificar accesos web
print_step "11" "Verificando accesos web..."

# Verificar HTTPS (puede fallar por certificado autofirmado)
if curl -k -f https://localhost/health &>/dev/null; then
    print_success "HTTPS: Accesible"
else
    print_warning "HTTPS: No accesible"
fi

# Verificar API
if curl -f http://localhost:8000/health &>/dev/null; then
    print_success "API: Accesible"
else
    print_warning "API: No accesible"
fi

# Verificar Grafana
if curl -f http://localhost:3001/api/health &>/dev/null; then
    print_success "Grafana: Accesible"
else
    print_warning "Grafana: No accesible"
fi

# Mostrar información final
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 PLATAFORMA INICIADA                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_success "Plataforma de ejecución remota iniciada"
echo ""
print_info "🌐 ACCESOS DISPONIBLES:"
echo ""
echo "   📱 Frontend Web:     https://localhost"
echo "   🔌 API REST:         https://localhost/api"
echo "   📚 Documentación:    https://localhost/api/docs"
echo "   📊 Grafana:          http://localhost:3001 (admin/admin123)"
echo "   📈 Prometheus:       http://localhost:9090"
echo "   💾 Base de datos:    localhost:5432"
echo ""

if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN_HERE" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    print_info "🤖 BOT DE TELEGRAM:"
    echo "   ✅ Bot configurado y funcionando"
    echo "   📱 Busca tu bot en Telegram y envía /start"
else
    print_info "🤖 BOT DE TELEGRAM:"
    echo "   ⚠️  No configurado"
    echo "   📝 Edita .env con tu TELEGRAM_BOT_TOKEN"
    echo "   🔄 Reinicia con: docker-compose restart telegram-bot"
fi

echo ""
print_info "🔧 COMANDOS ÚTILES:"
echo ""
echo "   Ver logs:           docker-compose logs -f"
echo "   Ver logs específico: docker-compose logs -f [servicio]"
echo "   Reiniciar:          docker-compose restart"
echo "   Detener:            docker-compose down"
echo "   Estado:             docker-compose ps"
echo ""

if [ ${#failed_services[@]} -gt 0 ]; then
    print_warning "⚠️  SERVICIOS CON PROBLEMAS:"
    for service in "${failed_services[@]}"; do
        echo "   • $service"
    done
    echo ""
    print_info "Revisa los logs: docker-compose logs [servicio]"
    echo ""
fi

print_info "📋 PRIMEROS PASOS:"
echo ""
echo "1. 🌐 Accede a https://localhost"
echo "2. 👤 Regístrate o usa admin/admin123"
echo "3. 🐍 Ejecuta tu primer script"
echo "4. 📱 Configura el bot de Telegram (opcional)"
echo "5. 📊 Revisa métricas en Grafana"
echo ""

print_success "¡Plataforma lista para usar! 🚀"

# Mostrar logs en tiempo real (opcional)
echo ""
read -p "¿Quieres ver los logs en tiempo real? (y/n): " show_logs
if [[ $show_logs == "y" || $show_logs == "Y" ]]; then
    echo ""
    print_info "Mostrando logs en tiempo real (Ctrl+C para salir):"
    docker-compose logs -f
fi