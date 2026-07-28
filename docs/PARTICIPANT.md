# Tarjeta para participantes

Sustituya `N` por el número de su equipo.

1. Conéctese al Wi-Fi del taller en el recinto. Si la placa aún no está
   configurada, conéctese a `equipoN-setup`, abra
   `http://10.42.N.1:8080/` y elija la red Wi-Fi del recinto.
2. Una persona del equipo abre `http://equipoN.local:6080/control.html`.
3. Las demás abren `http://equipoN.local:6080/view.html`.
4. Envíe un mensaje que mencione al bot de Telegram de su equipo. El bot solo
   funciona para las cinco personas autorizadas por el instructor.

Otros medios de acceso:

```text
SSH:    ssh cdmx@equipoN.local
Samba:  smb://equipoN.local/workspace
```

El directorio de código compartido es `/var/lib/cdmx-picoclaw/workspace`.
Guarde ahí todo el trabajo del agente. No pegue claves de API ni tokens de bots
en el chat, en archivos de código fuente ni en la terminal.

Antes de desconectar la placa, use `sudo poweroff` y espere a que termine la
actividad. Si se corta la energía inesperadamente, la placa debería
recuperarse en el siguiente arranque, pero una interrupción durante una
escritura aún puede dañar la tarjeta SD.
