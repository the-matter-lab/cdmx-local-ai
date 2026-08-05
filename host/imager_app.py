#!/usr/bin/env python3
"""Loopback-only, one-authorization SD-card imager for the CDMX workshop."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import subprocess
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import BinaryIO, Callable


ROOT = Path(__file__).resolve().parents[1]
UI_PATH = ROOT / "host" / "imager_ui.html"
STOCK_ENV = ROOT / "image" / "radxa-zero3-bookworm-kde-rsdk-b1.env"
GOLDEN_IMAGE = ROOT / "image" / "cdmx-workshop-golden.img.xz"
DISK_PATTERN = re.compile(r"^/dev/disk[0-9]+$")
CHUNK_SIZE = 4 * 1024 * 1024


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def parse_diskutil_info(output: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in output.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        result[key.strip()] = value.strip()
    return result


def disk_size(info: dict[str, str]) -> int:
    match = re.search(r"\(([0-9]+) Bytes", info.get("Disk Size", ""))
    return int(match.group(1)) if match else 0


def disk_is_safe(disk: str, info: dict[str, str]) -> bool:
    if not DISK_PATTERN.fullmatch(disk) or disk == "/dev/disk0":
        return False
    if info.get("Whole") != "Yes" or disk_size(info) < 4_000_000_000:
        return False
    removable = info.get("Removable Media") in {"Yes", "Removable"}
    external = info.get("Device Location") == "External"
    usb = info.get("Protocol") == "USB"
    internal = info.get("Device Location") == "Internal" or info.get("Internal") == "Yes"
    if internal and not removable:
        return False
    return removable or external or usb


def command(arguments: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, check=check, text=True, capture_output=True)


def disk_info(disk: str) -> dict[str, str]:
    if not DISK_PATTERN.fullmatch(disk):
        raise ValueError("invalid whole-disk identifier")
    return parse_diskutil_info(command(["diskutil", "info", disk]).stdout)


def list_safe_disks() -> list[dict[str, object]]:
    listing = command(["diskutil", "list"], check=False).stdout
    candidates = re.findall(r"^(/dev/disk[0-9]+) \([^\n]*physical\):", listing, re.MULTILINE)
    disks: list[dict[str, object]] = []
    for disk in candidates:
        try:
            info = disk_info(disk)
        except (OSError, subprocess.SubprocessError, ValueError):
            continue
        if not disk_is_safe(disk, info):
            continue
        disks.append(
            {
                "id": disk,
                "name": info.get("Device / Media Name", "Removable disk"),
                "size": disk_size(info),
                "protocol": info.get("Protocol", "Unknown"),
                "removable": info.get("Removable Media", "Unknown"),
            }
        )
    return disks


def raw_disk_path(disk: str) -> str:
    if not DISK_PATTERN.fullmatch(disk):
        raise ValueError("invalid whole-disk identifier")
    return "/dev/r" + disk.removeprefix("/dev/")


def validate_team(team: object) -> int | str:
    if team == "admin":
        return "admin"
    if isinstance(team, bool) or not isinstance(team, int) or team not in range(10):
        raise ValueError("identity must be admin or an integer from 0 through 9")
    return team


def identity_name(identity: object) -> str:
    validated = validate_team(identity)
    return "admin" if validated == "admin" else f"equipo{validated}"


def xz_uncompressed_size(path: Path) -> int:
    output = command(["xz", "--robot", "--list", str(path)]).stdout
    for line in output.splitlines():
        fields = line.split("\t")
        if fields and fields[0] == "totals" and len(fields) > 4:
            return int(fields[4])
    raise ValueError("could not determine uncompressed image size")


def sha512_sidecar(path: Path) -> str:
    sidecar = Path(str(path) + ".sha512")
    if not sidecar.is_file():
        raise FileNotFoundError(f"missing checksum: {sidecar.name}")
    value = sidecar.read_text(encoding="utf-8").split()[0].lower()
    if not re.fullmatch(r"[0-9a-f]{128}", value):
        raise ValueError(f"invalid checksum: {sidecar.name}")
    return value


def image_catalog() -> dict[str, dict[str, object]]:
    stock = parse_env(STOCK_ENV)
    stock_path = ROOT / "image" / "cache" / stock["IMAGE_FILENAME"]
    stock_ready = stock_path.is_file()
    golden_ready = GOLDEN_IMAGE.is_file() and Path(str(GOLDEN_IMAGE) + ".sha512").is_file()
    return {
        "stock": {
            "ready": stock_ready,
            "name": stock_path.name,
            "size": stock_path.stat().st_size if stock_ready else 0,
        },
        "golden": {
            "ready": golden_ready,
            "name": GOLDEN_IMAGE.name,
            "size": GOLDEN_IMAGE.stat().st_size if golden_ready else 0,
        },
    }


class JobState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.running_lock = threading.Lock()
        self.data: dict[str, object] = {
            "running": False,
            "phase": "idle",
            "label": "Ready",
            "progress": 0.0,
            "stage_percent": 0.0,
            "bytes_done": 0,
            "bytes_total": 0,
            "speed_mbps": 0.0,
            "eta_seconds": None,
            "disk": None,
            "team": None,
            "mode": None,
            "error": None,
            "logs": [],
        }

    def update(self, **changes: object) -> None:
        with self.lock:
            self.data.update(changes)

    def log(self, message: str) -> None:
        with self.lock:
            logs = list(self.data.get("logs", []))
            logs.append(message)
            self.data["logs"] = logs[-30:]

    def reserve(self) -> bool:
        with self.lock:
            if self.data.get("running"):
                return False
            self.data.update(running=True, phase="queued", label="Queued", error=None)
            return True

    def snapshot(self) -> dict[str, object]:
        with self.lock:
            snapshot = dict(self.data)
            snapshot["logs"] = list(self.data.get("logs", []))
        snapshot["disks"] = list_safe_disks()
        snapshot["images"] = image_catalog()
        return snapshot


STATE = JobState()


def progress_values(done: int, total: int, start: float) -> tuple[float, float, float | None]:
    elapsed = max(time.monotonic() - start, 0.001)
    speed = done / elapsed
    percent = min(100.0, done * 100.0 / max(total, 1))
    eta = (total - done) / speed if speed > 0 and done < total else None
    return percent, speed / 1_000_000, eta


def hash_file(path: Path, expected: str) -> None:
    total = path.stat().st_size
    done = 0
    digest = hashlib.sha512()
    start = time.monotonic()
    with path.open("rb") as source:
        while chunk := source.read(CHUNK_SIZE):
            digest.update(chunk)
            done += len(chunk)
            stage, speed, eta = progress_values(done, total, start)
            STATE.update(
                phase="checksum",
                label="Checking image",
                progress=stage * 0.05,
                stage_percent=stage,
                bytes_done=done,
                bytes_total=total,
                speed_mbps=speed,
                eta_seconds=eta,
            )
    if digest.hexdigest().lower() != expected.lower():
        raise ValueError("compressed-image checksum mismatch")


def write_all(destination: BinaryIO, chunk: bytes) -> None:
    view = memoryview(chunk)
    while view:
        written = destination.write(view)
        if written is None or written <= 0:
            raise OSError("SD-card write returned no data")
        view = view[written:]


def write_image(image: Path, raw_disk: str, total: int) -> str:
    digest = hashlib.sha512()
    done = 0
    start = time.monotonic()
    process = subprocess.Popen(
        ["xz", "-dc", "--", str(image)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdout is not None
    try:
        with open(raw_disk, "wb", buffering=0) as destination:
            while chunk := process.stdout.read(CHUNK_SIZE):
                write_all(destination, chunk)
                digest.update(chunk)
                done += len(chunk)
                stage, speed, eta = progress_values(done, total, start)
                STATE.update(
                    phase="write",
                    label="Writing RadxaOS",
                    progress=5.0 + stage * 0.60,
                    stage_percent=stage,
                    bytes_done=done,
                    bytes_total=total,
                    speed_mbps=speed,
                    eta_seconds=eta,
                )
            os.fsync(destination.fileno())
    except BaseException:
        process.kill()
        process.wait()
        raise
    stderr = (process.stderr.read() if process.stderr else b"").decode(errors="replace")
    return_code = process.wait()
    if return_code != 0:
        raise OSError(f"xz failed ({return_code}): {stderr.strip()}")
    if done != total:
        raise OSError(f"image produced {done} bytes; expected {total}")
    command(["sync"])
    return digest.hexdigest()


def verify_image(raw_disk: str, total: int, expected: str) -> None:
    digest = hashlib.sha512()
    done = 0
    start = time.monotonic()
    with open(raw_disk, "rb", buffering=0) as source:
        while done < total:
            chunk = source.read(min(CHUNK_SIZE, total - done))
            if not chunk:
                raise OSError("SD card ended before verification completed")
            digest.update(chunk)
            done += len(chunk)
            stage, speed, eta = progress_values(done, total, start)
            STATE.update(
                phase="verify",
                label="Verifying written bytes",
                progress=65.0 + stage * 0.33,
                stage_percent=stage,
                bytes_done=done,
                bytes_total=total,
                speed_mbps=speed,
                eta_seconds=eta,
            )
    if digest.hexdigest() != expected:
        raise OSError("read-back verification failed")


def select_image(mode: str) -> tuple[Path, str]:
    if mode == "stock":
        values = parse_env(STOCK_ENV)
        path = ROOT / "image" / "cache" / values["IMAGE_FILENAME"]
        expected = values["IMAGE_SHA512"].lower()
    elif mode == "team":
        path = GOLDEN_IMAGE
        expected = sha512_sidecar(path)
    else:
        raise ValueError("mode must be stock or team")
    if not path.is_file():
        raise FileNotFoundError(f"image not found: {path.name}")
    return path, expected


def ensure_disk(disk: str, required_bytes: int = 0) -> dict[str, str]:
    info = disk_info(disk)
    if not disk_is_safe(disk, info):
        raise ValueError("selected disk is not a safe removable whole disk")
    if required_bytes and disk_size(info) < required_bytes:
        raise ValueError("selected SD card is smaller than the image")
    return info


def flash_job(disk: str, mode: str, team: int | str | None) -> None:
    with STATE.running_lock:
        try:
            STATE.update(
                running=True,
                phase="starting",
                label="Preparing",
                progress=0.0,
                stage_percent=0.0,
                bytes_done=0,
                bytes_total=0,
                speed_mbps=0.0,
                eta_seconds=None,
                disk=disk,
                team=team,
                mode=mode,
                error=None,
                logs=[],
            )
            if os.geteuid() != 0:
                raise PermissionError("start the imager with administrator privileges")
            if mode == "team":
                team = validate_team(team)
            elif team is not None:
                raise ValueError("stock-master mode does not accept a team number")

            image, compressed_sha = select_image(mode)
            total = xz_uncompressed_size(image)
            ensure_disk(disk, total)
            STATE.log(f"Target: {disk}")
            STATE.log(f"Image: {image.name}")
            hash_file(image, compressed_sha)
            STATE.log("Compressed checksum passed")

            ensure_disk(disk, total)
            command(["diskutil", "unmountDisk", disk])
            raw = raw_disk_path(disk)
            source_sha = write_image(image, raw, total)
            STATE.log("Write completed; starting read-back")
            verify_image(raw, total, source_sha)
            STATE.log("Read-back checksum passed")

            if mode == "team":
                name = identity_name(team)
                STATE.update(
                    phase="provision",
                    label=f"Assigning {name}",
                    progress=98.5,
                    stage_percent=50.0,
                )
                command(
                    [
                        str(ROOT / "host" / "provision-team.sh"),
                        "--disk",
                        disk,
                        "--team",
                        str(team),
                    ]
                )
                STATE.log(f"Assigned {name}")

            STATE.update(phase="eject", label="Ejecting safely", progress=99.5)
            command(["diskutil", "eject", disk])
            label = "Stock master ready" if mode == "stock" else f"{identity_name(team)} ready"
            STATE.log("Safe to remove the SD card")
            STATE.update(
                running=False,
                phase="done",
                label=label,
                progress=100.0,
                stage_percent=100.0,
                bytes_done=total,
                bytes_total=total,
                speed_mbps=0.0,
                eta_seconds=0.0,
            )
        except Exception as exc:
            STATE.log(f"ERROR: {exc}")
            STATE.update(
                running=False,
                phase="error",
                label="Flash failed",
                error=str(exc),
                speed_mbps=0.0,
                eta_seconds=None,
            )


class ImagerHandler(BaseHTTPRequestHandler):
    server_version = "CDMXImager/1.0"

    def log_message(self, fmt: str, *args: object) -> None:
        return

    @property
    def token(self) -> str:
        return self.server.token  # type: ignore[attr-defined]

    def response(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def valid_host(self) -> bool:
        host = self.headers.get("Host", "").lower()
        port = self.server.server_address[1]
        return host in {f"127.0.0.1:{port}", f"localhost:{port}"}

    def json_response(self, status: int, payload: object) -> None:
        self.response(
            status,
            "application/json; charset=utf-8",
            (json.dumps(payload, separators=(",", ":")) + "\n").encode(),
        )

    def do_GET(self) -> None:  # noqa: N802
        if not self.valid_host():
            self.json_response(HTTPStatus.FORBIDDEN, {"error": "invalid host"})
            return
        if self.path == "/":
            nonce = secrets.token_urlsafe(16)
            html = UI_PATH.read_text(encoding="utf-8")
            html = html.replace("__CDMX_TOKEN__", self.token).replace("__CDMX_NONCE__", nonce)
            body = html.encode()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header(
                "Content-Security-Policy",
                f"default-src 'none'; script-src 'nonce-{nonce}'; style-src 'nonce-{nonce}'; connect-src 'self'; img-src 'self'",
            )
            self.send_header("X-Frame-Options", "DENY")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/state":
            self.json_response(HTTPStatus.OK, STATE.snapshot())
        else:
            self.json_response(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        if not self.valid_host():
            self.json_response(HTTPStatus.FORBIDDEN, {"error": "invalid host"})
            return
        if self.path != "/api/flash":
            self.json_response(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        if not secrets.compare_digest(self.headers.get("X-CDMX-Token", ""), self.token):
            self.json_response(HTTPStatus.FORBIDDEN, {"error": "invalid request token"})
            return
        if self.headers.get_content_type() != "application/json":
            self.json_response(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {"error": "JSON required"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 2 or length > 4096:
                raise ValueError("invalid request size")
            payload = json.loads(self.rfile.read(length))
            disk = payload.get("disk")
            team = payload.get("team")
            if not isinstance(disk, str) or not DISK_PATTERN.fullmatch(disk):
                raise ValueError("invalid disk")
            mode = payload.get("mode")
            if mode not in {"stock", "team"}:
                raise ValueError("invalid mode")
            if mode == "team":
                team = validate_team(team)
            else:
                team = None
            ensure_disk(disk)
        except (json.JSONDecodeError, OSError, subprocess.SubprocessError, ValueError) as exc:
            self.json_response(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            return
        if not STATE.reserve():
            self.json_response(HTTPStatus.CONFLICT, {"error": "a flash is already running"})
            return
        thread = threading.Thread(target=flash_job, args=(disk, mode, team), daemon=True)
        try:
            thread.start()
        except Exception:
            STATE.update(running=False, phase="error", label="Could not start flash")
            raise
        self.json_response(HTTPStatus.ACCEPTED, {"started": True})


class ImagerServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], token: str):
        self.token = token
        super().__init__(address, ImagerHandler)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args()
    if os.geteuid() != 0:
        print("Start with host/start-imager.command so macOS can authorize SD access.")
        return 77
    if not UI_PATH.is_file() or not STOCK_ENV.is_file():
        print("The imager must run from a complete cdmx-local-ai checkout.")
        return 66
    token = secrets.token_urlsafe(32)
    server = ImagerServer(("127.0.0.1", args.port), token)
    print(f"CDMX SD Imager: http://127.0.0.1:{args.port}/", flush=True)
    print("Keep this Terminal window open while flashing cards.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping CDMX SD Imager.", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
