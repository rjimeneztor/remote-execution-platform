#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}ℹ️ $1${NC}"
}

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 INSTALADOR - PLATAFORMA DE EJECUCIÓN REMOTA           ║
║                                                              ║
║    🌐 Web + Telegram Bot + Docker + Puppet                   ║
║    🔒 Ejecución segura de código remoto                      ║
║    📊 Monitoreo y gestión centralizada                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar que estamos en Ubuntu
print_step "1" "Verificando sistema operativo..."
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ $ID == "ubuntu" ]]; then
        print_success "Ubuntu $VERSION_ID detectado"
    else
        print_warning "Sistema: $ID $VERSION_ID (no es Ubuntu, continuando...)"
    fi
else
    print_warning "No se pudo detectar el sistema operativo"
fi

# Actualizar sistema
print_step "2" "Actualizando sistema..."
sudo apt update && sudo apt upgrade -y
print_success "Sistema actualizado"

# Instalar dependencias básicas
print_step "3" "Instalando dependencias básicas..."
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm
print_success "Dependencias básicas instaladas"

# Instalar Docker
print_step "4" "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    # Añadir repositorio oficial de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Añadir usuario al grupo docker
    sudo usermod -aG docker $USER
    
    # Iniciar Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker instalado correctamente"
else
    print_success "Docker ya está instalado"
fi

# Instalar Docker Compose
print_step "5" "Verificando Docker Compose..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose instalado"
else
    print_success "Docker Compose ya está disponible"
fi

# Instalar Puppet
print_step "6" "Instalando Puppet..."
if ! command -v puppet &> /dev/null; then
    # Descargar e instalar Puppet
    wget https://apt.puppetlabs.com/puppet7-release-$(lsb_release -cs).deb
    sudo dpkg -i puppet7-release-$(lsb_release -cs).deb
    sudo apt update
    sudo apt install -y puppet-agent
    
    # Añadir Puppet al PATH
    echo 'export PATH="/opt/puppetlabs/bin:$PATH"' >> ~/.bashrc
    export PATH="/opt/puppetlabs/bin:$PATH"
    
    print_success "Puppet instalado correctamente"
else
    print_success "Puppet ya está instalado"
fi

# Configurar Foreman (opcional, para instalación completa)
print_step "7" "Configurando Foreman..."
read -p "¿Quieres instalar Foreman para gestión centralizada? (y/n): " install_foreman

if [[ $install_foreman == "y" || $install_foreman == "Y" ]]; then
    # Instalar Foreman
    echo "deb http://deb.theforeman.org/ $(lsb_release -cs) 3.4" | sudo tee /etc/apt/sources.list.d/foreman.list
    wget -q https://deb.theforeman.org/pubkey.gpg -O- | sudo apt-key add -
    sudo apt update
    sudo apt install -y foreman-installer
    
    # Configurar Foreman
    sudo foreman-installer \
        --enable-foreman \
        --enable-foreman-cli \
        --enable-puppet \
        --puppet-server=true \
        --puppet-server-foreman-url=https://$(hostname -f)
    
    print_success "Foreman instalado y configurado"
else
    print_info "Saltando instalación de Foreman"
fi

# Crear estructura de directorios
print_step "8" "Creando estructura de proyecto..."
mkdir -p {backend,frontend,telegram-bot,code-executor,database,nginx,puppet,monitoring,scripts,logs,data}
mkdir -p puppet/{manifests,modules,hieradata}
mkdir -p data/{postgres,redis,uploads}
mkdir -p logs/{backend,telegram,executor,nginx}

print_success "Estructura de directorios creada"

# Configurar variables de entorno
print_step "9" "Configurando variables de entorno..."
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
TELEGRAM_WEBHOOK_URL=https://your-domain.com/telegram/webhook

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=false

# Security Configuration
ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com
CORS_ORIGINS=http://localhost:3000,https://your-domain.com

# Execution Limits
MAX_EXECUTION_TIME=300
MAX_MEMORY_MB=512
MAX_CPU_PERCENT=50

# File Upload Limits
MAX_FILE_SIZE_MB=10
ALLOWED_FILE_TYPES=.py,.sh,.ps1,.js,.sql

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
EOF

print_success "Variables de entorno configuradas"

# Generar certificados SSL
print_step "10" "Generando certificados SSL..."
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/private.key \
    -out ssl/certificate.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=RemoteExecution/CN=localhost"

print_success "Certificados SSL generados"

# Configurar permisos
print_step "11" "Configurando permisos..."
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh 2>/dev/null || true
chmod 600 ssl/private.key
chmod 644 ssl/certificate.crt

print_success "Permisos configurados"

# Información final
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ INSTALACIÓN COMPLETADA                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_success "Sistema base instalado correctamente"
echo ""
print_info "PRÓXIMOS PASOS:"
echo ""
echo "1. 🔧 CONFIGURAR TELEGRAM BOT:"
echo "   • Crea un bot con @BotFather"
echo "   • Edita .env con tu TELEGRAM_BOT_TOKEN"
echo ""
echo "2. 🚀 CONSTRUIR SERVICIOS:"
echo "   ./build.sh"
echo ""
echo "3. 🌐 INICIAR PLATAFORMA:"
echo "   ./start.sh"
echo ""
echo "4. 📊 ACCESOS:"
echo "   • Web: https://localhost"
echo "   • API: https://localhost/api"
echo "   • Grafana: http://localhost:3001"
echo ""

if [[ $install_foreman == "y" || $install_foreman == "Y" ]]; then
    echo "5. 🎛️ FOREMAN:"
    echo "   • URL: https://$(hostname -f)"
    echo "   • Usuario: admin"
    echo "   • Contraseña: (ver /etc/foreman/initial_admin_password)"
    echo ""
fi

print_warning "IMPORTANTE: Reinicia la sesión para aplicar cambios de grupo Docker"
print_info "Ejecuta: newgrp docker"

echo ""
print_success "¡Instalación completada! 🎉"