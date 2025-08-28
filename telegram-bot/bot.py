"""
Bot de Telegram para la Plataforma de Ejecución Remota
Permite autenticación y ejecución de comandos remotos
"""

import os
import logging
import asyncio
from datetime import datetime
from telegram import Update, BotCommand
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import httpx
from fastapi import FastAPI
import uvicorn
import threading

# Configurar logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Configuración
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:8000")

if not BOT_TOKEN or BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
    logger.error("TELEGRAM_BOT_TOKEN no configurado")
    exit(1)

# FastAPI para health check
health_app = FastAPI()

@health_app.get("/health")
async def health():
    return {"status": "healthy", "service": "telegram-bot"}

# Comandos del bot
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /start"""
    user = update.effective_user
    welcome_message = f"""
🚀 ¡Bienvenido a la Plataforma de Ejecución Remota!

Hola {user.first_name}, soy tu asistente para ejecutar código de forma segura.

📋 **Comandos disponibles:**
/start - Mostrar este mensaje
/help - Ayuda detallada
/login - Autenticarse en la plataforma
/execute - Ejecutar código
/status - Ver estado de ejecuciones
/profile - Ver tu perfil

🔒 **Seguridad:**
- Todas las ejecuciones son sandboxeadas
- Límites de tiempo y recursos aplicados
- Logs completos de actividad

¡Comienza con /login para autenticarte!
    """
    await update.message.reply_text(welcome_message)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /help"""
    help_text = """
📚 **Ayuda - Plataforma de Ejecución Remota**

🔐 **Autenticación:**
/login - Iniciar sesión con tus credenciales

⚡ **Ejecución de Código:**
/execute <lenguaje> <código> - Ejecutar código
Ejemplo: `/execute python print("Hello World")`

Lenguajes soportados:
• Python 🐍
• Bash 🐚
• PowerShell 💻
• JavaScript 🟨
• SQL 🗄️

📊 **Información:**
/status - Ver tus ejecuciones recientes
/profile - Ver información de tu cuenta

🛡️ **Límites de Seguridad:**
• Tiempo máximo: 5 minutos
• Memoria máxima: 512MB
• CPU máximo: 50%
• Sin acceso a red externa

❓ **Soporte:**
Si tienes problemas, contacta al administrador.
    """
    await update.message.reply_text(help_text)

async def login(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /login"""
    user = update.effective_user
    
    # Placeholder para autenticación
    login_message = f"""
🔐 **Proceso de Autenticación**

Usuario: {user.username or user.first_name}
ID: {user.id}

Para completar la autenticación:
1. Ve a la plataforma web
2. Genera un token de Telegram
3. Envía el token aquí

Estado: ⏳ Pendiente de implementación
    """
    await update.message.reply_text(login_message)

async def execute_code(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /execute"""
    if not context.args:
        await update.message.reply_text(
            "❌ Uso: /execute <lenguaje> <código>\n"
            "Ejemplo: /execute python print('Hello World')"
        )
        return
    
    if len(context.args) < 2:
        await update.message.reply_text(
            "❌ Debes especificar el lenguaje y el código\n"
            "Ejemplo: /execute python print('Hello World')"
        )
        return
    
    language = context.args[0].lower()
    code = " ".join(context.args[1:])
    
    # Placeholder para ejecución
    execution_message = f"""
⚡ **Ejecución de Código**

Lenguaje: {language}
Código: `{code}`

🔄 Estado: En cola...
⏱️ Tiempo estimado: < 30s

ID de ejecución: exec_placeholder_{datetime.now().strftime('%Y%m%d_%H%M%S')}

⏳ Ejecutando... (implementación pendiente)
    """
    
    message = await update.message.reply_text(execution_message)
    
    # Simular ejecución
    await asyncio.sleep(2)
    
    result_message = f"""
✅ **Ejecución Completada**

Lenguaje: {language}
Código: `{code}`

📤 **Salida:**
```
Hello World (placeholder)
```

⏱️ Tiempo: 0.1s
💾 Memoria: 12MB
🔄 Estado: Completado
    """
    
    await message.edit_text(result_message)

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /status"""
    status_message = """
📊 **Estado de Ejecuciones**

👤 Usuario: No autenticado
🔄 Ejecuciones hoy: 0
⏱️ Tiempo total usado: 0s
💾 Memoria promedio: 0MB

📈 **Ejecuciones Recientes:**
(No hay ejecuciones)

🔗 Para ver más detalles, visita la plataforma web.
    """
    await update.message.reply_text(status_message)

async def profile(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Comando /profile"""
    user = update.effective_user
    profile_message = f"""
👤 **Tu Perfil**

**Información de Telegram:**
• Nombre: {user.first_name} {user.last_name or ''}
• Usuario: @{user.username or 'No definido'}
• ID: {user.id}

**Estado de la Cuenta:**
• Autenticado: ❌ No
• Nivel: Invitado
• Ejecuciones disponibles: 0

**Límites:**
• Tiempo por ejecución: 5 min
• Memoria máxima: 512MB
• Ejecuciones por día: 100

🔗 Auténticate para acceder a todas las funciones.
    """
    await update.message.reply_text(profile_message)

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Manejar mensajes de texto"""
    message_text = update.message.text
    
    if message_text.startswith('/'):
        await update.message.reply_text(
            "❓ Comando no reconocido. Usa /help para ver comandos disponibles."
        )
    else:
        await update.message.reply_text(
            "💬 Mensaje recibido. Usa /execute para ejecutar código o /help para ayuda."
        )

def run_health_server():
    """Ejecutar servidor de health check"""
    uvicorn.run(health_app, host="0.0.0.0", port=8001, log_level="warning")

async def main() -> None:
    """Función principal del bot"""
    logger.info("Iniciando bot de Telegram...")
    
    # Crear aplicación
    application = Application.builder().token(BOT_TOKEN).build()
    
    # Configurar comandos
    commands = [
        BotCommand("start", "Iniciar bot"),
        BotCommand("help", "Mostrar ayuda"),
        BotCommand("login", "Autenticarse"),
        BotCommand("execute", "Ejecutar código"),
        BotCommand("status", "Ver estado"),
        BotCommand("profile", "Ver perfil"),
    ]
    
    await application.bot.set_my_commands(commands)
    
    # Registrar handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("login", login))
    application.add_handler(CommandHandler("execute", execute_code))
    application.add_handler(CommandHandler("status", status))
    application.add_handler(CommandHandler("profile", profile))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    logger.info("Bot configurado, iniciando polling...")
    
    # Iniciar bot
    await application.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    # Iniciar servidor de health check en thread separado
    health_thread = threading.Thread(target=run_health_server, daemon=True)
    health_thread.start()
    
    # Iniciar bot
    asyncio.run(main())