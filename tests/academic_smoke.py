"""Live ReLoop academic API smoke check. Reads local demo credentials, never logs them."""
from __future__ import annotations

import http.cookiejar
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "http://localhost:8080"
LOGIN_FILE = ROOT / ".local" / "demo-logins.txt"
LOG_FILE = ROOT / ".local" / "academic-test.log"


def read_login() -> tuple[str, str]:
    lines = LOGIN_FILE.read_text(encoding="utf-8").splitlines()
    password = next(line.split(": ", 1)[1] for line in lines if line.startswith("Password for all seeded accounts:"))
    email = next(line.split(": ", 1)[1] for line in lines if line.startswith("Admin:"))
    return email, password


def main() -> int:
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    log: list[str] = [f"Academic API smoke run {datetime.now(timezone.utc).isoformat()}"]
    failures = 0
    cached_csrf: tuple[str, str] | None = None

    def record(line: str) -> None:
        log.append(line)
        print(line.split(" body=", 1)[0], flush=True)

    def request(method: str, path: str, payload=None, expected=(200,)):
        nonlocal failures
        headers = {"Accept": "application/json"}
        data = None
        if payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        with opener.open(urllib.request.Request(BASE + path, data=data, headers=headers, method=method), timeout=10) as response:
            body = response.read().decode("utf-8", "replace")
            status = response.status
        result = json.loads(body) if body and body.lstrip().startswith(("{", "[")) else body
        ok = status in expected
        summary = result if isinstance(result, str) else json.dumps(result, ensure_ascii=False, default=str)
        record(f"{'PASS' if ok else 'FAIL'} {method} {path} status={status} body={summary[:900]}")
        if not ok:
            failures += 1
        return result

    def csrf_token():
        nonlocal cached_csrf
        if cached_csrf is not None:
            return cached_csrf
        token = request("GET", "/api/auth/csrf")
        cached_csrf = (token["token"], token["headerName"])
        return cached_csrf

    def post_with_csrf(path: str, payload=None):
        nonlocal failures
        token, header_name = csrf_token()
        headers = {"Accept": "application/json", header_name: token}
        data = json.dumps(payload if payload is not None else {}).encode()
        headers["Content-Type"] = "application/json"
        req = urllib.request.Request(BASE + path, data=data, headers=headers, method="POST")
        try:
            with opener.open(req, timeout=10) as response:
                status, body = response.status, response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            status, body = exc.code, exc.read().decode("utf-8", "replace")
        result = json.loads(body) if body and body.lstrip().startswith(("{", "[")) else body
        ok = status == 200
        summary = result if isinstance(result, str) else json.dumps(result, ensure_ascii=False, default=str)
        record(f"{'PASS' if ok else 'FAIL'} POST {path} status={status} body={summary[:900]}")
        if not ok:
            failures += 1
        return result

    def csrf_form_post(path: str, fields: dict[str, str]):
        nonlocal cached_csrf
        nonlocal failures
        token, header_name = csrf_token()
        headers = {"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded", header_name: token}
        req = urllib.request.Request(BASE + path, data=urllib.parse.urlencode(fields).encode(), headers=headers, method="POST")
        try:
            with opener.open(req, timeout=10) as response:
                status, body = response.status, response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            status, body = exc.code, exc.read().decode("utf-8", "replace")
        # Never include the submitted fields or request headers in the log.
        ok = status == 200
        record(f"{'PASS' if ok else 'FAIL'} POST {path} status={status} login response={body[:180]}")
        cached_csrf = None  # Spring rotates the session id at authentication.
        if not ok:
            failures += 1

    try:
        email, password = read_login()
        csrf_form_post("/api/auth/login", {"username": email, "password": password})
        who = request("GET", "/api/auth/me")
        if who.get("role") != "ADMIN":
            raise RuntimeError("Authenticated account is not an admin; role value omitted from credential data")

        for topic_id in range(1, 11):
            post_with_csrf(f"/api/academic/run/{topic_id}")

        actions = ["reset", "create", "insert", "add-column", "modify-column", "rename-column",
                   "drop-column", "comment", "merge", "view-check", "view-readonly", "tcl",
                   "rename", "truncate", "drop", "reset"]
        for action in actions:
            post_with_csrf(f"/api/academic/sandbox/{action}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        failures += 1
        record(f"FAIL unexpected HTTP {exc.code}: {body[:900]}")
    except Exception as exc:  # noqa: BLE001 - ensure a sanitized diagnostic is saved
        failures += 1
        record(f"FAIL exception {type(exc).__name__}: {str(exc)[:900]}")

    log.append(f"Result: {'PASS' if failures == 0 else 'FAIL'}; failures={failures}")
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    LOG_FILE.write_text("\n".join(log) + "\n", encoding="utf-8")
    print(log[-1])
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
