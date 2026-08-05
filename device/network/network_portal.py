#!/usr/bin/env python3
"""Local-only Wi-Fi onboarding portal for the CDMX workshop image."""

from __future__ import annotations

import html
import ipaddress
import json
import os
from pathlib import Path
import secrets
import subprocess
import threading
import time
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CONFIG_PATH = Path(os.environ.get("CDMX_CONFIG", "/etc/cdmx/workshop.conf"))
TOKEN_PATH = Path(os.environ.get("CDMX_PORTAL_TOKEN", "/run/cdmx/network-portal-token"))
LOGO_PATH = Path(os.environ.get("CDMX_PORTAL_LOGO", "/usr/local/share/cdmx/matter-lab-logo.svg"))
MAX_BODY = 4096


def validate_identity(value: object) -> int | str:
    if value == "admin":
        return "admin"
    if isinstance(value, bool):
        raise ValueError("TEAM must be admin or between 0 and 9")
    try:
        team = int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError) as exc:
        raise ValueError("TEAM must be admin or between 0 and 9") from exc
    if team not in range(10) or str(value) != str(team):
        raise ValueError("TEAM must be admin or between 0 and 9")
    return team


def identity_index(identity: object) -> int:
    validated = validate_identity(identity)
    return 10 if validated == "admin" else validated


def identity_hostname(identity: object) -> str:
    validated = validate_identity(identity)
    return "admin" if validated == "admin" else f"equipo{validated}"


def portal_url(identity: object) -> str:
    return f"http://10.42.{identity_index(identity)}.1:8080/"


def captive_api(identity: object) -> str:
    return json.dumps(
        {"captive": True, "user-portal-url": portal_url(identity)},
        separators=(",", ":"),
    )


def read_config(path: Path = CONFIG_PATH) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        if key in {"TEAM", "AP_SSID", "WIFI_COUNTRY", "NETWORK_INDEX"}:
            result[key] = value
    identity = validate_identity(result.get("TEAM", "0"))
    hostname = identity_hostname(identity)
    index = identity_index(identity)
    if result.get("AP_SSID") != f"{hostname}-setup":
        raise ValueError("AP_SSID does not match TEAM")
    if result.get("NETWORK_INDEX", str(index)) != str(index):
        raise ValueError("NETWORK_INDEX does not match TEAM")
    result["TEAM"] = str(identity)
    result["NETWORK_INDEX"] = str(index)
    result.setdefault("WIFI_COUNTRY", "MX")
    return result


def split_nmcli(line: str) -> list[str]:
    """Split nmcli's colon format, honoring backslash escapes."""
    fields: list[str] = []
    current: list[str] = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append("\\")
    fields.append("".join(current))
    return fields


def wifi_interface() -> str:
    output = subprocess.run(
        ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"],
        check=True,
        capture_output=True,
        text=True,
        timeout=10,
    ).stdout
    for line in output.splitlines():
        parts = split_nmcli(line)
        if len(parts) >= 2 and parts[1] == "wifi":
            return parts[0]
    raise RuntimeError("No Wi-Fi interface found")


def validate_credentials(ssid: str, password: str, open_network: bool) -> None:
    size = len(ssid.encode("utf-8"))
    if size < 1 or size > 32 or "\x00" in ssid or "\n" in ssid or "\r" in ssid:
        raise ValueError("SSID must contain 1-32 bytes")
    if open_network:
        if password:
            raise ValueError("Leave the password blank for an open network")
    elif len(password) < 8 or len(password) > 63 or any(c in password for c in "\x00\r\n"):
        raise ValueError("Wi-Fi password must contain 8-63 characters")


def configure_venue(ssid: str, password: str, open_network: bool) -> None:
    """Replace the venue profile and activate it without invoking a shell."""
    iface = wifi_interface()
    subprocess.run(
        ["nmcli", "connection", "delete", "cdmx-venue"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=15,
    )
    subprocess.run(
        [
            "nmcli", "connection", "add", "type", "wifi", "ifname", iface,
            "con-name", "cdmx-venue", "ssid", ssid,
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=20,
    )
    common = [
        "nmcli", "connection", "modify", "cdmx-venue",
        "connection.autoconnect", "yes", "connection.autoconnect-priority", "100",
        "802-11-wireless.cloned-mac-address", "permanent",
        "ipv4.method", "auto", "ipv6.method", "auto",
    ]
    subprocess.run(common, check=True, capture_output=True, text=True, timeout=20)
    if not open_network:
        # nmcli receives argv directly, so metacharacters are never shell-expanded.
        subprocess.run(
            [
                "nmcli", "connection", "modify", "cdmx-venue",
                "802-11-wireless-security.key-mgmt", "wpa-psk",
                "802-11-wireless-security.psk", password,
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=20,
        )
    subprocess.run(
        ["nmcli", "--wait", "45", "connection", "up", "cdmx-venue"],
        check=True,
        capture_output=True,
        text=True,
        timeout=55,
    )


def allowed_client(address: str, identity: object) -> bool:
    try:
        ip = ipaddress.ip_address(address)
    except ValueError:
        return False
    if ip.is_loopback:
        return True
    index = identity_index(identity)
    return ip in ipaddress.ip_network(f"10.42.{index}.0/24") or ip in ipaddress.ip_network(
        f"10.55.{index}.0/24"
    )


class PortalHandler(BaseHTTPRequestHandler):
    server_version = "CDMXOnboarding/1"

    @property
    def app(self) -> "PortalServer":
        return self.server  # type: ignore[return-value]

    def log_message(self, fmt: str, *args: object) -> None:
        # Never log form bodies or credentials.
        print(f"portal {self.client_address[0]} {fmt % args}", flush=True)

    def _allowed(self) -> bool:
        if allowed_client(self.client_address[0], self.app.identity):
            return True
        self.send_error(HTTPStatus.FORBIDDEN, "Use this device's setup or USB network")
        return False

    def _send(self, body: str, status: HTTPStatus = HTTPStatus.OK, cookie: bool = False) -> None:
        payload = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'")
        if cookie:
            self.send_header("Set-Cookie", f"cdmx_csrf={self.app.token}; Path=/; HttpOnly; SameSite=Strict")
        self.end_headers()
        self.wfile.write(payload)

    def _send_captive_api(self) -> None:
        payload = captive_api(self.app.identity).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/captive+json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _send_logo(self) -> None:
        payload = LOGO_PATH.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "image/svg+xml")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "public, max-age=86400")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _redirect_to_portal(self) -> None:
        self.send_response(HTTPStatus.FOUND)
        self.send_header("Location", portal_url(self.app.identity))
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if not self._allowed():
            return
        path = urlparse(self.path).path
        if self.server.server_port == 80:
            self._redirect_to_portal()
            return
        if path == "/healthz":
            self._send("ok")
            return
        if path == "/captive-api":
            self._send_captive_api()
            return
        if path == "/matter-lab-logo.svg":
            self._send_logo()
            return
        if path not in {"/", "/index.html"}:
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        hostname = self.app.hostname
        title = "Admin" if self.app.identity == "admin" else f"Equipo {self.app.identity}"
        body = f"""<!doctype html>
<html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} network setup</title>
<style>body{{font:17px system-ui;max-width:36rem;margin:2rem auto;padding:0 1rem;background:#192b28;color:#fff}}.logo{{display:block;width:min(260px,70vw);height:auto;margin:0 0 2.5rem}}h1{{margin-bottom:.35rem}}p{{color:#dbe6e3}}label{{display:block;margin-top:1rem;font-weight:650}}input,button{{box-sizing:border-box;width:100%;padding:.85rem;margin-top:.4rem;border-radius:7px;font:inherit}}input{{border:1px solid #8ba09b;background:#fff;color:#192b28}}button{{background:#12f98b;color:#192b28;border:0;font-weight:800;cursor:pointer}}small{{color:#b9cbc7}}</style>
<img class="logo" src="/matter-lab-logo.svg" alt="The Matter Lab">
<h1>{title}</h1><p>Enter the venue Wi-Fi. The setup hotspot will disappear while the board joins it.</p>
<form method="post" action="/connect">
<input type="hidden" name="csrf" value="{html.escape(self.app.token, quote=True)}">
<label>Wi-Fi name (SSID)<input name="ssid" maxlength="32" autocomplete="off" required autofocus></label>
<label>Password<input name="password" type="password" maxlength="63" autocomplete="new-password"></label>
<label><input style="width:auto" name="open" type="checkbox" value="1"> This network is open</label>
<button type="submit">Connect {hostname}</button></form>
<p><small>After connecting your phone to the venue Wi-Fi, open http://{hostname}.local:6080/control.html</small></p></html>"""
        self._send(body, cookie=True)

    def do_POST(self) -> None:  # noqa: N802
        if not self._allowed():
            return
        if urlparse(self.path).path != "/connect":
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length < 1 or length > MAX_BODY:
            self.send_error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
            return
        values = parse_qs(self.rfile.read(length).decode("utf-8", errors="strict"), keep_blank_values=True)
        cookie = SimpleCookie(self.headers.get("Cookie", ""))
        cookie_token = cookie.get("cdmx_csrf")
        form_token = values.get("csrf", [""])[0]
        if not cookie_token or not secrets.compare_digest(cookie_token.value, self.app.token) or not secrets.compare_digest(form_token, self.app.token):
            self.send_error(HTTPStatus.FORBIDDEN, "Invalid setup token")
            return
        ssid = values.get("ssid", [""])[0]
        password = values.get("password", [""])[0]
        open_network = values.get("open", [""])[0] == "1"
        try:
            validate_credentials(ssid, password, open_network)
        except ValueError as exc:
            self._send(f"<h1>Check the form</h1><p>{html.escape(str(exc))}</p><p><a href='/'>Try again</a></p>", HTTPStatus.BAD_REQUEST)
            return
        self._send(
            f"<h1>Connecting {self.app.hostname}</h1><p>Reconnect your device to the venue Wi-Fi, then open <strong>http://{self.app.hostname}.local:6080/control.html</strong>.</p>"
        )
        threading.Thread(
            target=self.app.activate_later,
            args=(ssid, password, open_network),
            daemon=True,
        ).start()


class PortalServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], config: dict[str, str], token: str):
        super().__init__(address, PortalHandler)
        self.config = config
        self.identity = validate_identity(config["TEAM"])
        self.index = identity_index(self.identity)
        self.hostname = identity_hostname(self.identity)
        self.token = token

    @staticmethod
    def activate_later(ssid: str, password: str, open_network: bool) -> None:
        time.sleep(1.5)
        try:
            configure_venue(ssid, password, open_network)
        except Exception as exc:
            # The exception never includes the submitted password.
            print(f"Wi-Fi activation failed: {type(exc).__name__}", flush=True)
            subprocess.run(["/usr/local/sbin/cdmx-network", "ap"], check=False, timeout=45)


def main() -> None:
    config = read_config()
    token = secrets.token_urlsafe(24)
    TOKEN_PATH.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    TOKEN_PATH.write_text(token + "\n", encoding="ascii")
    TOKEN_PATH.chmod(0o600)
    portal = PortalServer(("0.0.0.0", 8080), config, token)
    redirect = PortalServer(("0.0.0.0", 80), config, token)
    redirect_thread = threading.Thread(target=redirect.serve_forever, daemon=True)
    redirect_thread.start()
    try:
        portal.serve_forever()
    finally:
        redirect.shutdown()
        redirect.server_close()
        portal.server_close()


if __name__ == "__main__":
    main()
