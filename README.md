# Agente de programación · taller CDMX

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

PicoClaw conecta Telegram con el agente de programación de cada Radxa ZERO
3W. El participante configura el modelo, el bot y el gateway usando la sintaxis
nativa de PicoClaw. Las skills del taller permiten cambiar el NeoPixel, leer el
TCS34725 y trabajar con código.

El material que usarán los equipos está visible en la raíz del repositorio:
[`skills/`](skills) contiene las instrucciones del agente y
[`tools/`](tools) contiene la interfaz de hardware. La imagen no los instala:
cada equipo los descarga durante el taller.

La imagen ya incluye PicoClaw `0.3.1` y `pi`, pero no este repositorio ni sus
skills. No ejecutes el
instalador desde el escritorio noVNC.

## 1. Clonar el repositorio

Desde `~/workspace`:

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
```

## 2. Inicializar PicoClaw

PicoClaw `0.3.1` llama `onboard` a su inicialización:

```bash
picoclaw version
picoclaw onboard
```

El mensaje **`picoclaw is ready!`** es normal: solo confirma que PicoClaw creó
los archivos iniciales. Todavía no hay modelo, clave, bot ni gateway
configurados; esos son los siguientes pasos del participante.

Esto crea `~/.picoclaw/config.json`, `~/.picoclaw/.security.yml` y el espacio
de PicoClaw. Para el taller, usa los ejemplos como punto de partida:

```bash
cp device/agent/examples/config.telegram.json ~/.picoclaw/config.json
cp device/agent/examples/security.telegram.example.yml ~/.picoclaw/.security.yml
chmod 600 ~/.picoclaw/.security.yml
```

Ahora edita ambos archivos tú mismo:

```bash
nano ~/.picoclaw/config.json
nano ~/.picoclaw/.security.yml
```

En `config.json`:

- Cambia `YOUR_NUMERIC_TELEGRAM_USER_ID` por tu ID numérico.
- `provider`, `model` y `model_name` definen el modelo.
- `workspace` permanece en `/home/cdmx/workspace` para compartir el código con
  noVNC y `pi`.
- `allow_from` debe contener únicamente los participantes autorizados.

En `.security.yml`, reemplaza únicamente la clave de OpenRouter y el token del
bot. Nunca los pegues en `config.json`, el repositorio o el chat.

Para usar otro proveedor, conserva la estructura de `model_list` y consulta la
[guía oficial de proveedores de PicoClaw](https://github.com/sipeed/picoclaw/blob/v0.3.1/docs/guides/providers.md).

## 3. Instalar las skills

PicoClaw `0.3.1` instala una skill por comando. Este bloque instala las tres de
una vez usando la sintaxis nativa:

```bash
for skill in coding color-sensor led; do
  picoclaw skills install "the-matter-lab/cdmx-local-ai/skills/$skill"
done
picoclaw skills list
```

Para instalar las tres en `pi` con un solo comando:

```bash
npx skills add the-matter-lab/cdmx-local-ai \
  --skill '*' \
  --agent pi --yes
```

La herramienta de hardware permanece dentro del clon y no se instala en el
sistema. Desde `~/workspace/cdmx-local-ai` puedes probarla con:

```bash
python3 tools/cdmx_hardware.py --help
```

## 4. Crear el bot de Telegram

1. Habla con [`@BotFather`](https://t.me/BotFather), ejecuta `/newbot` y copia
   el token en `.security.yml`.
2. Envía `/start` a tu nuevo bot.
3. Obtén tu ID numérico con el método oficial
   [`getUpdates`](https://core.telegram.org/bots/api#getupdates) y escríbelo en
   `allow_from`.

Una lista vacía permite el acceso a cualquier persona: no la dejes vacía.

## 5. Probar e iniciar el gateway

Primero comprueba el modelo y las tools sin Telegram:

```bash
picoclaw agent -m "Lista las skills del taller"
```

Después inicia el gateway en primer plano:

```bash
picoclaw gateway
```

Mantén esa terminal abierta y escribe al bot. `Ctrl-C` detiene el gateway; el
mismo comando lo vuelve a iniciar. Prueba mensajes como:

```text
Cambia el LED a morado con brillo 20 %.
Lee el sensor de color y explícame los valores.
Revisa cdmx-bayesopt y ejecuta sus pruebas.
```

Usa `/list skills` y `/use led ...` para practicar la sintaxis de skills de
PicoClaw. `pi` sigue disponible como agente interactivo independiente:

```bash
pi
```

## Discord

PicoClaw también acepta un bloque `channel_list.discord`. Activa **Message
Content Intent**, coloca los IDs autorizados en `allow_from` y guarda el token
en `channels.discord.token` dentro de `.security.yml`. Consulta la
[sintaxis oficial de Discord](https://github.com/sipeed/picoclaw/blob/v0.3.1/docs/channels/discord/README.md).

## Instalación de la imagen

[`device/agent/install-agent.sh`](device/agent/install-agent.sh) es solamente
para construir la imagen o instalar los binarios en una Radxa preparada. Los
participantes no lo ejecutan. El instalador no incluye las skills ni las tools;
el repositorio no incluye claves reales.

```bash
make test
```
