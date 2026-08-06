# Kit para el taller CDMX Local AI

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

Configuración reproducible para diez placas Radxa ZERO 3W de 1 GB. Cada placa
arranca como `equipo0` a `equipo9`, funciona sin teclado, ofrece un escritorio
noVNC compartido y puede
ejecutar desde Telegram o Discord un agente de programación restringido al
espacio de trabajo.

Este repositorio contiene todo el código fuente, la configuración, las
verificaciones y las instrucciones de operación. Las imágenes de tarjetas SD,
que ocupan varios gigabytes, no se guardan en Git; la imagen lista para grabar
también se publica como un artefacto de Docker. Las credenciales siempre se
generan y guardan localmente.

## Lo que tendrán los participantes

- `http://equipoN.local:6080/control.html` — un controlador noVNC activo.
- `http://equipoN.local:6080/view.html` — enlace compartido de solo lectura para
  el resto del equipo.
- `ssh cdmx@equipoN.local` — acceso por terminal desde la misma red LAN.
- `sudo` sin contraseña para instalar las herramientas del ejercicio y
  configurar el hardware local.
- Un escritorio Openbox de 1280×720 con una terminal Pi, actividad del canal y
  del espacio de trabajo y estado de CPU/RAM/temperatura. Haga clic derecho en
  el fondo para abrir terminales, el editor Nano, Pi Agent y el monitor del
  sistema. `Ctrl+Alt+T` abre una terminal nueva.
- PicoClaw como agente principal del canal de Telegram; Discord es opcional.
- Pi como agente de programación interactivo local opcional.
- Dependencias de `cdmx-bayesopt` y las interfaces I2C4-M0/SPI3-M1 de la ZERO
  3W preparadas para el laboratorio de color.

El uso de un solo escritorio compartido es intencional. Cinco sesiones gráficas
más los agentes no caben cómodamente en 1 GB; una persona controla el escritorio
mientras las otras cuatro observan y envían instrucciones por el canal del
equipo.

## Sistema operativo

La imagen fijada es la imagen de RadxaOS para ZERO 3 que Radxa ha probado por
completo: Debian 12 Bookworm arm64, kernel 6.1, versión `rsdk-b1`. La imagen del
taller elimina las aplicaciones KDE y los navegadores locales que no se usan, y
emplea Openbox para ahorrar almacenamiento y memoria. La URL exacta y el SHA-512 publicado están
en [`image/radxa-zero3-bookworm-kde-rsdk-b1.env`](image/radxa-zero3-bookworm-kde-rsdk-b1.env).

## Preparar las diez tarjetas

Use tarjetas SD de la misma marca, modelo y capacidad. En la Mac de
preparación, construya una vez la imagen local del taller:

```bash
./host/download-stock-image.sh
./host/build-workshop-image.sh
```

En macOS, abra [`host/start-imager.command`](host/start-imager.command) para
usar la interfaz local `http://127.0.0.1:8766/`. macOS solicita autorización
una sola vez al iniciar el servidor; después puede insertar cada tarjeta,
elegir `equipo0` a `equipo9` (o `admin` para la tarjeta rápida del instructor)
y observar el progreso de escritura y verificación.
La interfaz solo escucha en loopback, vuelve a validar que el destino sea una
unidad completa y extraíble, y expulsa la tarjeta cuando es seguro retirarla.

Para evitar reconstruir la imagen, puede descargar el artefacto verificado de
[Docker Hub](https://hub.docker.com/r/bestquark/cdmx-radxa-zero3w):

```bash
./host/pull-workshop-image.sh
./host/start-imager.command
```

El contenedor no es una aplicación para ejecutar: transporta la imagen
`cdmx-workshop-golden.img.xz` en partes y su suma SHA-512. El script reconstruye
la imagen y comprueba la suma antes de habilitar la grabación de tarjetas. Para
fijar una versión exacta, use por ejemplo
`CDMX_IMAGE_REF=bestquark/cdmx-radxa-zero3w:2026-08-06 ./host/pull-workshop-image.sh`.

No se usa una placa maestra ni una tarjeta SD maestra física. La construcción
se ejecuta en un entorno Linux ARM64 aislado en la Mac e incluye la clave SSH
pública del usuario de la Mac. Después grabe cada tarjeta desde la interfaz web
o use la línea de comandos:

```bash
./host/flash-team.sh --team 0 --disk /dev/DISK
# repita con --team 1 ... --team 9
```

Cada comando destructivo muestra el disco seleccionado y exige una confirmación
exacta. Además, verifica tanto la imagen descargada/comprimida como los bytes
leídos de cada tarjeta SD terminada. Consulte [host/WORKFLOW.md](host/WORKFLOW.md)
para ver el procedimiento detallado del operador.

## Configuración de red sin conocer el Wi-Fi del recinto

Si no hay una conexión guardada para el recinto, `equipoN` crea el punto de
acceso abierto de configuración `equipoN-setup` en `10.42.N.1`. Al conectarse,
la pantalla de inicio de sesión de la red debe abrirse automáticamente en
iPhone/iPad, macOS, Windows y Android. Windows puede mostrar primero una
notificación **Action needed**. Si el sistema operativo no muestra nada, abra:

```text
http://10.42.N.1:8080/
```

La tarjeta `admin` usa `admin-setup`, `http://10.42.10.1:8080/` y
`http://admin.local:6080/control.html`.

La página busca redes Wi-Fi y guarda las credenciales enviadas directamente en
NetworkManager. Nunca las escribe en este repositorio ni en los registros de la
aplicación. Después de que la placa cambie de red, vuelva a conectar el
teléfono o la laptop al Wi-Fi del recinto y use `equipoN.local`.

La ZERO 3W tiene un solo radio Wi-Fi, por lo que no se presupone que el punto de
acceso de configuración y la conexión cliente al recinto funcionen al mismo
tiempo. Si la red del recinto aísla a los clientes, los participantes no podrán
acceder al noVNC local aunque Telegram sí funcione. Para un taller de 50
personas, la solución confiable es un router o punto de acceso exclusivo para el
taller; el punto de acceso de cada placa sirve para incorporación y
recuperación, no para sustituir una red Wi-Fi enrutada.

USB-C NCM puede servir como ruta de rescate después de activar el **modo de
periférico OTG** y el servicio `radxa-ncm@*.*` mediante `rsetup` de Radxa en
cada placa. Cuando existe `usb0`, la placa ofrece `10.55.N.1`. Pruebe
antes del evento los cables y hubs exactos, así como las laptops macOS y
Windows; no dé por hecho que todos los puertos de laptop pueden alimentar una
placa de manera confiable.

## Configurar el agente después de clonar

Asigne a cada placa su propia clave de API o clave virtual de LiteLLM y su
propio token de bot de Telegram. Nunca coloque la clave maestra de LiteLLM en
una placa. Para uno a cinco usuarios de Telegram:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

Para una puerta de enlace LiteLLM central:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://YOUR-GATEWAY.example/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

El comando solicita la clave de API o clave virtual y el token del bot sin
mostrarlos en pantalla. También admite archivos de secretos accesibles solo por
root para automatización del instructor. Los detalles y el flujo opcional para
Discord están en [device/agent/README.md](device/agent/README.md).

## Enlaces para el día del taller

Para el equipo `N`:

| Propósito | Dirección |
|---|---|
| Configuración del Wi-Fi | `http://10.42.N.1:8080/` |
| Control de noVNC | `http://equipoN.local:6080/control.html` |
| noVNC de solo lectura | `http://equipoN.local:6080/view.html` |
| SSH | `ssh cdmx@equipoN.local` |
| Rescate por USB | `http://10.55.N.1:6080/view.html` |

Ejecute `sudo cdmx-network reset` para olvidar el Wi-Fi del recinto y restaurar
el punto de acceso de configuración.

## Ejemplo de optimización bayesiana

El ejemplo reproducible que los participantes pueden clonar y ejecutar vive en
[`aspuru-guzik-group/cdmx-bayesopt`](https://github.com/aspuru-guzik-group/cdmx-bayesopt).
Está diseñada específicamente para la ZERO 3W de 1 GB y puede controlar una
función de prueba o un experimento físico mediante una función de Python.

## Límites de confiabilidad y seguridad

- El registro por diario de ext4, zram, registros volátiles de tamaño limitado,
  actualizaciones de seguridad desatendidas, servicios systemd reiniciables y
  claves de host únicas después de clonar reducen el desgaste de la tarjeta SD
  y permiten la recuperación automática tras ciclos normales de apagado y
  encendido.
- Una pérdida repentina de energía aún puede dañar cualquier tarjeta SD con
  permisos de escritura. Mantenga tarjetas de repuesto ya probadas y use
  `sudo poweroff` siempre que sea posible.
- VNC directo escucha únicamente en loopback. El Wi-Fi de configuración y
  noVNC no tienen contraseña deliberadamente para el taller, por lo que
  cualquier persona en esas redes locales puede ver/controlar el escritorio.
  La cuenta `cdmx` también tiene `sudo` sin contraseña para los ejercicios de
  hardware. No exponga estas interfaces a Internet pública. SSH acepta
  únicamente claves públicas.
- PicoClaw está fijado a una versión concreta porque aún no llega a v1. Se
  ejecuta sin sudo como usuario independiente, con aislamiento de systemd y un
  único espacio de trabajo con permisos de escritura, pero la ejecución remota
  de código sigue habilitada intencionalmente para el ejercicio. Use solo listas
  explícitas de cinco personas autorizadas y credenciales desechables para cada
  equipo.

Ejecute `make test` para correr las verificaciones del repositorio.

Referencias principales: [descargas de Radxa ZERO 3](https://docs.radxa.com/en/zero/zero3/download),
[instalación de Radxa](https://docs.radxa.com/en/zero/zero3/getting-started/install-os),
[configuración del punto de acceso de Radxa](https://docs.radxa.com/en/zero/zero3/radxa-os/ap),
[red USB de Radxa](https://docs.radxa.com/en/zero/zero3/radxa-os/usbnet),
[PicoClaw](https://github.com/sipeed/picoclaw),
[Pi](https://pi.dev/docs/latest/quickstart) y
[noVNC](https://github.com/novnc/noVNC).
