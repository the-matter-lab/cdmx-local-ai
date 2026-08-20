---
name: color-sensor
description: Read or report the workshop TCS34725 color sensor connected to the Radxa ZERO 3W.
---

# Sensor de color

Read one fresh sample with:

```bash
python3 "$HOME/workspace/cdmx-local-ai/tools/cdmx_hardware.py" sensor
```

Report the raw clear/red/green/blue counts as measurements. The normalized RGB
and hex values are only a convenient color preview, not calibrated physical
units. If the tool fails, explain the error and suggest checking physical pins
4 (5 V), 6 (GND), 8 (SCL), and 10 (SDA); never use `sudo`.
