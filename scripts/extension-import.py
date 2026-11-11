#!/usr/bin/env python3
"""Réglages d'une extension de Chromium (nightTab, Stylus) chargés depuis le dépôt dans un profil, sans fenêtre.

Chromium est lancé sans fenêtre (--headless) sur le profil, piloté par son protocole de débogage sur un tube (aucun port
réseau) : attente de l'extension (installée depuis le Chrome Web Store au démarrage, étape système d'install.sh), import sur
la page de l'extension, relecture, puis fermeture normale (données écrites). Chromium doit être fermé (profil verrouillé
sinon) : install.sh le vérifie avant.
- nightTab (dotfiles/chromium/nighttab.json, export Data → Export) : tout (favoris, couleurs, icônes, horloge) est dans le
  localStorage de son extension, clé « nightTab » ; écrite, page rechargée, relue.
- Stylus (dotfiles/chromium/stylus.json, sauvegarde Gérer → Exporter) : son propre import (celui du glisser-déposer d'une
  sauvegarde sur la page Gérer) ; styles déjà là reconnus et remplacés, autres styles gardés. Ses réglages ne sont pas
  importés (ceux du dépôt sont ceux par défaut).

Usage : extension-import.py [--dry-run] [--timeout s] nighttab|stylus <dossier de données Chromium> <fichier> [argument Chromium…]
Codes : 0 importé, 3 extension absente à l'expiration du délai, 1 autre échec.
"""
import json
import os
import re
import select
import signal
import subprocess
import sys
import time


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
        data = json.dumps(msg).encode() + b"\0"
        while data:     # message de plusieurs Mo (sauvegarde de Stylus) : écrit par morceaux
            data = data[os.write(self.out, data):]
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

    def evaluate(self, session, expression, timeout=30):
        r = self.call("Runtime.evaluate", {"expression": expression, "returnByValue": True, "awaitPromise": True}, session,
                      timeout)
        if "exceptionDetails" in r:
            raise RuntimeError(r["exceptionDetails"].get("exception", {}).get("description", "erreur JavaScript"))
        return r.get("result", {}).get("value")

    def wait(self, session, expression, timeout):
        """Attend qu'une expression soit vraie ; sa dernière valeur."""
        deadline = time.monotonic() + timeout
        value = None
        while time.monotonic() < deadline:
            try:
                value = self.evaluate(session, expression)
                if value:
                    return value
            except RuntimeError:
                pass
            time.sleep(0.5)
        return value

    def close(self):
        """Fermeture normale (données écrites) ; sinon arrêt, puis arrêt forcé de tous ses processus."""
        try:
            self.call("Browser.close", timeout=10)
        except Exception:
            pass
        for sig, wait in ((None, 30), (signal.SIGTERM, 15), (signal.SIGKILL, 10)):
            if sig:
                try:
                    os.killpg(self.proc.pid, sig)
                except ProcessLookupError:
                    pass
            try:
                self.proc.wait(timeout=wait)
                return
            except subprocess.TimeoutExpired:
                pass


def open_page(cdp, page, deadline):
    """Onglet sur une page d'extension, chargée ; None tant que l'extension n'est pas installée."""
    while time.monotonic() < deadline:
        target = cdp.call("Target.createTarget", {"url": page})["targetId"]
        session = cdp.call("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
        for _ in range(20):
            time.sleep(0.5)
            try:
                state = cdp.evaluate(session, "location.href + ' ' + document.readyState")
            except RuntimeError:
                continue
            if state.startswith(page) and state.endswith("complete"):
                return session
            if not state.startswith(("chrome-extension:", "about:blank")):
                break   # page d'erreur : extension pas (encore) installée
        cdp.call("Target.closeTarget", {"targetId": target})
        time.sleep(3)
    return None


class NightTab:
    name = "nightTab"
    page = "chrome-extension://hdpcadigjkbcpnlcpbcohpafiaefanki/index.html"

    def __init__(self, data):
        if not (isinstance(data, dict) and data.get("nightTab") and isinstance(data.get("bookmark"), list)):
            raise ValueError("pas un export de nightTab")
        self.data = data
        self.want = self.summary(data)

    @staticmethod
    def summary(data):
        groups = [g.get("name", {}).get("text") for g in data.get("bookmark", [])]
        return groups, sum(len(g.get("items", [])) for g in data.get("bookmark", []))

    def describe(self):
        return f"{len(self.want[0])} groupes, {self.want[1]} favoris"

    def load(self, cdp, session):
        cdp.evaluate(session, f"localStorage.setItem('nightTab', {json.dumps(json.dumps(self.data))}); true")
        cdp.evaluate(session, "location.reload(); true")
        time.sleep(1)
        cdp.wait(session, "document.readyState == 'complete'", 10)
        # Relu après le chargement par nightTab (qui réécrit sa clé s'il la convertit) : mêmes favoris attendus.
        got = self.summary(json.loads(cdp.evaluate(session, "localStorage.getItem('nightTab')") or "{}"))
        if got != self.want:
            raise RuntimeError(f"relu différent : {got[0]} ({got[1]} favoris)")
        return f"{got[1]} favoris relus après rechargement"


class Stylus:
    name = "Stylus"
    page = "chrome-extension://clngdbkpkpeebahjckkjfobafhncgmne/manage.html"

    def __init__(self, data):
        styles = [s for s in data if isinstance(s, dict) and isinstance(s.get("name"), str) and "settings" not in s] \
            if isinstance(data, list) else []
        if not styles:
            raise ValueError("pas une sauvegarde de Stylus")
        self.text = json.dumps(data, ensure_ascii=False)
        # Attendu après l'import : chaque style, par son nom, actif ou non, avec ses options choisies (variables usercss).
        self.want = {s["name"].strip(): self.state(s) for s in styles}

    @staticmethod
    def state(style):
        values = {k: v.get("value") for k, v in ((style.get("usercssData") or {}).get("vars") or {}).items()}
        return bool(style.get("enabled", True)), values

    def describe(self):
        return f"{len(self.want)} styles"

    def load(self, cdp, session):
        # Import de la page Gérer, chargé à part : le gestionnaire du glisser-déposer d'une sauvegarde (document.body.ondrop).
        if not cdp.wait(session, "typeof document.body.ondrop == 'function'", 15):
            raise RuntimeError("import de la page Gérer introuvable (nouvelle version de Stylus ?)")
        file = f"new File([{json.dumps(self.text)}], 'stylus.json', {{type: 'application/json'}})"
        cdp.evaluate(session, f"document.body.ondrop({{dataTransfer: {{files: [{file}]}}, preventDefault() {{}}}}); true")
        # Fin de l'import : son rapport s'affiche (#message-box).
        if not cdp.wait(session, "!!document.getElementById('message-box')", 120):
            raise RuntimeError("pas de rapport d'import après 120 s")
        got = cdp.evaluate(session, """API.styles.getAll().then(all => all.map(s => [s.name.trim(), !!s.enabled,
            Object.fromEntries(Object.entries(s.usercssData?.vars || {}).map(([k, v]) => [k, v.value ?? null]))]))""")
        have = {name: (enabled, values) for name, enabled, values in got}
        bad = [n for n, st in self.want.items() if have.get(n) != st]
        if bad:
            raise RuntimeError(f"{len(bad)} styles absents ou différents après l'import : {', '.join(bad[:5])}")
        return f"{len(self.want)} styles relus ({len(have)} dans le profil)"


def user_agent():
    """Agent utilisateur de Chromium avec fenêtre : celui sans fenêtre (« HeadlessChrome/… ») fait croire à Bitwarden qu'il
    tourne sous Safari ; il écrit alors une exception en boucle (des millions au journal) et Chromium ne répond plus."""
    out = subprocess.run(["chromium", "--version"], capture_output=True, text=True).stdout
    version = re.search(r"\b(\d+)\.\d", out)
    major = version.group(1) if version else "0"
    return f"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{major}.0.0.0 Safari/537.36"


def main():
    argv = sys.argv[1:]
    dry = "--dry-run" in argv
    argv = [a for a in argv if a != "--dry-run"]
    timeout = 120
    if argv[:1] == ["--timeout"]:
        timeout, argv = float(argv[1]), argv[2:]
    kinds = {"nighttab": NightTab, "stylus": Stylus}
    if len(argv) < 3 or argv[0] not in kinds:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    kind, profile, source, extra = kinds[argv[0]], argv[1], argv[2], argv[3:]
    try:
        ext = kind(json.load(open(source, encoding="utf-8")))
    except ValueError as e:
        print(f"! {source} : {e}", file=sys.stderr)
        return 1
    print(f"+ {ext.name} : {ext.describe()} ({source}) → {profile}")
    if dry:
        return 0
    cdp = Cdp(["chromium", "--headless=new", f"--user-data-dir={profile}", "--remote-debugging-pipe", "--no-first-run",
               "--no-default-browser-check", f"--user-agent={user_agent()}", *extra, "about:blank"])
    try:
        session = open_page(cdp, ext.page, time.monotonic() + timeout)
        if session is None:
            print(f"! {ext.name} pas installé dans {profile} après {timeout:.0f} s", file=sys.stderr)
            return 3
        print(f"= {ext.name} : {ext.load(cdp, session)}")
        return 0
    except (RuntimeError, OSError, ValueError) as e:
        print(f"! {ext.name} : {e}", file=sys.stderr)
        return 1
    finally:
        cdp.close()


if __name__ == "__main__":
    sys.exit(main())
