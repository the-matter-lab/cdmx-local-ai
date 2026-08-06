# Tarjeta para participantes

Sustituya `N` por el número de su equipo.

1. Conéctese al Wi-Fi del taller en el recinto. Si la placa aún no está
   configurada, conéctese a `equipoN-setup`; la pantalla de configuración debe
   abrirse automáticamente en iPhone/iPad, macOS, Windows y Android. En Windows,
   pulse primero la notificación **Action needed** si aparece. Si el sistema no
   muestra nada, abra `http://10.42.N.1:8080/` y elija la red Wi-Fi del recinto.
2. Una persona del equipo abre `http://equipoN.local:6080/control.html`.
3. Las demás abren `http://equipoN.local:6080/view.html`.
4. Envíe un mensaje que mencione al bot de Telegram de su equipo. El bot solo
   funciona para las cinco personas autorizadas por el instructor.

En el escritorio noVNC, haga clic derecho en cualquier parte vacía del fondo
para abrir el menú de aplicaciones. Desde ahí puede abrir una terminal, una
terminal dentro del espacio de trabajo, el editor Nano, Pi Agent o el monitor
del sistema. También puede usar `Ctrl+Alt+T` para abrir una terminal nueva,
`Ctrl+Alt+E` para abrir el editor y `Super+Espacio` para mostrar el menú.

Otros medios de acceso:

```text
SSH:    ssh cdmx@equipoN.local
```

El directorio de código compartido es `/var/lib/cdmx-picoclaw/workspace`.
Guarde ahí todo el trabajo del agente. No pegue claves de API ni tokens de bots
en el chat, en archivos de código fuente ni en la terminal.

Antes de desconectar la placa, use `sudo poweroff` y espere a que termine la
actividad. Si se corta la energía inesperadamente, la placa debería
recuperarse en el siguiente arranque, pero una interrupción durante una
escritura aún puede dañar la tarjeta SD.
