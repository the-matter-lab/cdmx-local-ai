# Espacio de trabajo compartido

Este es el único directorio que PicoClaw puede leer y modificar. El escritorio
noVNC abre el mismo directorio, así que participantes y agente ven los mismos
archivos.

Comandos útiles:

```bash
pi
picoclaw skills list
picoclaw agent -m "Lista las skills del taller"
picoclaw gateway
git -C "$HOME/workspace/cdmx-local-ai" status
python3 "$HOME/workspace/cdmx-local-ai/tools/cdmx_hardware.py" led '#6633FF' --brightness 0.25
python3 "$HOME/workspace/cdmx-local-ai/tools/cdmx_hardware.py" sensor
```

Después de clonar `cdmx-local-ai` e instalar sus skills, usa `/list skills` en
Telegram o Discord para ver `led`, `color-sensor` y `coding`. No guardes aquí
claves de API ni tokens de bots; PicoClaw los lee desde
`~/.picoclaw/.security.yml`.
