# Agente del taller y canales de chat

Este paquete instala PicoClaw v0.3.1 para arm64, el agente de programación Pi y una cuenta de servicio restringida. Este repositorio no debe contener credenciales reales. Durante la preparación del taller, cada tarjeta recibe una clave de API distinta (o una clave virtual de LiteLLM) y su propio token de bot de Telegram.

## Instalación

En la Radxa, desde la raíz del repositorio:

```bash
sudo device/agent/install-agent.sh
```

Antes de instalar, el instalador verifica tanto el manifiesto fijado de sumas de comprobación de la versión oficial como el resumen fijado de `picoclaw_aarch64.deb`. También instala un entorno de ejecución oficial y verificado de Node 22 para arm64 y `@earendil-works/pi-coding-agent` 0.82.1. El servicio queda instalado, pero no se inicia hasta que existan credenciales y una lista de usuarios permitidos que no esté vacía.

## Configuración de un equipo (primero Telegram)

Busca el identificador numérico de usuario de Telegram de cada participante y proporciona de uno a cinco identificadores. Los secretos se solicitan mediante entradas ocultas y no se guardan en el historial del shell ni aparecen en la lista de procesos:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222 \
  --telegram-user 333333333 \
  --telegram-user 444444444 \
  --telegram-user 555555555
```

Para un proxy de LiteLLM, el modelo es el alias configurado en el proxy y el valor solicitado es la clave virtual de esa tarjeta:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://litellm.example.org/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

Discord es opcional. Activa *Message Content Intent* en el portal para desarrolladores de Discord y después agrega por separado los usuarios permitidos:

```bash
sudo cdmx-agent-setup \
  --telegram-user 111111111 \
  --enable-discord \
  --discord-user 999999999999999999
```

Para automatizar la creación de imágenes, guarda cada secreto en un archivo separado, accesible únicamente por root (`chmod 600`), y pasa `--api-key-file`, `--telegram-token-file` y, de manera opcional, `--discord-token-file`. Como alternativa, `--from-env` lee `OPENAI_API_KEY` o `LITELLM_VIRTUAL_KEY`, `LITELLM_API_BASE`, además de `TELEGRAM_BOT_TOKEN` y el valor opcional `DISCORD_BOT_TOKEN`; elimina esas variables del entorno inmediatamente después. Se recomienda proporcionar los valores mediante archivos o entradas ocultas.

Si proporcionas los valores del entorno mediante `sudo`, conserva explícitamente solo las variables necesarias. Por ejemplo:

```bash
sudo --preserve-env=OPENAI_API_KEY,TELEGRAM_BOT_TOKEN \
  cdmx-agent-setup --from-env --telegram-user 111111111
```

La reconfiguración se negará a sobrescribir credenciales existentes a menos que se indique `--force`. Usa `--no-start` cuando prepares una imagen sin conexión.

## Límites de seguridad

- Telegram y Discord nunca aceptan una lista de usuarios permitidos vacía; cada uno admite como máximo cinco identificadores numéricos de usuario definidos explícitamente.
- La ejecución remota de comandos está habilitada porque programar forma parte del ejercicio, pero PicoClaw v0.3.1 restringe las rutas a `/var/lib/cdmx-picoclaw/workspace` y mantiene activado su filtro de comandos peligrosos.
- El servicio se ejecuta como el usuario sin inicio de sesión `cdmx-agent`, sin capacidades, con el sistema operativo en modo de solo lectura, dispositivos y directorio temporal privados, y varias protecciones del kernel y de llamadas al sistema.
- Solo se puede escribir en el estado y el espacio de trabajo de PicoClaw. La configuración pertenece a root; los secretos usan el propietario y grupo `root:cdmx-agent` y el modo `0640`. El usuario `cdmx` de noVNC comparte el espacio de trabajo con setgid mediante el grupo independiente `cdmx-workspace` y no puede leer el archivo de secretos.
- La puerta de enlace escucha únicamente en la interfaz de bucle local. Telegram y Discord usan conexiones salientes, por lo que no es necesario exponer ningún puerto de PicoClaw en la red LAN.

Comprobaciones útiles:

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo -u cdmx-agent picoclaw --version
pi --version
```

Ejecuta las pruebas locales del generador con:

```bash
python3 -m unittest discover -s device/agent/tests -v
```
