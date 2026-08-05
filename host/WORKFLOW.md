# Flujo de trabajo para las tarjetas del taller

Ejecuta estos comandos desde la raíz del repositorio. La imagen del taller se
construye localmente y no contiene credenciales de Wi-Fi ni claves de API.

En macOS, el flujo recomendado para grabar las tarjetas es abrir
`host/start-imager.command`. La aplicación local solicita autorización una vez,
detecta únicamente discos completos extraíbles, permite elegir `equipo0` a
`equipo9` o `admin`, muestra el progreso de escritura y verificación y expulsa cada
tarjeta terminada. Escucha exclusivamente en `127.0.0.1:8766`.

Los comandos siguientes proporcionan el mismo flujo de forma manual:

1. Descarga y verifica la imagen fijada de Radxa con
   `./host/download-stock-image.sh`.
2. Construye la imagen directamente en la Mac con
   `./host/build-workshop-image.sh`.
3. Para cada tarjeta, ejecuta
   `./host/flash-team.sh --team N --disk /dev/DISK`, donde `N` va de 0 a 9, o
   use `--team admin` para la tarjeta del instructor.

El último comando verifica la imagen comprimida, la escribe, vuelve a
leer los bytes escritos y solo entonces escribe `before.txt` y
`cdmx-team.env` en la partición FAT `config` o `efi`. El marcador asigna `equipoN`; el
servicio de primer arranque del dispositivo lo procesa. La configuración de
Wi-Fi queda vacía para que las credenciales del lugar puedan ingresarse
localmente después del arranque.

La imagen ocupa 8.07 GB sin comprimir. Las tarjetas de destino deben tener como
mínimo ese tamaño en bytes. Usa el mismo modelo y lote para las diez tarjetas.
