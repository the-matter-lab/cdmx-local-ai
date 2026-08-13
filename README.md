# Agente de programación · taller CDMX

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

PicoClaw convierte Telegram o Discord en una puerta de entrada al agente de
programación de cada Radxa ZERO 3W. Los participantes pueden pedir en lenguaje
natural que cambie el NeoPixel, lea el TCS34725, explique el proyecto o cree,
modifique y pruebe archivos. El escritorio noVNC y el agente comparten el mismo
espacio de trabajo.

La imagen, el Wi-Fi y noVNC viven en
[`cdmx-radxa-flash`](https://github.com/the-matter-lab/cdmx-radxa-flash). El
Color Lab y el ejercicio RGB de optimización bayesiana permanecen en
[`cdmx-bayesopt`](https://github.com/the-matter-lab/cdmx-bayesopt).

## 1. Instalar

En la imagen del taller ya está instalado. Para actualizarlo o instalarlo en
otra tarjeta:

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
sudo ./device/agent/install-agent.sh
```

El instalador fija PicoClaw `0.3.1`, crea el usuario sin privilegios
`cdmx-agent` e instala tres skills: `led`, `color-sensor` y `coding`. También
instala `pi` para usar un agente interactivo desde la terminal del escritorio.

## 2. Elegir el modelo

Para una prueba corta recomendamos una clave de
[OpenRouter](https://openrouter.ai/keys) con su router `openrouter/free`:

```bash
sudo cdmx-agent-setup \
  --provider openrouter \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

El comando pide la clave y el token del bot sin mostrarlos. El nivel gratuito
de OpenRouter tiene límites bajos y disponibilidad variable; sirve para
experimentar, no para producción. También están disponibles:

| Opción | Argumento | Valor predeterminado |
|---|---|---|
| [Gemini API](https://aistudio.google.com/api-keys) | `--provider gemini` | `gemini-2.5-flash` |
| [DeepSeek](https://platform.deepseek.com/api_keys) | `--provider deepseek` | `deepseek-chat` |
| [Moonshot/Kimi](https://platform.moonshot.cn/console/api-keys) | `--provider moonshot` | `moonshot-v1-8k` |
| [OpenAI API](https://platform.openai.com/api-keys) | `--provider openai` | `gpt-5.4` |
| [Anthropic API](https://console.anthropic.com/settings/keys) | `--provider anthropic` | `claude-sonnet-4-6` |
| LiteLLM del taller | `--provider litellm --api-base https://…/v1` | `cdmx-workshop` |

Se puede cambiar el modelo con `--model`. Las cuentas y cuotas de cada
proveedor son independientes.

PicoClaw también ofrece sus propios flujos de inicio de sesión, sin pegar una
clave API. El acceso efectivo depende del plan y los permisos de la cuenta:

```bash
# Muestra un código y una URL para iniciar sesión con OpenAI/Codex.
sudo cdmx-agent-setup --provider openai-oauth --telegram-user 111111111

# Primero genera un token con `claude setup-token` en una máquina con Claude.
sudo cdmx-agent-setup --provider anthropic-oauth --telegram-user 111111111
```

## 3. Conectar el chat

### Telegram

1. Crea un bot con [`@BotFather`](https://t.me/BotFather) y envíale `/start`.
2. Obtén el identificador numérico `from.id` de cada participante con el método
   oficial [`getUpdates`](https://core.telegram.org/bots/api#getupdates).
3. Repite `--telegram-user ID` para cada persona (máximo cinco).

### Discord

Activa **Message Content Intent** para el bot y copia los IDs numéricos de los
participantes:

```bash
sudo cdmx-agent-setup \
  --provider openrouter \
  --disable-telegram \
  --enable-discord \
  --discord-user 999999999999999999
```

Para usar ambos canales, omite `--disable-telegram` y agrega las opciones de
Discord. Usa `--force` para reemplazar una configuración anterior.

## 4. Probarlo

Envía al bot, por ejemplo:

```text
Cambia el LED a morado con brillo 20 %.
Lee el sensor de color y explícame los valores.
Revisa los archivos de mi proyecto y ejecuta sus pruebas.
```

PicoClaw elige automáticamente la skill apropiada. También puedes usar
`/list skills` y `/use led ...`. Los mismos comandos de hardware funcionan en
la terminal:

```bash
cd /var/lib/cdmx-picoclaw/workspace
python3 tools/cdmx_hardware.py led '#6633FF' --brightness 0.20
python3 tools/cdmx_hardware.py sensor
```

## Operación y seguridad

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo systemctl restart cdmx-picoclaw.service
```

Solo los IDs incluidos pueden conversar con el bot. El servicio no corre como
root, solo puede escribir dentro de su espacio compartido y recibe únicamente
los grupos I²C/SPI necesarios. Las credenciales quedan fuera del espacio del
agente, en `/etc/cdmx-picoclaw/.security.yml` con modo `0640`. Usa bots y claves
desechables distintas por equipo. PicoClaw aún es software anterior a v1; no
lo expongas como servicio público ni lo uses con datos sensibles.

```bash
make test
```
