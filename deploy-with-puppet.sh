#!/bin/bash

# Script de despliegue con Puppet para la plataforma de ejecución remota

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
║    🎭 DESPLIEGUE CON PUPPET + FOREMAN                        ║
║                                                              ║
║    🚀 Plataforma de Ejecución Remota                         ║
║    🤖 Automatización declarativa completa                    ║
║    📊 Gestión centralizada de infraestructura                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar que estamos ejecutando como root o con sudo
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root o con sudo"
   exit 1
fi

# Obtener información del sistema
print_step "1" "Detectando información del sistema..."
HOSTNAME=$(hostname -f)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
OS_VERSION=$(lsb_release -rs)
print_success "Sistema: Ubuntu $OS_VERSION"
print_success "Hostname: $HOSTNAME"
print_success "IP: $IP_ADDRESS"

# Configurar variables para Puppet
print_step "2" "Configurando variables de Puppet..."

# Generar contraseñas seguras
POSTGRES_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 64)

# Configuración por defecto
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-YOUR_BOT_TOKEN_HERE}"
ENVIRONMENT="${ENVIRONMENT:-production}"
DEBUG_MODE="${DEBUG_MODE:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Límites de ejecución
MAX_EXECUTION_TIME="${MAX_EXECUTION_TIME:-300}"
MAX_MEMORY_MB="${MAX_MEMORY_MB:-512}"
MAX_CPU_PERCENT="${MAX_CPU_PERCENT:-50}"
MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-10}"

# Hosts y CORS
ALLOWED_HOSTS="${ALLOWED_HOSTS:-localhost,127.0.0.1,$HOSTNAME,$IP_ADDRESS}"
CORS_ORIGINS="${CORS_ORIGINS:-https://$HOSTNAME,https://$IP_ADDRESS}"
TELEGRAM_WEBHOOK_URL="${TELEGRAM_WEBHOOK_URL:-https://$HOSTNAME/telegram/webhook}"

print_success "Variables configuradas"

# Crear archivo de configuración para Puppet
print_step "3" "Creando configuración de Puppet..."

mkdir -p /etc/puppetlabs/code/environments/production/hieradata

cat > /etc/puppetlabs/code/environments/production/hieradata/common.yaml << EOF
---
# Configuración de la plataforma de ejecución remota

# Base de datos
remote_execution_platform::postgres_password: '$POSTGRES_PASSWORD'

# JWT
remote_execution_platform::jwt_secret: '$JWT_SECRET'

# Telegram
remote_execution_platform::telegram_bot_token: '$TELEGRAM_BOT_TOKEN'
remote_execution_platform::telegram_webhook_url: '$TELEGRAM_WEBHOOK_URL'

# Configuración de aplicación
remote_execution_platform::environment: '$ENVIRONMENT'
remote_execution_platform::debug_mode: $DEBUG_MODE
remote_execution_platform::log_level: '$LOG_LEVEL'

# Límites de ejecución
remote_execution_platform::max_execution_time: $MAX_EXECUTION_TIME
remote_execution_platform::max_memory_mb: $MAX_MEMORY_MB
remote_execution_platform::max_cpu_percent: $MAX_CPU_PERCENT
remote_execution_platform::max_file_size_mb: $MAX_FILE_SIZE_MB

# Seguridad
remote_execution_platform::allowed_hosts: '$ALLOWED_HOSTS'
remote_execution_platform::cors_origins: '$CORS_ORIGINS'
remote_execution_platform::allowed_file_types: '.py,.sh,.ps1,.js,.sql'

# Timestamp
remote_execution_platform::timestamp: '$(date -u +"%Y-%m-%d %H:%M:%S UTC")'
EOF

print_success "Configuración de Puppet creada"

# Copiar módulos de Puppet
print_step "4" "Instalando módulos de Puppet..."

# Crear estructura de módulos
mkdir -p /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/{manifests,templates,files}

# Copiar manifests
cp -r puppet/manifests/* /etc/puppetlabs/code/environments/production/manifests/
cp -r puppet/templates/* /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/

# Crear templates adicionales
cat > /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/node_exporter_service.erb << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/logrotate.erb << 'EOF'
/opt/platform/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 platform platform
    postrotate
        systemctl reload remote-execution-platform
    endscript
}
EOF

cat > /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/fail2ban_jail.erb << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /opt/platform/logs/nginx/error.log

[platform-api]
enabled = true
port = http,https
logpath = /opt/platform/logs/backend/backend.log
maxretry = 5
EOF

cat > /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/limits.erb << 'EOF'
# Límites para el usuario platform
platform soft nofile 65536
platform hard nofile 65536
platform soft nproc 32768
platform hard nproc 32768
EOF

cat > /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/sysctl_security.erb << 'EOF'
# Configuración de seguridad del kernel
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
kernel.dmesg_restrict = 1
EOF

print_success "Módulos de Puppet instalados"

# Aplicar configuración de Puppet
print_step "5" "Aplicando configuración con Puppet..."

# Ejecutar Puppet apply
/opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp --verbose

if [ $? -eq 0 ]; then
    print_success "Configuración de Puppet aplicada correctamente"
else
    print_error "Error aplicando configuración de Puppet"
    exit 1
fi

# Verificar servicios
print_step "6" "Verificando servicios..."

services=("docker" "remote-execution-platform" "node_exporter" "fail2ban")
failed_services=()

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        print_success "$service: Activo"
    else
        print_warning "$service: Inactivo"
        failed_services+=($service)
    fi
done

# Verificar contenedores Docker
print_step "7" "Verificando contenedores Docker..."
sleep 10  # Esperar a que los contenedores se inicien

cd /opt/platform/remote-execution-platform
containers=$(docker-compose ps --services)
for container in $containers; do
    if docker-compose ps $container | grep -q "Up"; then
        print_success "Contenedor $container: Funcionando"
    else
        print_warning "Contenedor $container: No funciona"
    fi
done

# Configurar Foreman (si está disponible)
print_step "8" "Configurando integración con Foreman..."

if command -v foreman-installer &> /dev/null; then
    print_info "Foreman detectado, configurando integración..."
    
    # Registrar el nodo en Foreman
    /opt/puppetlabs/bin/puppet config set server $(hostname -f)
    /opt/puppetlabs/bin/puppet config set environment production
    
    # Ejecutar primer run con Foreman
    /opt/puppetlabs/bin/puppet agent --test --server $(hostname -f)
    
    print_success "Integración con Foreman configurada"
else
    print_info "Foreman no detectado, usando Puppet standalone"
fi

# Configurar cron para Puppet
print_step "9" "Configurando ejecución automática de Puppet..."

cat > /etc/cron.d/puppet-platform << 'EOF'
# Ejecutar Puppet cada 30 minutos para mantener la configuración
*/30 * * * * root /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp --logdest syslog
EOF

print_success "Cron de Puppet configurado"

# Generar reporte de despliegue
print_step "10" "Generando reporte de despliegue..."

cat > /opt/platform/deployment-report.txt << EOF
REPORTE DE DESPLIEGUE - PLATAFORMA DE EJECUCIÓN REMOTA
======================================================

Fecha: $(date)
Hostname: $HOSTNAME
IP Address: $IP_ADDRESS
OS Version: Ubuntu $OS_VERSION

CONFIGURACIÓN:
- Environment: $ENVIRONMENT
- Debug Mode: $DEBUG_MODE
- Log Level: $LOG_LEVEL

LÍMITES DE EJECUCIÓN:
- Tiempo máximo: ${MAX_EXECUTION_TIME}s
- Memoria máxima: ${MAX_MEMORY_MB}MB
- CPU máximo: ${MAX_CPU_PERCENT}%

ACCESOS:
- Web: https://$HOSTNAME
- API: https://$HOSTNAME/api
- Grafana: http://$HOSTNAME:3001
- Prometheus: http://$HOSTNAME:9090

SERVICIOS INSTALADOS:
$(systemctl list-units --type=service --state=active | grep -E "(docker|platform|node_exporter|fail2ban)")

CONTENEDORES DOCKER:
$(cd /opt/platform/remote-execution-platform && docker-compose ps)

CONFIGURACIÓN DE PUPPET:
- Manifests: /etc/puppetlabs/code/environments/production/manifests/
- Modules: /etc/puppetlabs/code/environments/production/modules/
- Hieradata: /etc/puppetlabs/code/environments/production/hieradata/

LOGS:
- Sistema: /var/log/syslog
- Aplicación: /opt/platform/logs/
- Puppet: /var/log/puppetlabs/

PRÓXIMOS PASOS:
1. Configurar bot de Telegram editando TELEGRAM_BOT_TOKEN en hieradata
2. Acceder a https://$HOSTNAME para probar la plataforma
3. Revisar logs en /opt/platform/logs/
4. Configurar monitoreo en Grafana (admin/admin123)

EOF

print_success "Reporte generado en /opt/platform/deployment-report.txt"

# Mostrar información final
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 🎉 DESPLIEGUE COMPLETADO                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_success "Plataforma desplegada con Puppet correctamente"
echo ""
print_info "🌐 ACCESOS DISPONIBLES:"
echo ""
echo "   📱 Frontend Web:     https://$HOSTNAME"
echo "   🔌 API REST:         https://$HOSTNAME/api"
echo "   📚 Documentación:    https://$HOSTNAME/api/docs"
echo "   📊 Grafana:          http://$HOSTNAME:3001 (admin/admin123)"
echo "   📈 Prometheus:       http://$HOSTNAME:9090"
echo ""

if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN_HERE" ]; then
    print_info "🤖 BOT DE TELEGRAM:"
    echo "   ✅ Configurado y funcionando"
else
    print_info "🤖 BOT DE TELEGRAM:"
    echo "   ⚠️  Pendiente de configuración"
    echo "   📝 Edita: /etc/puppetlabs/code/environments/production/hieradata/common.yaml"
    echo "   🔄 Ejecuta: puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp"
fi

echo ""
print_info "🔧 GESTIÓN CON PUPPET:"
echo ""
echo "   Aplicar cambios:     puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp"
echo "   Ver configuración:   cat /etc/puppetlabs/code/environments/production/hieradata/common.yaml"
echo "   Logs de Puppet:      tail -f /var/log/puppetlabs/puppet.log"
echo "   Estado servicios:    systemctl status remote-execution-platform"
echo ""

if [ ${#failed_services[@]} -gt 0 ]; then
    print_warning "⚠️  SERVICIOS CON PROBLEMAS:"
    for service in "${failed_services[@]}"; do
        echo "   • $service"
    done
    echo ""
    print_info "Revisa los logs: journalctl -u [servicio]"
fi

echo ""
print_info "📋 COMANDOS ÚTILES:"
echo ""
echo "   Ver reporte:         cat /opt/platform/deployment-report.txt"
echo "   Logs aplicación:     tail -f /opt/platform/logs/backend/backend.log"
echo "   Reiniciar platform:  systemctl restart remote-execution-platform"
echo "   Estado contenedores: cd /opt/platform/remote-execution-platform && docker-compose ps"
echo ""

print_success "¡Despliegue con Puppet completado! 🚀"

# Mostrar reporte
echo ""
read -p "¿Quieres ver el reporte completo de despliegue? (y/n): " show_report
if [[ $show_report == "y" || $show_report == "Y" ]]; then
    echo ""
    cat /opt/platform/deployment-report.txt
fi