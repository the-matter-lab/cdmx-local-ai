import importlib.util
import pathlib
import tempfile
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "workspace" / "tools" / "cdmx_hardware.py"
SPEC = importlib.util.spec_from_file_location("cdmx_hardware", MODULE_PATH)
hardware = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(hardware)


class FakeSPI:
    def __init__(self):
        self.written = None
        self.closed = False
        self.max_speed_hz = None
        self.mode = None

    def writebytes2(self, data):
        self.written = data

    def close(self):
        self.closed = True


class FakeI2C:
    def __init__(self):
        self.writes = []
        self.closed = False

    def write_byte_data(self, address, register, value):
        self.writes.append((address, register, value))

    def read_byte_data(self, _address, _register):
        return 1

    def read_i2c_block_data(self, _address, _register, _length):
        # clear=1000, red=300, green=600, blue=900
        return [232, 3, 44, 1, 88, 2, 132, 3]

    def close(self):
        self.closed = True


class HardwareTests(unittest.TestCase):
    def test_color_parser_and_ws2812_payload(self):
        self.assertEqual(hardware.parse_color("#12aBef"), (18, 171, 239))
        self.assertEqual(len(hardware.encode_ws2812((1, 2, 3), 0.25)), 57)
        with self.assertRaises(ValueError):
            hardware.parse_color("purple")

    def test_led_writes_spi_and_leaves_the_requested_color_latched(self):
        spi = FakeSPI()
        result = hardware.set_led((102, 51, 255), 0.2, spi_factory=lambda _b, _d: spi)
        self.assertEqual(result["hex"], "#6633FF")
        self.assertEqual(len(spi.written), 57)
        self.assertTrue(spi.closed)

    @mock.patch.object(hardware.time, "sleep", return_value=None)
    def test_sensor_returns_raw_and_normalized_reading(self, _sleep):
        connection = FakeI2C()
        result = hardware.read_sensor(11, bus_factory=lambda _number: connection)
        self.assertEqual(result["raw"], {"clear": 1000, "red": 300, "green": 600, "blue": 900})
        self.assertEqual(result["normalized_rgb"], [85, 170, 255])
        self.assertTrue(connection.closed)

    def test_named_i2c_adapter_wins_over_legacy_bus(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            for number, name in ((4, "rk3x-i2c"), (11, "i2c-gpio-cdmx")):
                adapter = root / f"i2c-{number}"
                adapter.mkdir()
                (adapter / "name").write_text(name, encoding="utf-8")
            self.assertEqual(hardware.resolve_i2c_bus("auto", root), 11)


if __name__ == "__main__":
    unittest.main()
