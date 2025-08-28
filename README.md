# 🚀 Plataforma de Ejecución Remota

## 📋 Descripción

Plataforma web interactiva que permite a usuarios autenticados ejecutar scripts remotamente desde una interfaz web y un bot de Telegram integrado, completamente contenerizada con Docker y orquestada mediante Puppet Foreman para automatización y gestión centralizada de la infraestructura.

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend Web  │    │  Bot Telegram   │    │   API Gateway   │
│   (React)       │    │   (Python)      │    │   (Nginx)       │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴───────────┐
                    │     Backend API         │
                    │   (FastAPI/Python)      │
                    └─────────────┬───────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
┌─────────┴───────┐    ┌─────────┴───────┐    ┌─────────┴───────┐
│   PostgreSQL    │    │  Code Executor  │    │  Notification   │
│   (Database)    │    │   (Sandboxed)   │    │    Service      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Componentes

- **Frontend Web**: Interfaz React con autenticación JWT y consola interactiva
- **Backend API**: API REST con FastAPI para gestión de usuarios y ejecución
- **Bot Telegram**: Bot integrado para ejecución remota y notificaciones
- **Code Executor**: Servicio de ejecución sandboxeada de código en contenedores
- **Database**: PostgreSQL para persistencia de datos y auditoría
- **Notification Service**: Sistema de notificaciones bidireccional
- **API Gateway**: Nginx como proxy reverso, balanceador y SSL termination
- **Monitoring**: Prometheus + Grafana + Node Exporter para métricas
- **Security**: Fail2ban, UFW, límites de recursos y sandboxing

## 🚀 Instalación

### Opción 1: Instalación Rápida (Recomendada)

```bash
# Clonar repositorio
git clone <repo>
cd remote-execution-platform

# Ejecutar instalador completo
sudo chmod +x install.sh
sudo ./install.sh

# Construir servicios
./build.sh

# Iniciar plataforma
./start.sh
```

### Opción 2: Despliegue con Puppet (Producción)

```bash
# Despliegue automatizado con Puppet
sudo chmod +x deploy-complete.sh
sudo ./deploy-complete.sh
```

### Opción 3: Despliegue con Puppet + Foreman

```bash
# Despliegue con gestión centralizada
sudo chmod +x deploy-with-puppet.sh
sudo ./deploy-with-puppet.sh
```

## ⚙️ Configuración

### Variables de Entorno (.env)

```bash
# Base de datos
POSTGRES_DB=remote_execution
POSTGRES_USER=platform_user
POSTGRES_PASSWORD=<generada_automáticamente>

# JWT
JWT_SECRET_KEY=<generada_automáticamente>
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=1440

# Telegram Bot
TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN_HERE
TELEGRAM_WEBHOOK_URL=https://your-domain.com/telegram/webhook

# Límites de ejecución
MAX_EXECUTION_TIME=300
MAX_MEMORY_MB=512
MAX_CPU_PERCENT=50
MAX_FILE_SIZE_MB=10

# Seguridad
ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com
CORS_ORIGINS=https://your-domain.com
```

### Configurar Bot de Telegram

1. Crear bot con [@BotFather](https://t.me/botfather)
2. Obtener token del bot
3. Editar `.env` con tu `TELEGRAM_BOT_TOKEN`
4. Reiniciar servicios: `docker-compose restart telegram-bot`

## 🔧 Uso

### Accesos Web

- **Frontend**: https://localhost
- **API Docs**: https://localhost/api/docs
- **Grafana**: http://localhost:3001 (admin/admin123)
- **Prometheus**: http://localhost:9090

### Bot de Telegram

Comandos disponibles:
- `/start` - Iniciar bot
- `/help` - Mostrar ayuda
- `/login` - Autenticarse
- `/execute <lenguaje> <código>` - Ejecutar código
- `/status` - Ver estado de ejecuciones
- `/profile` - Ver perfil de usuario

### Lenguajes Soportados

- 🐍 **Python** - `python print("Hello World")`
- 🐚 **Bash** - `bash echo "Hello World"`
- 💻 **PowerShell** - `powershell Write-Host "Hello World"`
- 🟨 **JavaScript** - `javascript console.log("Hello World")`
- 🗄️ **SQL** - `sql SELECT 'Hello World'`

## 🛡️ Seguridad

### Características de Seguridad

- **Sandboxing**: Ejecución en contenedores aislados
- **Límites de Recursos**: CPU, memoria y tiempo controlados
- **Autenticación JWT**: Tokens seguros con expiración
- **Firewall**: UFW configurado automáticamente
- **Fail2ban**: Protección contra ataques de fuerza bruta
- **SSL/TLS**: Certificados automáticos para HTTPS
- **Auditoría**: Logs completos de todas las operaciones

### Límites por Defecto

- Tiempo máximo de ejecución: 5 minutos
- Memoria máxima: 512MB
- CPU máximo: 50%
- Tamaño de archivo: 10MB
- Sin acceso a red externa desde código ejecutado

## 📊 Monitoreo

### Métricas Disponibles

- Número de ejecuciones por usuario
- Tiempo promedio de ejecución
- Uso de recursos del sistema
- Errores y fallos de seguridad
- Estado de servicios

### Dashboards Grafana

- **Sistema**: CPU, memoria, disco, red
- **Aplicación**: Requests, ejecuciones, usuarios activos
- **Seguridad**: Intentos de acceso, bloqueos fail2ban
- **Docker**: Estado de contenedores, recursos

## 🔄 Gestión con Puppet

### Comandos Útiles

```bash
# Aplicar configuración
puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp

# Ver configuración actual
cat /etc/puppetlabs/code/environments/production/hieradata/common.yaml

# Logs de Puppet
tail -f /var/log/puppetlabs/puppet.log

# Estado de servicios
systemctl status remote-execution-platform
```

### Actualizar Configuración

1. Editar hieradata: `/etc/puppetlabs/code/environments/production/hieradata/common.yaml`
2. Aplicar cambios: `puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp`
3. Verificar servicios: `systemctl status remote-execution-platform`

## 🔧 Mantenimiento

### Backup Automático

```bash
# Backup manual
/opt/platform/scripts/backup.sh

# Ver backups
ls -la /opt/platform/backups/

# Restaurar backup (manual)
# 1. Detener servicios
# 2. Restaurar base de datos desde backup
# 3. Restaurar configuración
# 4. Reiniciar servicios
```

### Monitoreo de Salud

```bash
# Check manual de salud
/opt/platform/scripts/health-check.sh

# Ver logs de salud
tail -f /opt/platform/logs/health-check.log

# Estado de contenedores
docker-compose ps
```

### Logs

```bash
# Logs de aplicación
tail -f /opt/platform/logs/backend/backend.log
tail -f /opt/platform/logs/telegram/telegram.log

# Logs de sistema
journalctl -u remote-execution-platform -f

# Logs de Docker
docker-compose logs -f [servicio]
```

## 🚨 Solución de Problemas

### Problemas Comunes

1. **Bot de Telegram no responde**
   - Verificar `TELEGRAM_BOT_TOKEN` en `.env`
   - Reiniciar: `docker-compose restart telegram-bot`

2. **API no accesible**
   - Verificar firewall: `ufw status`
   - Verificar contenedor: `docker-compose ps backend`

3. **Base de datos no conecta**
   - Verificar contenedor: `docker-compose ps postgres`
   - Ver logs: `docker-compose logs postgres`

4. **Certificados SSL**
   - Regenerar: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/private.key -out ssl/certificate.crt`

### Comandos de Diagnóstico

```bash
# Estado general
systemctl status remote-execution-platform

# Recursos del sistema
htop
df -h
free -h

# Red y puertos
netstat -tlnp
ufw status

# Docker
docker system df
docker-compose ps
docker-compose logs
```

## 🤝 Contribución

1. Fork del repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` para más detalles.

## 🆘 Soporte

- **Documentación**: Ver carpeta `docs/`
- **Issues**: Crear issue en GitHub
- **Email**: admin@platform.local
- **Telegram**: Contactar al administrador del bot

## 🔧 Tecnologías

- **Contenerización**: Docker & Docker Compose
- **Orquestación**: Puppet + Foreman (opcional)
- **Backend**: Python (FastAPI, SQLAlchemy, Redis)
- **Frontend**: React + Material-UI + Monaco Editor
- **Database**: PostgreSQL
- **Cache**: Redis
- **Proxy**: Nginx
- **Monitoring**: Prometheus + Grafana + Node Exporter
- **Security**: Fail2ban + UFW + SSL/TLS