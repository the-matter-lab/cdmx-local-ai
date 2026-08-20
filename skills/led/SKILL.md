---
name: led
description: Control, change, dim, or turn off the workshop NeoPixel LED connected to the Radxa ZERO 3W.
---

# LED del taller

Use the deterministic hardware tool; do not write directly to `/dev/spidev*`.

```bash
python3 "$HOME/workspace/cdmx-local-ai/tools/cdmx_hardware.py" led '#FF6600' --brightness 0.25
python3 "$HOME/workspace/cdmx-local-ai/tools/cdmx_hardware.py" led '#000000'
```

Translate color names to `#RRGGBB`. Keep brightness at or below `0.35` unless
the participant explicitly asks for more. Report the JSON result. If the tool
fails, explain the error and suggest checking physical pin 19 (DIN), pin 20
(GND), and the separate 5 V connection; never use `sudo`.
