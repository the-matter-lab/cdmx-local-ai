# Flujo de trabajo para las tarjetas del taller

Ejecuta estos comandos desde la raíz del repositorio. Cada escritura requiere
la frase de confirmación exacta que muestra el script. La imagen maestra no debe
contener credenciales de Wi-Fi ni claves de API.

1. Enumera los discos extraíbles con `./host/list-disks.sh`.
2. Descarga y verifica la imagen fijada de Radxa con
   `./host/download-stock-image.sh`.
3. Crea la tarjeta maestra original con
   `./host/flash-stock.sh --disk /dev/DISK`.
4. Arranca esa tarjeta en una ZERO 3W, instala el conjunto de herramientas del
   taller con el instalador del dispositivo, pruébalo, elimina todas las
   credenciales y el historial, y apaga el equipo correctamente.
5. Vuelve a insertar la tarjeta maestra en la computadora anfitriona y ejecuta
   `./host/capture-golden.sh --source /dev/DISK`.
6. Para cada tarjeta nueva, ejecuta
   `./host/flash-team.sh --team N --disk /dev/DISK`, donde `N` va de 1 a 10.

El último comando verifica la imagen maestra comprimida, la escribe, vuelve a
leer los bytes escritos y solo entonces escribe `before.txt` y
`cdmx-team.env` en la partición FAT `config`. El marcador asigna `equipoN`; el
servicio de primer arranque del dispositivo lo procesa. La configuración de
Wi-Fi queda vacía para que las credenciales del lugar puedan ingresarse
localmente después del arranque.

La captura maestra es una imagen del dispositivo completo. Por lo tanto, las
tarjetas de destino deben tener como mínimo el mismo tamaño en bytes que la
tarjeta maestra, aunque ambas anuncien la misma capacidad. Usa el mismo modelo
y lote de tarjetas para la maestra y todas las copias.
