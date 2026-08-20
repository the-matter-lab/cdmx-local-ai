#!/usr/bin/env python3
"""Small CLI for the workshop TCS34725 and one SPI NeoPixel."""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path


def resolve_i2c_bus(value: str = "auto", root: str | Path = "/sys/class/i2c-dev") -> int:
    if value != "auto":
        number = int(value)
        if number < 0:
            raise ValueError("I2C bus must be non-negative")
        return number

    adapters: list[tuple[int, str]] = []
    for path in Path(root).glob("i2c-*"):
        try:
            number = int(path.name.removeprefix("i2c-"))
            name = (path / "name").read_text(encoding="utf-8").strip()
        except (OSError, ValueError):
            continue
        adapters.append((number, name))

    exact = sorted(
        number
        for number, name in adapters
        if name == "i2c-gpio-cdmx" or name.endswith(".i2c-gpio-cdmx")
    )
    if exact:
        return exact[0]
    gpio = sorted(number for number, name in adapters if "i2c-gpio" in name)
    if len(gpio) == 1:
        return gpio[0]
    if any(number == 4 for number, _name in adapters):
        return 4
    raise OSError("CDMX I2C adapter not found; check the sensor wiring and reboot")


def parse_color(value: str) -> tuple[int, int, int]:
    cleaned = value.strip().removeprefix("#")
    if len(cleaned) != 6:
        raise ValueError("color must be #RRGGBB")
    try:
        return tuple(int(cleaned[offset : offset + 2], 16) for offset in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as exc:
        raise ValueError("color must be #RRGGBB") from exc


def encode_ws2812(color: tuple[int, int, int], brightness: float) -> bytes:
    if not math.isfinite(brightness) or not 0.0 <= brightness <= 1.0:
        raise ValueError("brightness must be between 0 and 1")
    red, green, blue = color
    ordered = (round(green * brightness), round(red * brightness), round(blue * brightness))
    bits: list[int] = []
    for channel in ordered:
        for bit in range(7, -1, -1):
            bits.extend((1, 1, 0) if channel & (1 << bit) else (1, 0, 0))
    payload = bytearray()
    for offset in range(0, len(bits), 8):
        byte = 0
        for bit in bits[offset : offset + 8]:
            byte = (byte << 1) | bit
        payload.append(byte)
    return bytes(24) + bytes(payload) + bytes(24)


def set_led(
    color: tuple[int, int, int],
    brightness: float,
    bus: int = 3,
    device: int = 0,
    spi_factory=None,
) -> dict[str, object]:
    if spi_factory is None:
        import spidev

        connection = spidev.SpiDev()
        connection.open(bus, device)
    else:
        connection = spi_factory(bus, device)
    connection.max_speed_hz = 2_400_000
    connection.mode = 0
    payload = encode_ws2812(color, brightness)
    try:
        if hasattr(connection, "writebytes2"):
            connection.writebytes2(list(payload))
        else:
            connection.xfer2(list(payload))
    finally:
        connection.close()
    return {
        "led": "on" if any(color) and brightness else "off",
        "hex": "#" + "".join(f"{channel:02X}" for channel in color),
        "rgb": list(color),
        "brightness": brightness,
        "device": f"/dev/spidev{bus}.{device}",
    }


def read_sensor(bus_number: int, bus_factory=None) -> dict[str, object]:
    if bus_factory is None:
        try:
            from smbus2 import SMBus
        except ImportError:
            from smbus import SMBus

        connection = SMBus(bus_number)
    else:
        connection = bus_factory(bus_number)

    address = 0x29
    command = 0x80
    auto_increment = 0x20
    integration_ms = 153.6
    cycles = round(integration_ms / 2.4)
    try:
        connection.write_byte_data(address, command | 0x01, 256 - cycles)
        connection.write_byte_data(address, command | 0x0F, 0x01)
        connection.write_byte_data(address, command | 0x00, 0x01)
        time.sleep(0.003)
        connection.write_byte_data(address, command | 0x00, 0x03)
        time.sleep(integration_ms / 1000.0)
        status = connection.read_byte_data(address, command | 0x13)
        if not status & 0x01:
            raise OSError("TCS34725 sample is not ready")
        data = connection.read_i2c_block_data(address, command | auto_increment | 0x14, 8)
        if len(data) != 8:
            raise OSError(f"TCS34725 returned {len(data)} bytes instead of 8")
    finally:
        try:
            connection.write_byte_data(address, command | 0x00, 0x00)
        finally:
            close = getattr(connection, "close", None)
            if close:
                close()

    clear, red, green, blue = (
        data[offset] | (data[offset + 1] << 8) for offset in range(0, 8, 2)
    )
    peak = max(red, green, blue, 1)
    rgb = [round(channel * 255 / peak) for channel in (red, green, blue)]
    return {
        "sensor": "TCS34725",
        "timestamp": time.time(),
        "i2c_bus": bus_number,
        "raw": {"clear": clear, "red": red, "green": green, "blue": blue},
        "normalized_rgb": rgb,
        "normalized_hex": "#" + "".join(f"{channel:02X}" for channel in rgb),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    led = subparsers.add_parser("led", help="set the NeoPixel color")
    led.add_argument("color", help="#RRGGBB; use #000000 to turn it off")
    led.add_argument("--brightness", type=float, default=0.25)
    led.add_argument("--spi-bus", type=int, default=3)
    led.add_argument("--spi-device", type=int, default=0)
    sensor = subparsers.add_parser("sensor", help="read one TCS34725 sample")
    sensor.add_argument("--i2c-bus", default="auto")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "led":
            result = set_led(
                parse_color(args.color), args.brightness, args.spi_bus, args.spi_device
            )
        else:
            result = read_sensor(resolve_i2c_bus(args.i2c_bus))
    except (ImportError, OSError, ValueError) as exc:
        print(f"hardware error: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
