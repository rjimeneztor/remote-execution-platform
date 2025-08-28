# Manifest principal de Puppet para la plataforma de ejecución remota

# Configuración global
Exec {
  path => ['/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin']
}

# Nodo por defecto
node default {
  include remote_execution_platform
}

# Clase principal de la plataforma
class remote_execution_platform {
  
  # Incluir clases base
  include remote_execution_platform::base
  include remote_execution_platform::docker
  include remote_execution_platform::application
  include remote_execution_platform::monitoring
  include remote_execution_platform::security
  
  # Orden de aplicación
  Class['remote_execution_platform::base'] ->
  Class['remote_execution_platform::docker'] ->
  Class['remote_execution_platform::application'] ->
  Class['remote_execution_platform::monitoring'] ->
  Class['remote_execution_platform::security']
}

# Configuración base del sistema
class remote_execution_platform::base {
  
  # Actualizar sistema
  exec { 'apt_update':
    command => 'apt-get update',
    unless  => 'test $(find /var/lib/apt/lists -maxdepth 1 -type f -mmin -60 | wc -l) -gt 0',
  }
  
  # Paquetes base necesarios
  $base_packages = [
    'curl',
    'wget',
    'git',
    'vim',
    'htop',
    'unzip',
    'software-properties-common',
    'apt-transport-https',
    'ca-certificates',
    'gnupg',
    'lsb-release',
    'python3',
    'python3-pip',
    'nodejs',
    'npm'
  ]
  
  package { $base_packages:
    ensure  => installed,
    require => Exec['apt_update'],
  }
  
  # Usuario para la aplicación
  user { 'platform':
    ensure     => present,
    home       => '/opt/platform',
    shell      => '/bin/bash',
    managehome => true,
    system     => true,
  }
  
  # Directorio base de la aplicación
  file { '/opt/platform':
    ensure  => directory,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => User['platform'],
  }
  
  # Configurar timezone
  file { '/etc/timezone':
    ensure  => file,
    content => "UTC\n",
    notify  => Exec['reconfigure_tzdata'],
  }
  
  exec { 'reconfigure_tzdata':
    command     => 'dpkg-reconfigure -f noninteractive tzdata',
    refreshonly => true,
  }
}

# Configuración de Docker
class remote_execution_platform::docker {
  
  # Añadir repositorio de Docker
  exec { 'add_docker_gpg_key':
    command => 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg',
    creates => '/usr/share/keyrings/docker-archive-keyring.gpg',
  }
  
  file { '/etc/apt/sources.list.d/docker.list':
    ensure  => file,
    content => "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable\n",
    require => Exec['add_docker_gpg_key'],
    notify  => Exec['apt_update_docker'],
  }
  
  exec { 'apt_update_docker':
    command     => 'apt-get update',
    refreshonly => true,
  }
  
  # Instalar Docker
  package { ['docker-ce', 'docker-ce-cli', 'containerd.io']:
    ensure  => installed,
    require => [File['/etc/apt/sources.list.d/docker.list'], Exec['apt_update_docker']],
  }
  
  # Configuración del daemon de Docker
  file { '/etc/docker/daemon.json':
    ensure  => file,
    content => template('remote_execution_platform/docker_daemon.erb'),
    notify  => Service['docker'],
    require => Package['docker-ce'],
  }
  
  # Instalar Docker Compose
  exec { 'install_docker_compose':
    command => 'curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose',
    creates => '/usr/local/bin/docker-compose',
    require => Package['curl'],
  }
  
  # Iniciar y habilitar Docker
  service { 'docker':
    ensure  => running,
    enable  => true,
    require => Package['docker-ce'],
  }
  
  # Añadir usuario platform al grupo docker
  exec { 'add_platform_to_docker_group':
    command => 'usermod -aG docker platform',
    unless  => 'groups platform | grep -q docker',
    require => [User['platform'], Package['docker-ce']],
  }
}

# Configuración de la aplicación
class remote_execution_platform::application {
  
  # Directorio de la aplicación
  file { '/opt/platform/remote-execution-platform':
    ensure  => directory,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => File['/opt/platform'],
  }
  
  # Clonar repositorio (en producción usar un método más seguro)
  exec { 'clone_application':
    command => 'git clone https://github.com/your-repo/remote-execution-platform.git /opt/platform/remote-execution-platform',
    creates => '/opt/platform/remote-execution-platform/.git',
    user    => 'platform',
    require => [Package['git'], File['/opt/platform/remote-execution-platform']],
  }
  
  # Archivo de configuración
  file { '/opt/platform/remote-execution-platform/.env':
    ensure  => file,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0600',
    content => template('remote_execution_platform/env.erb'),
    require => Exec['clone_application'],
  }
  
  # Scripts ejecutables
  file { ['/opt/platform/remote-execution-platform/install.sh',
          '/opt/platform/remote-execution-platform/build.sh',
          '/opt/platform/remote-execution-platform/start.sh']:
    ensure  => file,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => Exec['clone_application'],
  }
  
  # Directorios de datos
  file { ['/opt/platform/data',
          '/opt/platform/logs',
          '/opt/platform/ssl']:
    ensure  => directory,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => File['/opt/platform'],
  }
  
  # Generar certificados SSL
  exec { 'generate_ssl_certificates':
    command => 'openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /opt/platform/ssl/private.key -out /opt/platform/ssl/certificate.crt -subj "/C=ES/ST=Madrid/L=Madrid/O=RemoteExecution/CN=localhost"',
    creates => '/opt/platform/ssl/certificate.crt',
    user    => 'platform',
    require => [Package['openssl'], File['/opt/platform/ssl']],
  }
  
  # Servicio systemd para la aplicación
  file { '/etc/systemd/system/remote-execution-platform.service':
    ensure  => file,
    content => template('remote_execution_platform/systemd_service.erb'),
    notify  => [Exec['systemd_reload'], Service['remote-execution-platform']],
  }
  
  exec { 'systemd_reload':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }
  
  service { 'remote-execution-platform':
    ensure  => running,
    enable  => true,
    require => [File['/etc/systemd/system/remote-execution-platform.service'], 
                Class['remote_execution_platform::docker']],
  }
}

# Configuración de monitoreo
class remote_execution_platform::monitoring {
  
  # Instalar Node Exporter para métricas del sistema
  exec { 'download_node_exporter':
    command => 'wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz',
    creates => '/tmp/node_exporter.tar.gz',
    require => Package['wget'],
  }
  
  exec { 'extract_node_exporter':
    command => 'tar -xzf /tmp/node_exporter.tar.gz -C /tmp/ && mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/',
    creates => '/usr/local/bin/node_exporter',
    require => Exec['download_node_exporter'],
  }
  
  # Usuario para Node Exporter
  user { 'node_exporter':
    ensure => present,
    system => true,
    shell  => '/bin/false',
    home   => '/nonexistent',
  }
  
  # Servicio Node Exporter
  file { '/etc/systemd/system/node_exporter.service':
    ensure  => file,
    content => template('remote_execution_platform/node_exporter_service.erb'),
    notify  => [Exec['systemd_reload_monitoring'], Service['node_exporter']],
  }
  
  exec { 'systemd_reload_monitoring':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }
  
  service { 'node_exporter':
    ensure  => running,
    enable  => true,
    require => [File['/etc/systemd/system/node_exporter.service'], User['node_exporter']],
  }
  
  # Configurar logrotate para logs de la aplicación
  file { '/etc/logrotate.d/remote-execution-platform':
    ensure  => file,
    content => template('remote_execution_platform/logrotate.erb'),
  }
  
  # Script de backup automático
  file { '/opt/platform/scripts/backup.sh':
    ensure  => file,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    content => template('remote_execution_platform/backup_script.erb'),
    require => File['/opt/platform'],
  }
  
  # Script de monitoreo de salud
  file { '/opt/platform/scripts/health-check.sh':
    ensure  => file,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    content => template('remote_execution_platform/monitoring_script.erb'),
    require => File['/opt/platform'],
  }
  
  # Directorio de scripts
  file { '/opt/platform/scripts':
    ensure  => directory,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => File['/opt/platform'],
  }
  
  # Directorio de backups
  file { '/opt/platform/backups':
    ensure  => directory,
    owner   => 'platform',
    group   => 'platform',
    mode    => '0755',
    require => File['/opt/platform'],
  }
  
  # Cron para backup diario
  cron { 'platform_daily_backup':
    command => '/opt/platform/scripts/backup.sh >> /opt/platform/logs/backup.log 2>&1',
    user    => 'platform',
    hour    => '2',
    minute  => '30',
    require => File['/opt/platform/scripts/backup.sh'],
  }
  
  # Cron para monitoreo cada 5 minutos
  cron { 'platform_health_check':
    command => '/opt/platform/scripts/health-check.sh',
    user    => 'platform',
    minute  => '*/5',
    require => File['/opt/platform/scripts/health-check.sh'],
  }
}

# Configuración de seguridad
class remote_execution_platform::security {
  
  # Configurar firewall básico
  package { 'ufw':
    ensure => installed,
  }
  
  # Reglas de firewall
  exec { 'ufw_default_deny':
    command => 'ufw --force default deny incoming',
    unless  => 'ufw status | grep -q "Default: deny (incoming)"',
    require => Package['ufw'],
  }
  
  exec { 'ufw_default_allow_outgoing':
    command => 'ufw --force default allow outgoing',
    unless  => 'ufw status | grep -q "Default: allow (outgoing)"',
    require => Package['ufw'],
  }
  
  # Permitir SSH
  exec { 'ufw_allow_ssh':
    command => 'ufw --force allow ssh',
    unless  => 'ufw status | grep -q "22/tcp"',
    require => Exec['ufw_default_deny'],
  }
  
  # Permitir HTTP y HTTPS
  exec { 'ufw_allow_http':
    command => 'ufw --force allow http',
    unless  => 'ufw status | grep -q "80/tcp"',
    require => Exec['ufw_default_deny'],
  }
  
  exec { 'ufw_allow_https':
    command => 'ufw --force allow https',
    unless  => 'ufw status | grep -q "443/tcp"',
    require => Exec['ufw_default_deny'],
  }
  
  # Habilitar firewall
  exec { 'ufw_enable':
    command => 'ufw --force enable',
    unless  => 'ufw status | grep -q "Status: active"',
    require => [Exec['ufw_allow_ssh'], Exec['ufw_allow_http'], Exec['ufw_allow_https']],
  }
  
  # Configurar fail2ban
  package { 'fail2ban':
    ensure => installed,
  }
  
  service { 'fail2ban':
    ensure  => running,
    enable  => true,
    require => Package['fail2ban'],
  }
  
  # Configuración personalizada de fail2ban
  file { '/etc/fail2ban/jail.local':
    ensure  => file,
    content => template('remote_execution_platform/fail2ban_jail.erb'),
    notify  => Service['fail2ban'],
    require => Package['fail2ban'],
  }
  
  # Configurar límites del sistema
  file { '/etc/security/limits.d/platform.conf':
    ensure  => file,
    content => template('remote_execution_platform/limits.erb'),
  }
  
  # Configurar sysctl para seguridad
  file { '/etc/sysctl.d/99-platform-security.conf':
    ensure  => file,
    content => template('remote_execution_platform/sysctl_security.erb'),
    notify  => Exec['sysctl_reload'],
  }
  
  exec { 'sysctl_reload':
    command     => 'sysctl -p /etc/sysctl.d/99-platform-security.conf',
    refreshonly => true,
  }
}