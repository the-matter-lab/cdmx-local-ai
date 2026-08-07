# Agente local para el taller CDMX

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

Este repositorio contiene solamente el agente de programación del taller para
Radxa ZERO 3W: PicoClaw para conversar desde Telegram o Discord, Pi para
trabajar desde una terminal y una configuración que limita al agente al espacio
de trabajo compartido.

La imagen del sistema operativo, el portal de Wi-Fi, noVNC y las herramientas
para grabar tarjetas SD viven en
[`the-matter-lab/cdmx-radxa-flash`](https://github.com/the-matter-lab/cdmx-radxa-flash).
El ejercicio de optimización bayesiana vive en
[`the-matter-lab/cdmx-bayesopt`](https://github.com/the-matter-lab/cdmx-bayesopt).

## Instalar en la Radxa

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
sudo ./device/agent/install-agent.sh
```

El instalador fija y verifica las versiones de PicoClaw, Node y Pi. Crea el
usuario sin inicio de sesión `cdmx-agent`, el servicio systemd y el espacio de
trabajo compartido `/var/lib/cdmx-picoclaw/workspace`. El servicio no comienza
hasta que se guarden credenciales y al menos un usuario autorizado.

## Configurar Telegram

Cada equipo debe usar su propia clave de OpenAI o clave virtual de LiteLLM y su
propio bot. Para uno a cinco participantes:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

El comando solicita la clave de API y el token del bot con entradas ocultas.
Los números de `--telegram-user` son identificadores numéricos de usuarios de
Telegram, no nombres de usuario.

Con una puerta de enlace LiteLLM:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://TU-GATEWAY.example/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

## Configurar Discord

Activa *Message Content Intent* para el bot en el portal de Discord y agrega
explícitamente las personas autorizadas:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --disable-telegram \
  --enable-discord \
  --discord-user 999999999999999999
```

También se pueden activar Telegram y Discord en el mismo comando. Consulta
[`device/agent/README.md`](device/agent/README.md) para automatización con
archivos protegidos o variables de entorno.

## Uso y diagnóstico

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo -u cdmx-agent picoclaw --version
pi --version
```

El agente corre sin privilegios y solo puede escribir en su espacio de trabajo.
Las credenciales quedan en `/etc/cdmx-picoclaw/.security.yml`, propiedad de
`root:cdmx-agent` y con modo `0640`. Usa credenciales desechables distintas por
equipo y listas explícitas de participantes.

Para ejecutar las pruebas del repositorio:

```bash
make test
```
