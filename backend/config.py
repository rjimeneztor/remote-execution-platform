"""
Configuración de la aplicación
"""
import os
from typing import List
from pydantic_settings import BaseSettings
from pydantic import validator

class Settings(BaseSettings):
    """Configuración de la aplicación"""
    
    # Database
    DATABASE_URL: str = "postgresql://platform_user:password@postgres:5432/remote_execution"
    
    # Redis
    REDIS_URL: str = "redis://redis:6379/0"
    
    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-this"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 1440  # 24 horas
    
    # API
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DEBUG: bool = False
    
    # Security
    ALLOWED_HOSTS: List[str] = ["localhost", "127.0.0.1"]
    CORS_ORIGINS: List[str] = ["http://localhost:3000"]
    
    # Execution limits
    MAX_EXECUTION_TIME: int = 300  # 5 minutos
    MAX_MEMORY_MB: int = 512
    MAX_CPU_PERCENT: int = 50
    
    # File upload
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_FILE_TYPES: List[str] = [".py", ".sh", ".ps1", ".js", ".sql"]
    UPLOAD_DIR: str = "/app/uploads"
    
    # Telegram
    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_WEBHOOK_URL: str = ""
    
    # Monitoring
    PROMETHEUS_PORT: int = 9090
    GRAFANA_PORT: int = 3001
    
    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"
    
    @validator('ALLOWED_HOSTS', pre=True)
    def parse_allowed_hosts(cls, v):
        if isinstance(v, str):
            return [host.strip() for host in v.split(',')]
        return v
    
    @validator('CORS_ORIGINS', pre=True)
    def parse_cors_origins(cls, v):
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(',')]
        return v
    
    @validator('ALLOWED_FILE_TYPES', pre=True)
    def parse_allowed_file_types(cls, v):
        if isinstance(v, str):
            return [ext.strip() for ext in v.split(',')]
        return v
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# Instancia global de configuración
settings = Settings()

# Configuración de logging
LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        },
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(name)s %(levelname)s %(message)s"
        }
    },
    "handlers": {
        "default": {
            "formatter": "json" if settings.LOG_FORMAT == "json" else "default",
            "class": "logging.StreamHandler",
            "stream": "ext://sys.stdout",
        },
        "file": {
            "formatter": "json" if settings.LOG_FORMAT == "json" else "default",
            "class": "logging.handlers.RotatingFileHandler",
            "filename": "/app/logs/backend.log",
            "maxBytes": 10485760,  # 10MB
            "backupCount": 5,
        }
    },
    "loggers": {
        "": {
            "level": settings.LOG_LEVEL,
            "handlers": ["default", "file"],
        },
    },
}

# Configuración de Docker para ejecución de código
DOCKER_CONFIG = {
    "image_templates": {
        "python": "python:3.11-slim",
        "bash": "ubuntu:22.04",
        "powershell": "mcr.microsoft.com/powershell:latest",
        "javascript": "node:18-alpine",
        "sql": "postgres:15-alpine"
    },
    "resource_limits": {
        "memory": f"{settings.MAX_MEMORY_MB}m",
        "cpu_period": 100000,
        "cpu_quota": settings.MAX_CPU_PERCENT * 1000,
        "network_mode": "none",  # Sin acceso a red por seguridad
        "read_only": True,
        "tmpfs": {"/tmp": "size=100m,noexec"}
    },
    "security_opts": [
        "no-new-privileges:true",
        "seccomp:unconfined"  # Puede necesitar ajustes según el código
    ]
}

# Configuración de notificaciones
NOTIFICATION_CONFIG = {
    "channels": {
        "telegram": {
            "enabled": bool(settings.TELEGRAM_BOT_TOKEN),
            "priority": 1
        },
        "websocket": {
            "enabled": True,
            "priority": 2
        },
        "email": {
            "enabled": False,  # TODO: configurar SMTP
            "priority": 3
        }
    },
    "templates": {
        "execution_started": "🚀 Ejecución iniciada: {script_name}",
        "execution_completed": "✅ Ejecución completada: {script_name} ({duration}s)",
        "execution_failed": "❌ Ejecución fallida: {script_name} - {error}",
        "user_login": "👤 Usuario conectado: {username}",
        "system_alert": "⚠️ Alerta del sistema: {message}"
    }
}