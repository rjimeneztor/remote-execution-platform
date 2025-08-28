#!/bin/bash

# Script de despliegue completo para la plataforma de ejecución remota
# Integra Puppet, Docker, y todas las configuraciones necesarias

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_banner() {
    echo -e "${PURPLE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 DESPLIEGUE COMPLETO - PLATAFORMA EJECUCIÓN REMOTA     ║
║                                                              ║
║    🎭 Puppet + Docker + Foreman                              ║
║    🌐 Web + API + Telegram Bot                               ║
║    📊 Monitoreo + Backup + Seguridad                         ║
║    🔒 Ejecución sandboxeada y segura                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Verificar que estamos ejecutando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root o con sudo"
        exit 1
    fi
}

# Detectar información del sistema
detect_system() {
    print_step "1" "Detectando información del sistema..."
    
    HOSTNAME=$(hostname -f)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "No se pudo detectar el sistema operativo"
        exit 1
    fi
    
    if [[ $OS_NAME != "ubuntu" ]]; then
        print_warning "Sistema detectado: $OS_NAME $OS_VERSION (no es Ubuntu)"
        read -p "¿Continuar de todos modos? (y/n): " continue_anyway
        if [[ $continue_anyway != "y" && $continue_anyway != "Y" ]]; then
            exit 1
        fi
    fi
    
    print_success "Sistema: $OS_NAME $OS_VERSION"
    print_success "Hostname: $HOSTNAME"
    print_success "IP: $IP_ADDRESS"
}

# Configurar variables de entorno
setup_environment() {
    print_step "2" "Configurando variables de entorno..."
    
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
    CORS_ORIGINS="${CORS_ORIGINS:-https://$HOSTNAME,https://$IP_ADDRESS,https://localhost}"
    TELEGRAM_WEBHOOK_URL="${TELEGRAM_WEBHOOK_URL:-https://$HOSTNAME/telegram/webhook}"
    
    # Email para alertas
    ALERT_EMAIL="${ALERT_EMAIL:-admin@$HOSTNAME}"
    
    print_success "Variables configuradas"
}

# Instalar dependencias base
install_dependencies() {
    print_step "3" "Instalando dependencias base..."
    
    # Actualizar sistema
    apt update && apt upgrade -y
    
    # Instalar paquetes esenciales
    apt install -y \
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
        nodejs \
        npm \
        openssl \
        bc \
        mailutils \
        logrotate \
        cron
    
    print_success "Dependencias base instaladas"
}

# Instalar y configurar Puppet
install_puppet() {
    print_step "4" "Instalando Puppet..."
    
    if ! command -v puppet &> /dev/null; then
        # Descargar e instalar Puppet
        wget https://apt.puppetlabs.com/puppet7-release-$(lsb_release -cs).deb
        dpkg -i puppet7-release-$(lsb_release -cs).deb
        apt update
        apt install -y puppet-agent
        
        # Añadir Puppet al PATH
        echo 'export PATH="/opt/puppetlabs/bin:$PATH"' >> /root/.bashrc
        export PATH="/opt/puppetlabs/bin:$PATH"
        
        print_success "Puppet instalado"
    else
        print_success "Puppet ya está instalado"
    fi
    
    # Crear estructura de directorios
    mkdir -p /etc/puppetlabs/code/environments/production/{manifests,modules,hieradata}
    mkdir -p /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/{manifests,templates,files}
}

# Configurar Puppet con nuestros manifests
configure_puppet() {
    print_step "5" "Configurando Puppet..."
    
    # Copiar manifests
    cp -r puppet/manifests/* /etc/puppetlabs/code/environments/production/manifests/
    cp -r puppet/templates/* /etc/puppetlabs/code/environments/production/modules/remote_execution_platform/templates/
    
    # Crear hieradata con nuestras variables
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

# Alertas
remote_execution_platform::alert_email: '$ALERT_EMAIL'

# Timestamp
remote_execution_platform::timestamp: '$(date -u +"%Y-%m-%d %H:%M:%S UTC")'
EOF
    
    print_success "Configuración de Puppet creada"
}

# Aplicar configuración de Puppet
apply_puppet() {
    print_step "6" "Aplicando configuración con Puppet..."
    
    # Ejecutar Puppet apply
    /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp --verbose --detailed-exitcodes
    
    puppet_exit_code=$?
    
    case $puppet_exit_code in
        0)
            print_success "Puppet aplicado correctamente - Sin cambios"
            ;;
        2)
            print_success "Puppet aplicado correctamente - Cambios realizados"
            ;;
        *)
            print_error "Error aplicando Puppet (código: $puppet_exit_code)"
            print_info "Revisa los logs: /var/log/puppetlabs/puppet.log"
            exit 1
            ;;
    esac
}

# Configurar aplicación específica
setup_application() {
    print_step "7" "Configurando aplicación..."
    
    # Cambiar al directorio de la aplicación
    cd /opt/platform/remote-execution-platform || {
        print_error "Directorio de aplicación no encontrado"
        exit 1
    }
    
    # Copiar archivos de configuración si no existen
    if [ ! -f "docker-compose.yml" ]; then
        print_info "Copiando archivos de configuración..."
        cp -r ../../../remote-execution-platform/* . 2>/dev/null || true
    fi
    
    # Asegurar permisos correctos
    chown -R platform:platform /opt/platform/
    chmod +x /opt/platform/remote-execution-platform/*.sh 2>/dev/null || true
    
    print_success "Aplicación configurada"
}

# Construir e iniciar servicios
build_and_start() {
    print_step "8" "Construyendo e iniciando servicios..."
    
    cd /opt/platform/remote-execution-platform
    
    # Construir imágenes como usuario platform
    sudo -u platform bash -c "
        cd /opt/platform/remote-execution-platform
        if [ -f 'build.sh' ]; then
            ./build.sh
        else
            docker-compose build --no-cache
        fi
    "
    
    if [ $? -eq 0 ]; then
        print_success "Imágenes construidas correctamente"
    else
        print_error "Error construyendo imágenes"
        exit 1
    fi
    
    # Iniciar servicios a través de systemd
    systemctl start remote-execution-platform
    systemctl enable remote-execution-platform
    
    print_success "Servicios iniciados"
}

# Verificar servicios
verify_services() {
    print_step "9" "Verificando servicios..."
    
    # Esperar a que los servicios se inicien
    sleep 30
    
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
    cd /opt/platform/remote-execution-platform
    containers=$(docker-compose ps --services 2>/dev/null || echo "")
    
    if [ -n "$containers" ]; then
        for container in $containers; do
            if docker-compose ps $container 2>/dev/null | grep -q "Up"; then
                print_success "Contenedor $container: Funcionando"
            else
                print_warning "Contenedor $container: No funciona"
            fi
        done
    fi
    
    return ${#failed_services[@]}
}

# Configurar Foreman (opcional)
setup_foreman() {
    print_step "10" "Configurando Foreman (opcional)..."
    
    read -p "¿Quieres instalar Foreman para gestión centralizada? (y/n): " install_foreman
    
    if [[ $install_foreman == "y" || $install_foreman == "Y" ]]; then
        print_info "Instalando Foreman..."
        
        # Instalar Foreman
        echo "deb http://deb.theforeman.org/ $(lsb_release -cs) 3.4" > /etc/apt/sources.list.d/foreman.list
        wget -q https://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
        apt update
        apt install -y foreman-installer
        
        # Configurar Foreman
        foreman-installer \
            --enable-foreman \
            --enable-foreman-cli \
            --enable-puppet \
            --puppet-server=true \
            --puppet-server-foreman-url=https://$HOSTNAME \
            --foreman-initial-admin-password=admin123
        
        # Registrar el nodo
        /opt/puppetlabs/bin/puppet config set server $HOSTNAME
        /opt/puppetlabs/bin/puppet config set environment production
        
        print_success "Foreman instalado y configurado"
        print_info "Acceso: https://$HOSTNAME (admin/admin123)"
    else
        print_info "Saltando instalación de Foreman"
    fi
}

# Configurar cron para Puppet
setup_puppet_cron() {
    print_step "11" "Configurando ejecución automática de Puppet..."
    
    cat > /etc/cron.d/puppet-platform << 'EOF'
# Ejecutar Puppet cada 30 minutos para mantener la configuración
*/30 * * * * root /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp --logdest syslog >/dev/null 2>&1
EOF
    
    print_success "Cron de Puppet configurado"
}

# Generar reporte final
generate_report() {
    print_step "12" "Generando reporte de despliegue..."
    
    cat > /opt/platform/deployment-report.txt << EOF
REPORTE DE DESPLIEGUE - PLATAFORMA DE EJECUCIÓN REMOTA
======================================================

Fecha: $(date)
Hostname: $HOSTNAME
IP Address: $IP_ADDRESS
OS Version: $OS_NAME $OS_VERSION

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
- Documentación: https://$HOSTNAME/api/docs
- Grafana: http://$HOSTNAME:3001 (admin/admin123)
- Prometheus: http://$HOSTNAME:9090

SERVICIOS INSTALADOS:
$(systemctl list-units --type=service --state=active | grep -E "(docker|platform|node_exporter|fail2ban)" || echo "No se pudieron listar servicios")

CONTENEDORES DOCKER:
$(cd /opt/platform/remote-execution-platform && docker-compose ps 2>/dev/null || echo "No se pudieron listar contenedores")

CONFIGURACIÓN DE PUPPET:
- Manifests: /etc/puppetlabs/code/environments/production/manifests/
- Modules: /etc/puppetlabs/code/environments/production/modules/
- Hieradata: /etc/puppetlabs/code/environments/production/hieradata/

SCRIPTS DE GESTIÓN:
- Backup: /opt/platform/scripts/backup.sh
- Monitoreo: /opt/platform/scripts/health-check.sh
- Logs: /opt/platform/logs/

LOGS:
- Sistema: /var/log/syslog
- Aplicación: /opt/platform/logs/
- Puppet: /var/log/puppetlabs/

PRÓXIMOS PASOS:
1. Configurar bot de Telegram editando TELEGRAM_BOT_TOKEN en hieradata
2. Acceder a https://$HOSTNAME para probar la plataforma
3. Revisar logs en /opt/platform/logs/
4. Configurar monitoreo en Grafana (admin/admin123)

COMANDOS ÚTILES:
- Aplicar Puppet: puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp
- Ver logs: tail -f /opt/platform/logs/backend/backend.log
- Reiniciar: systemctl restart remote-execution-platform
- Estado: systemctl status remote-execution-platform
- Backup manual: /opt/platform/scripts/backup.sh
- Check salud: /opt/platform/scripts/health-check.sh

EOF
    
    print_success "Reporte generado en /opt/platform/deployment-report.txt"
}

# Función principal
main() {
    print_banner
    
    check_root
    detect_system
    setup_environment
    install_dependencies
    install_puppet
    configure_puppet
    apply_puppet
    setup_application
    build_and_start
    
    if verify_services; then
        print_success "Todos los servicios están funcionando"
    else
        print_warning "Algunos servicios tienen problemas"
    fi
    
    setup_foreman
    setup_puppet_cron
    generate_report
    
    # Mostrar información final
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 🎉 DESPLIEGUE COMPLETADO                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_success "Plataforma desplegada correctamente"
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
    
    echo ""
    print_info "📋 COMANDOS ÚTILES:"
    echo ""
    echo "   Ver reporte:         cat /opt/platform/deployment-report.txt"
    echo "   Logs aplicación:     tail -f /opt/platform/logs/backend/backend.log"
    echo "   Reiniciar platform:  systemctl restart remote-execution-platform"
    echo "   Estado contenedores: cd /opt/platform/remote-execution-platform && docker-compose ps"
    echo "   Backup manual:       /opt/platform/scripts/backup.sh"
    echo "   Check de salud:      /opt/platform/scripts/health-check.sh"
    echo ""
    
    print_success "¡Despliegue completado! 🚀"
    
    # Mostrar reporte
    echo ""
    read -p "¿Quieres ver el reporte completo de despliegue? (y/n): " show_report
    if [[ $show_report == "y" || $show_report == "Y" ]]; then
        echo ""
        cat /opt/platform/deployment-report.txt
    fi
}

# Ejecutar función principal
main "$@"