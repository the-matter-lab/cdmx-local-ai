# Espacio de trabajo compartido

Este es el único directorio que PicoClaw puede leer y modificar. El escritorio
noVNC abre el mismo directorio, así que participantes y agente ven los mismos
archivos.

Comandos útiles:

```bash
pi
git status
python3 tools/cdmx_hardware.py led '#6633FF' --brightness 0.25
python3 tools/cdmx_hardware.py sensor
```

En Telegram o Discord usa `/list skills` para ver `led`, `color-sensor` y
`coding`, o simplemente pide la tarea en lenguaje natural. No guardes aquí
claves de API ni tokens de bots; se almacenan fuera de este espacio.
