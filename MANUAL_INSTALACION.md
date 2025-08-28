# � Manual de  Instalación y Uso - Plataforma de Ejecución Remota

## 📋 Tabla de Contenidos

1. [Requisitos del Sistema](#requisitos-del-sistema)
2. [Instalación](#instalación)
3. [Configuración](#configuración)
4. [Uso de la Plataforma](#uso-de-la-plataforma)
5. [Bot de Telegram](#bot-de-telegram)
6. [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
7. [Solución de Problemas](#solución-de-problemas)
8. [Comandos Útiles](#comandos-útiles)

---

## 🖥️ Requisitos del Sistema

### Requisitos Mínimos
- **OS**: Ubuntu 20.04 LTS o superior
- **RAM**: 4GB mínimo, 8GB recomendado
- **CPU**: 2 cores mínimo, 4 cores recomendado
- **Disco**: 20GB libres mínimo, 50GB recomendado
- **Red**: Conexión a internet estable

### Requisitos de Software
- **Docker**: 20.10 o superior
- **Docker Compose**: 2.0 o superior
- **Puppet**: 7.x (se instala automáticamente)
- **Git**: Para clonar el repositorio
- **OpenSSL**: Para certificados SSL

### Puertos Requeridos
- **80**: HTTP (redirige a HTTPS)
- **443**: HTTPS (Frontend y API)
- **3001**: Grafana Dashboard
- **9090**: Prometheus Metrics
- **5432**: PostgreSQL (interno)
- **6379**: Redis (interno)
- **8000**: Backend API (interno)

---

## 🚀 Instalación

### Opción 1: Instalación Automática Completa (Recomendada)

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/remote-execution-platform.git
cd remote-execution-platform

# 2. Hacer ejecutables los scripts
sudo chmod +x *.sh

# 3. Ejecutar instalación completa
sudo ./deploy-complete.sh
```

**¿Qué hace este script?**
- Instala todas las dependencias (Docker, Puppet, etc.)
- Configura el sistema operativo
- Despliega todos los servicios
- Configura seguridad (firewall, fail2ban)
- Instala monitoreo (Prometheus, Grafana)
- Configura backups automáticos

### Opción 2: Instalación Paso a Paso

#### Paso 1: Preparar el Sistema
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias base
sudo ./install.sh
```

#### Paso 2: Construir Servicios
```bash
# Construir imágenes Docker
./build.sh
```

#### Paso 3: Iniciar Plataforma
```bash
# Iniciar todos los servicios
./start.sh
```

### Opción 3: Solo con Puppet
```bash
# Despliegue usando Puppet
sudo ./deploy-with-puppet.sh
```

---

## ⚙️ Configuración

### Configuración Básica

#### 1. Variables de Entorno (.env)

El archivo `.env` se genera automáticamente, pero puedes personalizarlo:

```bash
# Editar configuración
nano /opt/platform/remote-execution-platform/.env
```

**Variables importantes:**
```bash
# Bot de Telegram (OBLIGATORIO para bot)
TELEGRAM_BOT_TOKEN=tu_token_aqui

# Dominio (cambiar por tu dominio real)
ALLOWED_HOSTS=localhost,127.0.0.1,tu-dominio.com
CORS_ORIGINS=https://tu-dominio.com

# Límites de ejecución
MAX_EXECUTION_TIME=300        # 5 minutos máximo
MAX_MEMORY_MB=512            # 512MB máximo
MAX_CPU_PERCENT=50           # 50% CPU máximo
MAX_FILE_SIZE_MB=10          # 10MB archivos máximo

# Email para alertas
ALERT_EMAIL=admin@tu-dominio.com
```

#### 2. Configurar Bot de Telegram

**Crear Bot:**
1. Abrir Telegram y buscar [@BotFather](https://t.me/botfather)
2. Enviar `/newbot`
3. Seguir instrucciones para crear el bot
4. Copiar el token que te proporciona

**Configurar Token:**
```bash
# Editar archivo de configuración
sudo nano /opt/platform/remote-execution-platform/.env

# Cambiar esta línea:
TELEGRAM_BOT_TOKEN=tu_token_real_aqui

# Reiniciar bot
sudo systemctl restart remote-execution-platform
# O usando Docker Compose:
cd /opt/platform/remote-execution-platform
docker-compose restart telegram-bot
```

#### 3. Configurar SSL/HTTPS

**Certificados Autofirmados (por defecto):**
Los certificados se generan automáticamente para `localhost`.

**Certificados Reales (Let's Encrypt):**
```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obtener certificado (cambiar tu-dominio.com)
sudo certbot --nginx -d tu-dominio.com

# Copiar certificados a la plataforma
sudo cp /etc/letsencrypt/live/tu-dominio.com/fullchain.pem /opt/platform/ssl/certificate.crt
sudo cp /etc/letsencrypt/live/tu-dominio.com/privkey.pem /opt/platform/ssl/private.key

# Reiniciar nginx
docker-compose restart nginx
```

---

## 🌐 Uso de la Plataforma

### Acceso Web

#### 1. Abrir la Plataforma
```
URL: https://localhost (o tu dominio)
```

#### 2. Registro/Login
- **Usuario por defecto**: `admin`
- **Contraseña por defecto**: `admin123`

#### 3. Interfaz Principal

**Dashboard:**
- Vista general de ejecuciones
- Estadísticas de uso
- Estado del sistema

**Editor de Código:**
- Editor Monaco (como VS Code)
- Syntax highlighting
- Autocompletado básico

**Consola de Ejecución:**
- Salida en tiempo real
- Logs de error
- Tiempo de ejecución

### Ejecutar Código

#### Desde la Web

1. **Seleccionar Lenguaje:**
   - Python 🐍
   - Bash 🐚
   - PowerShell 💻
   - JavaScript 🟨
   - SQL 🗄️

2. **Escribir Código:**
```python
# Ejemplo Python
print("¡Hola desde la plataforma!")
import datetime
print(f"Fecha actual: {datetime.datetime.now()}")

# Ejemplo con librerías
import requests
# Nota: Sin acceso a internet por seguridad
```

3. **Ejecutar:**
   - Botón "Ejecutar" o `Ctrl+Enter`
   - Ver resultados en tiempo real
   - Descargar logs si es necesario

#### Límites de Ejecución

**Por defecto:**
- ⏱️ **Tiempo**: 5 minutos máximo
- 💾 **Memoria**: 512MB máximo
- 🖥️ **CPU**: 50% máximo
- 📁 **Archivos**: 10MB máximo
- 🌐 **Red**: Sin acceso externo

---

## 🤖 Bot de Telegram

### Configuración del Bot

#### 1. Encontrar tu Bot
Busca tu bot en Telegram usando el nombre que le diste a @BotFather.

#### 2. Comandos Disponibles

**Comandos Básicos:**
- `/start` - Iniciar bot y ver bienvenida
- `/help` - Mostrar ayuda completa
- `/login` - Proceso de autenticación
- `/profile` - Ver información de perfil

**Ejecución de Código:**
- `/execute <lenguaje> <código>` - Ejecutar código

**Ejemplos:**
```
/execute python print("Hola Telegram!")
/execute bash echo "Hola desde Bash"
/execute javascript console.log("Hola JS")
```

**Gestión:**
- `/status` - Ver ejecuciones recientes
- `/limits` - Ver límites de tu cuenta

### Autenticación en Telegram

#### Proceso de Login

1. **Enviar `/login` al bot**
2. **El bot responde con instrucciones**
3. **Ir a la plataforma web**
4. **Generar token de Telegram en perfil**
5. **Enviar token al bot**
6. **¡Autenticado!**

---

## 📊 Monitoreo y Mantenimiento

### Grafana Dashboard

#### Acceso
```
URL: http://localhost:3001
Usuario: admin
Contraseña: admin123
```

#### Dashboards Disponibles

**1. Sistema General:**
- CPU, RAM, Disco
- Red y I/O
- Procesos activos

**2. Aplicación:**
- Requests por minuto
- Ejecuciones por usuario
- Tiempo promedio de ejecución
- Errores y fallos

### Backup Automático

#### Configuración por Defecto
- **Frecuencia**: Diario a las 2:30 AM
- **Retención**: 7 días
- **Ubicación**: `/opt/platform/backups/`

#### Backup Manual
```bash
# Ejecutar backup inmediato
sudo /opt/platform/scripts/backup.sh

# Ver backups disponibles
ls -la /opt/platform/backups/
```

---

## 🚨 Solución de Problemas

### Problemas Comunes

#### 1. Bot de Telegram No Responde

**Síntomas:**
- Bot no responde a comandos
- Error "Bot not found"

**Solución:**
```bash
# Verificar token
grep TELEGRAM_BOT_TOKEN /opt/platform/remote-execution-platform/.env

# Verificar contenedor
docker-compose ps telegram-bot

# Ver logs
docker-compose logs telegram-bot

# Reiniciar bot
docker-compose restart telegram-bot
```

#### 2. API No Accesible

**Síntomas:**
- Error 502 Bad Gateway
- Timeout en requests

**Solución:**
```bash
# Verificar backend
docker-compose ps backend

# Ver logs
docker-compose logs backend

# Reiniciar backend
docker-compose restart backend
```

---

## 🔧 Comandos Útiles

### Gestión de Servicios

#### Systemd (Recomendado)
```bash
# Iniciar plataforma
sudo systemctl start remote-execution-platform

# Detener plataforma
sudo systemctl stop remote-execution-platform

# Reiniciar plataforma
sudo systemctl restart remote-execution-platform

# Estado de la plataforma
sudo systemctl status remote-execution-platform
```

#### Docker Compose
```bash
# Cambiar al directorio
cd /opt/platform/remote-execution-platform

# Iniciar servicios
docker-compose up -d

# Detener servicios
docker-compose down

# Ver estado
docker-compose ps

# Ver logs
docker-compose logs -f
```

### Gestión con Puppet

#### Aplicar Configuración
```bash
# Aplicar cambios
sudo puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp

# Ver configuración actual
cat /etc/puppetlabs/code/environments/production/hieradata/common.yaml
```

### Mantenimiento

#### Limpieza del Sistema
```bash
# Limpiar Docker
docker system prune -a -f

# Limpiar logs antiguos
sudo find /opt/platform/logs -name "*.log" -mtime +30 -delete

# Actualizar sistema
sudo apt update && sudo apt upgrade -y
```

---

## 📞 Soporte y Ayuda

### Documentación Adicional
- **API Docs**: https://localhost/api/docs
- **Grafana Help**: http://localhost:3001/help

### Contacto
- **Email**: admin@platform.local
- **GitHub Issues**: [Crear issue](https://github.com/tu-usuario/remote-execution-platform/issues)

---

## 🎯 Próximos Pasos

Después de la instalación exitosa:

1. **✅ Configurar Bot de Telegram**
2. **✅ Personalizar dominios y SSL**
3. **✅ Configurar alertas por email**
4. **✅ Revisar dashboards de Grafana**
5. **✅ Probar ejecución de código**
6. **✅ Configurar backups en ubicación externa**
7. **✅ Documentar procedimientos específicos de tu organización**

¡Tu plataforma de ejecución remota está lista para usar! 🚀