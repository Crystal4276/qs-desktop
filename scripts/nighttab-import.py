#!/usr/bin/env python3
"""Réglages de nightTab (dotfiles/chromium/nighttab.json) chargés dans un profil Chromium, sans fenêtre.

nightTab garde tout (favoris, couleurs, icônes, horloge) dans le localStorage de son extension, clé « nightTab », au format
de son export (Data → Export). Chromium est lancé sans fenêtre (--headless) sur le profil, piloté par son protocole de
débogage sur un tube (aucun port réseau) : attente de l'extension (installée depuis le Chrome Web Store au démarrage, étape
système d'install.sh), écriture de la clé, rechargement de la page, relecture, puis fermeture normale (données écrites).
Chromium doit être fermé (profil verrouillé sinon) : install.sh le vérifie avant.

Usage : nighttab-import.py [--dry-run] [--timeout s] <dossier de données Chromium> <nighttab.json> [argument Chromium…]
Codes : 0 importé, 3 extension absente à l'expiration du délai, 1 autre échec.
"""
import json
import os
import select
import subprocess
import sys
import time

EXTENSION = "hdpcadigjkbcpnlcpbcohpafiaefanki"
PAGE = f"chrome-extension://{EXTENSION}/index.html"


class Cdp:
    """Protocole de débogage de Chromium sur --remote-debugging-pipe : JSON terminé par un octet nul, fd 3 → Chromium, fd 4 ←."""

    def __init__(self, args):
        to_chrome_r, self.out = os.pipe()
        self.inp, from_chrome_w = os.pipe()

        def fds():
            os.dup2(to_chrome_r, 3)
            os.dup2(from_chrome_w, 4)

        self.proc = subprocess.Popen(args, pass_fds=(3, 4), preexec_fn=fds, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        os.close(to_chrome_r)
        os.close(from_chrome_w)
        self.buf, self.next = b"", 0

    def call(self, method, params=None, session=None, timeout=30):
        self.next += 1
        msg = {"id": self.next, "method": method, "params": params or {}}
        if session:
            msg["sessionId"] = session
        os.write(self.out, json.dumps(msg).encode() + b"\0")
        deadline = time.monotonic() + timeout
        while True:
            while b"\0" in self.buf:
                raw, self.buf = self.buf.split(b"\0", 1)
                reply = json.loads(raw)
                if reply.get("id") == self.next:
                    if "error" in reply:
                        raise RuntimeError(f"{method} : {reply['error'].get('message')}")
                    return reply.get("result", {})
            if time.monotonic() > deadline or self.proc.poll() is not None:
                raise RuntimeError(f"{method} : pas de réponse de Chromium")
            if select.select([self.inp], [], [], 0.5)[0]:
                chunk = os.read(self.inp, 1 << 16)
                if not chunk:
                    raise RuntimeError("Chromium s'est fermé")
                self.buf += chunk

    def evaluate(self, session, expression):
        r = self.call("Runtime.evaluate", {"expression": expression, "returnByValue": True, "awaitPromise": True}, session)
        if "exceptionDetails" in r:
            raise RuntimeError(r["exceptionDetails"].get("exception", {}).get("description", "erreur JavaScript"))
        return r.get("result", {}).get("value")

    def close(self):
        try:
            self.call("Browser.close", timeout=10)
        except Exception:
            pass
        try:
            self.proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            self.proc.wait(timeout=10)


def open_page(cdp, deadline):
    """Onglet sur la page de nightTab, chargée ; None tant que l'extension n'est pas installée."""
    while time.monotonic() < deadline:
        target = cdp.call("Target.createTarget", {"url": PAGE})["targetId"]
        session = cdp.call("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
        for _ in range(20):
            time.sleep(0.5)
            try:
                state = cdp.evaluate(session, "location.href + ' ' + document.readyState")
            except RuntimeError:
                continue
            if state.startswith(PAGE) and state.endswith("complete"):
                return session
            if not state.startswith(("chrome-extension:", "about:blank")):
                break   # page d'erreur : extension pas (encore) installée
        cdp.call("Target.closeTarget", {"targetId": target})
        time.sleep(3)
    return None


def main():
    argv = sys.argv[1:]
    dry = "--dry-run" in argv
    argv = [a for a in argv if a != "--dry-run"]
    timeout = 120
    if argv[:1] == ["--timeout"]:
        timeout, argv = float(argv[1]), argv[2:]
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    profile, source, extra = argv[0], argv[1], argv[2:]
    data = json.load(open(source, encoding="utf-8"))
    if not (isinstance(data, dict) and data.get("nightTab") and isinstance(data.get("bookmark"), list)):
        print(f"! {source} : pas un export de nightTab", file=sys.stderr)
        return 1
    groups = [g.get("name", {}).get("text") for g in data["bookmark"]]
    count = sum(len(g.get("items", [])) for g in data["bookmark"])
    print(f"+ nightTab : {len(groups)} groupes, {count} favoris ({source}) → {profile}")
    if dry:
        return 0
    cdp = Cdp(["chromium", "--headless=new", f"--user-data-dir={profile}", "--remote-debugging-pipe", "--no-first-run",
               "--no-default-browser-check", *extra, "about:blank"])
    try:
        session = open_page(cdp, time.monotonic() + timeout)
        if session is None:
            print(f"! nightTab pas installé dans {profile} après {timeout:.0f} s", file=sys.stderr)
            return 3
        cdp.evaluate(session, f"localStorage.setItem('nightTab', {json.dumps(json.dumps(data))}); true")
        cdp.evaluate(session, "location.reload(); true")
        time.sleep(1)
        for _ in range(20):
            time.sleep(0.5)
            try:
                if cdp.evaluate(session, "document.readyState") == "complete":
                    break
            except RuntimeError:
                pass
        # Relu après le chargement par nightTab (qui réécrit sa clé s'il la convertit) : mêmes favoris attendus.
        stored = json.loads(cdp.evaluate(session, "localStorage.getItem('nightTab')") or "{}")
        got = [g.get("name", {}).get("text") for g in stored.get("bookmark", [])]
        got_count = sum(len(g.get("items", [])) for g in stored.get("bookmark", []))
        if (got, got_count) != (groups, count):
            print(f"! nightTab relu différent : {got} ({got_count} favoris)", file=sys.stderr)
            return 1
        print(f"= nightTab : {got_count} favoris relus après rechargement")
        return 0
    except (RuntimeError, OSError, ValueError) as e:
        print(f"! nightTab : {e}", file=sys.stderr)
        return 1
    finally:
        cdp.close()


if __name__ == "__main__":
    sys.exit(main())
