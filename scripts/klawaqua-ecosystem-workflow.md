---
name: klawaqua-ecosystem-workflow
description: Flujo de trabajo para activar ngrok y asegurar que thepopebot esté operativo y funcionando en el ecosistema KlawAqua.
trigger_conditions:
  - Cuando se necesita iniciar o verificar el ecosistema KlawAqua completo
  - Después de reiniciar el sistema o Docker
  - Antes de usar la interfaz web de thepopebot remotamente
  - Como parte de rutinas de mantenimiento o verificaciones de salud
prerequisites:
  - Docker y docker-compose instalados y funcionando
  - Ngrok instalado y autenticado (ngrok authtoken configurado)
  - ThePopebot desplegado en /opt/klawaqua/projects/thepopebot/
  - Ollama ejecutándose localmente en puerto 11434
  - OpenClaw configurado para usar Ollama directamente
steps:
  - Verificar y activar ngrok
  - Verificar servicios de thepopebot
  - Verificar backend de Ollama
  - Proporcionar resumen
command_line_usage: |
  /opt/klawaqua/scripts/start-ecosystem.sh
expected_outputs:
  - Ngrok iniciado y proporcionando una URL pública tipo https://xxxxxxxxxxxx.ngrok-free.dev
  - Todos los servicios de thepopebot reportando estado "Up"
  - Confirmación de que Ollama está respondiendo en puerto 11434
  - Resumen con la URL de acceso seguro al ecosistema y ubicación del log
troubleshooting:
  - "Ngrok falla al iniciar": "Verificar que ngrok esté autenticado (`ngrok authtoken <tu-token>`)"
  - "Servicios no se inician": "Revisar logs de Docker con `docker logs <nombre-servicio>`"
  - "Ollama no responde": "Verificar que el servicio ollama esté activo (`systemctl status ollama`)"
  - "Puerto 8080 en uso": "Otro servicio podría estar usando el puerto necesario para Traefik"
success_criteria:
  - Ngrok proporciona una URL pública accesible
  - Los servicios thepopebot-event-handler, thepopebot-instance-litellm-1, thepopebot-instance-traefik-1 y thepopebot-instance-runner-1 están en estado "Up"
  - Ollama responde en `http://localhost:11434/api/tags`
  - Se puede acceder a la interfaz web de thepopebot mediante la URL de ngrok
author: Hermes Agent
---