# Lista de verificación para el instructor

## Dos semanas antes

- Confirme que las diez placas sean ZERO 3W de 1 GB y que todas las tarjetas SD
  sean del mismo modelo y tengan la misma capacidad en bytes.
- Use fuentes de alimentación de 5 V/2 A o superiores y pruebe los cables de
  alimentación exactos. La ZERO 3 solo acepta una entrada de 5 V.
- Construya, limpie, capture y verifique mediante lectura la imagen maestra.
- Grabe `equipo1` a `equipo10`; nunca arranque dos tarjetas con el mismo número.
- Arranque cada tarjeta dos veces, incluida una prueba intencional de desconexión
  y reconexión después de que hayan terminado todas las escrituras.
- Verifique `.local`, SSH, escritura y borrado en Samba, noVNC de control, noVNC
  de solo lectura, la demostración bayesiana, zram y la recuperación del punto
  de acceso de configuración.
- Si usará el rescate por USB, active en la maestra la superposición de
  periférico OTG de Radxa y el servicio NCM, y después haga pruebas con equipos
  macOS y Windows.

## Credenciales que debe preparar

- Una contraseña local del taller para Linux, Samba, el punto de acceso de
  configuración y noVNC. Imprímala en la tarjeta informativa del equipo; no
  reutilice una contraseña personal.
- Diez claves de proyecto de OpenAI o, preferentemente, diez claves virtuales de
  LiteLLM con presupuesto limitado.
- Diez bots de Telegram, uno por equipo. Registre cada token en una hoja de
  secretos del instructor sin conexión y configure un grupo de equipo por bot.
- De uno a cinco identificadores numéricos de usuario de Telegram por equipo.
  No use un comodín ni una lista de usuarios autorizados vacía.
- Opcional: una aplicación o bot de Discord por equipo con Message Content
  Intent habilitado.

Inyecte las credenciales de la API y del canal únicamente después de grabar cada
clon. Nunca las agregue a la tarjeta maestra ni al repositorio.

## Ensayo de la red del recinto

- Prefiera un router o punto de acceso exclusivo para el taller, dimensionado
  para aproximadamente 60 clientes (diez placas más los dispositivos de los
  participantes). Verifique la capacidad de DHCP y el tráfico entre clientes.
- Si usará el Wi-Fi del recinto, pregunte explícitamente si están bloqueados el
  tráfico multicast/mDNS y el tráfico entre dispositivos. Una conexión exitosa
  a Internet no demuestra que noVNC vaya a funcionar.
- Tenga listos el SSID y la contraseña para la página de configuración, pero no
  los incorpore en las tarjetas.
- Registre las concesiones o direcciones IP de DHCP como alternativa cuando
  `.local` no esté disponible.

## El día del taller

1. Encienda las placas por grupos y compruebe `equipoN-setup` o la red
   guardada.
2. Abra desde la laptop del instructor el enlace noVNC de solo lectura de cada
   equipo.
3. Ejecute `systemctl --failed` y `free -h` mediante SSH.
4. Configure y pruebe el bot del equipo antes de entregar su código QR o
   invitación.
5. Designe un controlador noVNC por equipo; todos los demás deben usar el
   enlace de solo lectura.
6. Tenga preparadas dos tarjetas SD de repuesto ya grabadas y al menos una
   placa Radxa y una fuente de alimentación de repuesto.

## Comandos de recuperación

```bash
sudo cdmx-network status
sudo cdmx-network reset
sudo systemctl restart cdmx-desktop cdmx-novnc cdmx-demo
sudo systemctl restart cdmx-picoclaw
sudo journalctl -u cdmx-network -u cdmx-picoclaw -n 100 --no-pager
sudo reboot
```
