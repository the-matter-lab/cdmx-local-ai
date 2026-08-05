# Arquitectura y decisiones de diseño

```text
teléfonos y laptops de participantes
  ├─ HTTP 6080 ──> noVNC/websockify ──> 127.0.0.1:5901 TigerVNC/Openbox
  ├─ SSH ─────────────────────────────> espacio de trabajo compartido
  └─ nube de Telegram/Discord
             │ sondeo largo/WebSocket de salida
             v
        PicoClaw (cdmx-agent, sin sudo)
             │ API de OpenAI o clave virtual de LiteLLM por equipo
             v
       /var/lib/cdmx-picoclaw/workspace

configuración inicial de la red
  equipoN-setup / 10.42.N.1 ──> portal local ──> perfil del recinto en NetworkManager
  NCM por USB opcional / 10.55.N.1 ───────────> acceso de recuperación
```

La sesión gráfica es única y compartida. `view.html` indica a noVNC que suprima
la entrada, mientras que `control.html` la permite. Esto es una medida de
coordinación, no un límite de control de acceso: cualquier persona que conozca
la URL del controlador y la contraseña puede controlar el escritorio.

El agente del canal está aislado de la cuenta de inicio de sesión, por lo que
los participantes normales no pueden leer su archivo de secretos de la API y
del canal. Ambas identidades comparten únicamente el grupo setgid del espacio de
trabajo. La herramienta de comandos de PicoClaw está habilitada porque la
programación autónoma es el tema del taller; systemd limita sus privilegios
sobre el sistema de archivos y el sistema operativo, pero no constituye un
entorno aislado matemáticamente completo.

Solo se puede acceder al portal de configuración Wi-Fi desde la subred de
configuración o USB de ese equipo. El portal usa un token de formulario por
proceso, valida todos los valores, llama a `nmcli` mediante arreglos de
argumentos en lugar de hacerlo a través de un shell y nunca registra las
credenciales. NetworkManager almacena el perfil del recinto en su directorio de
conexiones del sistema, al que solo root puede acceder.
