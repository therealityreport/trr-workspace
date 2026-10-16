#!/usr/bin/env python3
"""Read-only readiness proof for the installed Project Manager Portless router.

This never starts a proxy, changes its markers, or alters routes. Startup health
is paired with the live process and a trusted TLS response; a manifest alone is
not evidence that the router is running with the required configuration.
"""
from __future__ import annotations

import http.client
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import time
from datetime import datetime
from typing import Callable

MANIFEST = Path("/Library/Application Support/Project Manager/Portless Router/release-manifest.json")
LAUNCHD_SERVICE = Path("/Library/LaunchDaemons/local.thomashulihan.projectmanager.portless-router.plist")
HEALTH_SUFFIX = Path("Library/Application Support/Project Manager/portless-router/health.json")


class RouterNotReady(ValueError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise RouterNotReady(message)


def managed_owner_present(
    manifest_path: Path = MANIFEST,
    *,
    service_path: Path = LAUNCHD_SERVICE,
    process_runner: Callable | None = None,
) -> bool:
    """Ownership survives an outage, invalid manifest, or missing ready markers."""
    for path in (manifest_path, service_path):
        try:
            path.lstat()
            return True
        except FileNotFoundError:
            continue
        except OSError:
            return True  # Unknown ownership cannot authorize a replacement proxy.
    process_runner = process_runner or subprocess.run
    try:
        process = process_runner(
            ["ps", "-ax", "-o", "command="], capture_output=True, text=True,
            timeout=2, check=False, env={**os.environ, "LC_ALL": "C"},
        )
        if process.returncode != 0:
            return True
    except (OSError, subprocess.SubprocessError):
        return True
    releases = re.escape(str(MANIFEST.parent / "releases"))
    command = re.compile(
        rf"{releases}/(?P<release>[a-f0-9]{{64}})/node/bin/node "
        rf"{releases}/(?P=release)/scripts/portless-router\.mjs --manifest {re.escape(str(manifest_path))}"
    )
    return any(command.fullmatch(line.strip()) for line in process.stdout.splitlines())


def _trusted_tls_probe(ca_certificate: Path) -> bool:
    context = ssl.create_default_context(cafile=str(ca_certificate))
    connection = http.client.HTTPSConnection("localhost", 443, timeout=2, context=context)
    try:
        # This host cannot match a route under the only allowed TLD, localhost.
        # The request therefore checks the router without contacting any app.
        connection.request("HEAD", "/", headers={"Host": "trr-router-readiness.invalid"})
        response = connection.getresponse()
        return response.status == 404 and response.getheader("X-Portless") == "1"
    finally:
        connection.close()


def verify_router(
    manifest_path: Path = MANIFEST,
    *,
    home: Path | None = None,
    process_runner: Callable | None = None,
    tls_probe: Callable[[Path], bool] | None = None,
) -> None:
    home = home or Path.home()
    process_runner = process_runner or subprocess.run
    tls_probe = tls_probe or _trusted_tls_probe
    manifest = json.loads(manifest_path.read_text())
    health = json.loads((home / HEALTH_SUFFIX).read_text())
    _require(isinstance(manifest, dict) and isinstance(health, dict), "Managed router metadata is invalid")
    _require(manifest.get("schemaVersion") == "project-manager.portless-router.release/v1"
             and manifest.get("mode") == "production", "Unsupported managed router release")
    _require(manifest.get("routing") == {"strict": False, "tlds": ["localhost"]},
             "Managed router does not provide localhost wildcard routing")
    sockets = manifest["sockets"]
    _require(isinstance(sockets, dict), "Managed router socket configuration is invalid")
    _require(sockets.get("https", {}).get("port") == 443 and sockets.get("http", {}).get("port") == 80,
             "Managed router does not own the canonical ports")
    uid = manifest["identity"]["uid"]
    _require(type(uid) is int and uid == os.getuid(), "Managed router belongs to another user")
    state = manifest["state"]
    directory = home / ".portless"
    _require(Path(state["directory"]) == directory and Path(state["routes"]) == directory / "routes.json"
             and Path(state["caCertificate"]) == directory / "ca.pem", "Managed router state directory differs")
    _require(health.get("schemaVersion") == "project-manager.portless-router.health/v1"
             and health.get("component") == "adapter" and health.get("state") == "ready",
             "Managed router has no ready adapter receipt")
    pid = health.get("pid")
    _require(type(pid) is int and pid > 0, "Managed router receipt has no process")
    _require((directory / "proxy.pid").read_text().strip() == str(pid)
             and (directory / "proxy.port").read_text().strip() == "443"
             and (directory / "proxy.tls").read_text().strip() == "1"
             and (directory / "proxy.tld").read_text().strip() == "localhost"
             and json.loads((directory / "proxy.tlds").read_text()) == ["localhost"],
             "Managed router live markers do not match its ready receipt")
    observed = datetime.fromisoformat(health["observedAt"].replace("Z", "+00:00"))
    _require(observed.tzinfo is not None and manifest_path.stat().st_mtime <= observed.timestamp() + 1
             and observed.timestamp() <= time.time() + 5, "Managed router receipt predates its manifest")
    process = process_runner(
        ["ps", "-p", str(pid), "-o", "uid=,lstart=,command="],
        capture_output=True, text=True, timeout=2, check=False,
        env={**os.environ, "LC_ALL": "C"},
    )
    parts = process.stdout.strip().split(maxsplit=6)
    expected_command = (f'{manifest["runtime"]["node"]["path"]} '
                        f'{manifest["runtime"]["adapter"]["path"]} --manifest {manifest_path}')
    _require(process.returncode == 0 and len(parts) == 7 and parts[0] == str(uid)
             and parts[6] == expected_command, "Managed router process does not match its release")
    started = datetime.strptime(" ".join(parts[1:6]), "%a %b %d %H:%M:%S %Y").timestamp()
    _require(started <= observed.timestamp() + 1, "Managed router ready receipt is from an older process")
    routes = json.loads((directory / "routes.json").read_text())
    _require(isinstance(routes, list), "Managed router routes are invalid")
    names: set[str] = set()
    for route in routes:
        _require(isinstance(route, dict), "Managed router route is invalid")
        hostname, port, owner = route.get("hostname"), route.get("port"), route.get("pid")
        _require(isinstance(hostname, str) and hostname.endswith(".localhost")
                 and hostname not in names and len(hostname) <= 253
                 and all(re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in hostname.split("."))
                 and type(port) is int and 1 <= port <= 65535
                 and type(owner) is int and owner >= 0, "Managed router route is incompatible")
        _require(hostname != "admin.trr.localhost", "Admin TRR route must use wildcard fallback")
        names.add(hostname)
    _require(tls_probe(Path(state["caCertificate"])), "Managed router trusted TLS readiness probe failed")


def main(arguments: list[str] | None = None) -> int:
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments == ["--owner-present"]:
        return 0 if managed_owner_present() else 1
    if arguments:
        return 2
    try:
        verify_router()
    except (RouterNotReady, OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError,
            http.client.HTTPException):
        return 1
    print("Project Manager managed Portless router is ready on HTTPS 443 with localhost wildcard routing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
