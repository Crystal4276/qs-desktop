#!/usr/bin/env python3
"""Portails captifs : installation réversible et service QML avec backend factice.
Le test QML exige Quickshell et un compositeur Wayland de banc (voir DEVELOPMENT.md).
Aucune connexion réelle ni action VPN ; les lancements et nmcli sont factices.
"""
import configparser
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
SETUP = REPO / 'scripts/network-setup.sh'
CONF = Path('etc/NetworkManager/conf.d/90-qs-desktop-connectivity.conf')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, timeout=10, **kwargs).stdout.strip()


def stop_group(proc):
    try: os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError: pass
    try: proc.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.communicate()


def installation_test(work):
    root = work / 'system'
    def setup(*args):
        return run(str(SETUP), '--root', str(root), *args)
    setup('--dry-run', 'install')
    assert not root.exists(), 'dry-run wrote files'
    target = root / CONF
    target.parent.mkdir(parents=True)
    original = b'[connectivity]\nuri=http://original.example/check\n'
    target.write_bytes(original)
    target.chmod(0o640)
    setup('install')
    expected = (REPO / 'dotfiles/NetworkManager/conf.d' / CONF.name).read_bytes()
    assert target.read_bytes() == expected
    setup('install')
    assert (root / 'var/lib/qs-desktop/network-setup/original').read_bytes() == original
    setup('--dry-run', 'uninstall')
    assert target.read_bytes() == expected
    target.write_text('# local edit\n')
    setup('uninstall')
    assert target.read_bytes() == original and target.stat().st_mode & 0o777 == 0o640
    assert next(target.parent.glob('*.before-restore-*')).read_text() == '# local edit\n'
    target.unlink()
    setup('install')
    setup('uninstall')
    assert not target.exists()
    setup('install')
    assert target.read_bytes() == expected
    setup('uninstall')
    state = root / 'var/lib/qs-desktop/network-setup'
    state.mkdir(parents=True)
    result = subprocess.run([str(SETUP), '--root', str(root), 'install'], capture_output=True)
    assert result.returncode != 0 and not target.exists(), 'partial backup must refuse installation'
    parser = configparser.ConfigParser()
    parser.read_string(expected.decode())
    url = re.search(r'captivePortalUrl: "([^"]+)"', (REPO / 'services/Network.qml').read_text())[1]
    assert url == parser['connectivity']['uri'] and url.startswith('http://')
    assert parser['connectivity']['response'] == ''
    print('PASS installation: dry-run, idempotence, backup, restore, local edits, partial state, shared URL')


def concurrent_installation_test(work):
    # Hold the first install just before it creates its backup, then start a second invocation.
    # The old script lets both enter this section and the second overwrites the original backup.
    for existing in (True, False):
        sync = work / ('race-existing' if existing else 'race-new')
        system = sync / 'system'
        bindir = sync / 'bin'
        bindir.mkdir(parents=True)
        target = system / CONF
        target.parent.mkdir(parents=True)
        original = b'original-settings\n'
        if existing: target.write_bytes(original)
        real_install = shlex.quote(shutil.which('install'))
        real_flock = shlex.quote(shutil.which('flock'))
        (bindir / 'install').write_text('''#!/bin/bash
if [[ $1 == -d && ${@: -1} == */network-setup ]]; then
    touch "$SYNC/$SIDE.wait"
    while [[ ! -f $SYNC/$SIDE.go ]]; do sleep 0.01; done
fi
exec ''' + real_install + ' "$@"\n')
        (bindir / 'flock').write_text('#!/bin/bash\ntouch "$SYNC/$SIDE.lockwait"\nexec ' + real_flock + ' "$@"\n')
        for stub in bindir.iterdir(): stub.chmod(0o755)
        processes = []
        def start(side):
            proc = subprocess.Popen([str(SETUP), '--root', str(system), 'install'], stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, text=True, start_new_session=True,
                                    env=dict(os.environ, SYNC=str(sync), SIDE=side,
                                             PATH=str(bindir) + ':' + os.environ['PATH']))
            processes.append(proc)
            return proc
        def await_marker(*names):
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if any((sync / name).exists() for name in names): return
                time.sleep(0.01)
            raise AssertionError('No synchronization marker: ' + str(names))
        try:
            first = start('a'); await_marker('a.wait')
            second = start('b'); await_marker('b.wait', 'b.lockwait')
            (sync / 'a.go').touch()
            output = first.communicate(timeout=5)
            assert first.returncode == 0, output
            (sync / 'b.go').touch()
            output = second.communicate(timeout=5)
            assert second.returncode == 0, output
            run(str(SETUP), '--root', str(system), 'uninstall')
            if existing: assert target.read_bytes() == original, 'concurrent installs overwrote the original backup'
            else: assert not target.exists(), 'concurrent installs saved the managed file as the original'
        finally:
            for proc in processes:
                stop_group(proc)
    print('PASS concurrent installs: original restored / new file removed')


def form_test(ipc, nmcli_log, notify_log, work):
    """Formulaires du panneau Wi-Fi : réseau entreprise et réseau WPA. Création sans secret sur la ligne de commande (sortie de
    `nmcli` traduite), TTLS sans domaine refusé, profil d'un nouveau réseau supprimé après un échec, saisie reprise, mot de passe
    enregistré refusé hors panneau (vraie liste surveillée) ou au clic (« expiré »), profil existant gardé, panneau fermé ou en
    aperçu, annulation (de la seule connexion suivie), autre connexion demandée, deux créations rapprochées, garde-fou, réseau
    disparu, échec de `nmcli`."""
    def form(): return json.loads(ipc('form'))
    def calls(): return json.loads(ipc('calls'))
    def settle(seconds=0.1): time.sleep(seconds)
    def fill(**values): ipc('fill', json.dumps({PLACEHOLDERS[k]: v for k, v in values.items()}))
    def new_calls(before): return calls()[len(before):]
    def notified(): return notify_log.read_text().splitlines() if notify_log.exists() else []
    def invocations(): return [line.split('\x1f') for line in nmcli_log.read_text().splitlines()] if nmcli_log.exists() else []
    def added(): return [inv[inv.index('connection.uuid') + 1] for inv in invocations() if inv[1] == 'add']
    def deleted(): return [inv[-1] for inv in invocations() if inv[1] == 'delete']
    def profile(name, uuid, method='ttls', identity='alice@campus.example'):
        ipc('profile', name, uuid, json.dumps({'802-1x': {'eap': [method], 'identity': identity, 'phase2-auth': 'pap'},
                                               'connection': {'autoconnect': False}}))
        settle()
    created_args = ['connection', 'add', 'type', 'wifi', 'con-name', 'Campus', 'ssid', 'Campus', 'connection.autoconnect', 'no',
                    'wifi-sec.key-mgmt', 'wpa-eap', '802-1x.eap', 'ttls', '802-1x.phase2-auth', 'pap',
                    '802-1x.identity', 'alice@campus.example', '802-1x.auth-timeout', '10', '802-1x.system-ca-certs', 'yes',
                    '802-1x.domain-suffix-match', 'radius.campus.example']
    def without_uuid(inv):
        i = inv.index('connection.uuid')
        return inv[:i] + inv[i + 2:]

    ipc('panels', 'false', '0')   # faux panneaux du test du portail : seul le vrai panneau compte ici
    ipc('openForm', 'enterprise'); settle()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['passwordFor'] == 'Campus', f
    assert all(f[k]['visible'] for k in ('username', 'password', 'domain')) and f['tabs'] == {'visible': True, 'current': 'peap'}, f
    assert f['connect'] == {'visible': True, 'enabled': False} and not f['holdOpen'], f
    # Identifiant manquant : ni Entrée ni bouton. TTLS sans domaine : refusé (PAP en clair vers un faux point d'accès).
    fill(password='pa ss'); ipc('enter', 'Password'); ipc('click', 'Connect'); settle()
    f = form()
    assert f['passwordFor'] == 'Campus' and f['holdOpen'] and not f['connect']['enabled'] and not invocations(), f
    fill(username=' alice@campus.example '); ipc('pick', 'ttls'); settle()
    f = form()
    assert not f['connect']['enabled'] and f['domain']['placeholder'] == 'Server domain (required with TTLS)', f
    ipc('enter', 'Password'); settle()
    assert form()['passwordFor'] == 'Campus' and not invocations()
    fill(domain=' radius.campus.example '); settle()
    assert form()['connect']['enabled']
    ipc('capturePanel', str(work / 'enterprise-form.png')); settle()
    ipc('click', 'Connect'); settle(0.5)
    f = form()
    # Connexion en cours : le panneau n'est pas retenu (il garderait le clavier) ; l'échec sera notifié puis montré.
    assert f['passwordFor'] == '' and f['signingIn'] and not f['holdOpen'] and f['failText'] == '', f
    # Sortie de `nmcli` traduite (« ajoutée avec succès ») : l'UUID vient de la commande, pas de sa sortie.
    assert [without_uuid(inv) for inv in invocations()] == [created_args], invocations()
    uuid = added()[0]
    assert calls() == [], 'nothing written before the profile appears'
    profile('enterprise', uuid)
    assert calls() == [['write', {'802-1x': {'password': 'pa ss'}}], ['connect', uuid]], calls()

    # Refus : profil créé supprimé (mot de passe jamais gardé), formulaire rouge avec ce qui avait été saisi.
    before = calls()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert new_calls(before) == [['forget', uuid]], calls()
    f = form()
    assert f['title'] == ['Wrong username or password for Campus'] and not f['signingIn'] and f['failText'] == '', f
    assert f['username'] == {'visible': True, 'text': 'alice@campus.example', 'error': True}, f
    assert f['password']['text'] == '' and f['password']['error'], f
    assert f['tabs'] == {'visible': True, 'current': 'ttls'} and f['domain']['text'] == 'radius.campus.example', f
    ipc('capturePanel', str(work / 'enterprise-refused.png')); settle()

    # Nouvelle saisie : profil recréé ; connecté, il reçoit la connexion automatique.
    fill(password='good'); ipc('enter', 'Password'); settle(0.5)
    uuid = added()[-1]
    before = calls()
    profile('enterprise', uuid)
    ipc('setState', 'enterprise', 'Connected'); settle()
    assert new_calls(before) == [['write', {'802-1x': {'password': 'good'}}], ['connect', uuid],
                                 ['write', {'connection': {'autoconnect': True}}]], calls()
    assert not form()['signingIn'] and notified() == [], 'no notification while the panel is pinned'
    ipc('setState', 'enterprise', 'Disconnected'); settle()

    # Mot de passe enregistré refusé hors panneau (renouvelé par l'établissement), par la vraie liste surveillée : notification
    # panneau fermé, formulaire rouge à l'ouverture, rien d'effacé ; autre cause hors panneau (réseau perdu) : rien.
    ipc('closePanel'); ipc('destroyPanel'); ipc('list', 'enterprise'); settle()
    before = calls()
    ipc('emitFail', 'enterprise', 'WifiNetworkLost'); settle()
    assert notified() == [] and not form_pending(ipc)
    ipc('emitFail', 'enterprise', 'NoSecrets'); settle()
    assert new_calls(before) == [] and notified() == ['--app-name=Wi-Fi', '--icon=network-wireless-offline', '--',
        'Campus refused the saved password: it may have expired', 'Open the Wi-Fi panel to enter the new one.'], notified()
    # Connecté depuis (autre moyen) : l'échec en attente est dépassé, rien à montrer. (Réseau du portail retiré : une carte
    # n'a qu'un réseau connecté.)
    ipc('configure', json.dumps({'joined': False})); ipc('setState', 'enterprise', 'Connected'); settle()
    assert not form_pending(ipc)
    ipc('setState', 'enterprise', 'Disconnected'); ipc('configure', json.dumps({'joined': True}))
    ipc('emitFail', 'enterprise', 'NoSecrets'); settle()
    assert form_pending(ipc)
    ipc('list', ''); ipc('reopenPanel'); settle()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and not f['password']['error'], f
    assert f['failText'] == 'Campus refused the saved password: it may have expired', f
    assert f['username']['text'] == 'alice@campus.example' and not f['tabs']['visible'] and not f['domain']['visible'], f
    notify_log.unlink()

    # Réseau enregistré cliqué puis refusé (rien de tapé) : mot de passe enregistré refusé, « expiré » ; identifiant repris.
    before = calls()
    ipc('openForm', 'enterprise'); settle()
    f = form()   # formulaire d'échec affiché, réseau recliqué : refermé, panneau non retenu
    assert f['passwordFor'] == '' and f['signingIn'] and not f['holdOpen'], f
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert new_calls(before) == [['connect', uuid]], calls()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['username']['text'] == 'alice@campus.example', f
    assert f['failText'] == 'Campus refused the saved password: it may have expired', f
    # Échec hors panneau du même réseau, formulaire déjà ouvert et mot de passe commencé : vidé, message mis à jour.
    fill(password='partial'); ipc('background', 'enterprise', 'NoSecrets'); settle()
    f = form()
    assert f['password']['text'] == '' and f['failText'] == 'Campus refused the saved password: it may have expired', f

    # Nouveau mot de passe, échec de signal : rien d'effacé (il est peut-être bon), message.
    before = calls()
    fill(username='alice', password='new'); ipc('click', 'Connect'); settle()
    ipc('fail', 'enterprise', 'WifiClientFailed', 'false'); settle()
    assert new_calls(before) == [['write', {'802-1x': {'identity': 'alice', 'password': 'new', 'password-flags': 0}}],
                                 ['connect', uuid]], calls()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['username']['text'] == 'alice', f
    assert f['failText'] == 'Could not connect to Campus — weak signal or wrong username or password', f

    # Refusé : profil existant gardé avec ce mot de passe (l'ancien est déjà remplacé) ; l'échec de la connexion automatique qui
    # suit est signalé, pas ignoré.
    before = calls()
    fill(password='wrong'); ipc('enter', 'Password'); settle()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert len(new_calls(before)) == 2 and form()['title'] == ['Wrong username or password for Campus'], calls()
    ipc('background', 'enterprise', 'NoSecrets'); settle()
    assert form()['failText'] == 'Campus refused the saved password: it may have expired', form()
    # Réseau du formulaire connecté entre-temps : formulaire et message refermés ; puis un nouvel échec le rouvre.
    ipc('setState', 'enterprise', 'Connected'); settle()
    f = form()
    assert f['passwordFor'] == '' and f['failText'] == '', f
    ipc('setState', 'enterprise', 'Disconnected'); ipc('openForm', 'enterprise'); settle()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert form()['passwordFor'] == 'Campus', form()

    # Panneau fermé, puis simple aperçu au survol pendant la connexion (état avant le signal) : notification, l'aperçu ne
    # consomme pas l'échec ; montré une fois le panneau épinglé.
    fill(password='again'); ipc('enter', 'Password'); settle()
    ipc('closePanel'); settle(); ipc('previewPanel'); settle()
    before = calls()
    ipc('fail', 'enterprise', 'NoSecrets', 'true'); settle(1.2)
    assert new_calls(before) == [], calls()
    assert notified()[3:] == ['Wrong username or password for Campus', 'Open the Wi-Fi panel to try again.'], notified()
    f = form()
    assert f['passwordFor'] == '' and f['failurePending'], f
    ipc('closePanel'); settle(); ipc('reopenPanel'); settle()
    f = form()
    assert f['title'] == ['Wrong username or password for Campus'] and f['username']['text'] == 'alice', f
    notify_log.unlink()

    # Annulation : rien à montrer (profil existant gardé).
    fill(password='x'); ipc('enter', 'Password'); settle()
    before = calls()
    ipc('cancel'); ipc('setState', 'enterprise', 'Disconnected'); settle(1.2)
    assert new_calls(before) == [], calls()
    f = form()
    assert f['passwordFor'] == '' and f['failText'] == '' and not f['signingIn'], f

    # Retour à « Disconnected » sans échec traduit : message après une seconde, mot de passe (non saisi) gardé.
    before = calls()
    ipc('openForm', 'enterprise'); settle()
    ipc('setState', 'enterprise', 'Disconnected'); settle(0.3)
    assert form()['signingIn'] and form()['passwordFor'] == ''
    settle(1.0)
    f = form()
    assert not f['signingIn'] and f['passwordFor'] == 'Campus' and f['failText'].startswith('Could not connect to Campus —'), f
    assert new_calls(before) == [['connect', uuid]], calls()

    # Autre connexion demandée pendant la tentative (réseau WPA) : abandon sans message.
    fill(password='y'); ipc('enter', 'Password'); settle()
    ipc('openForm', 'personal'); settle(); fill(password='wpa key'); before = calls(); ipc('click', 'Connect'); settle()
    assert new_calls(before) == [['psk', 'wpa key']], calls()
    ipc('setState', 'enterprise', 'Disconnected'); settle(1.2)
    f = form()
    assert not f['signingIn'] and f['failText'] == '' and f['passwordFor'] == '' and not f['failurePending'], f

    # Réseau WPA enregistré en cours, puis réseau entreprise enregistré : l'échec du premier ne se mêle pas au second.
    profile('personal', 'home-uuid', 'none')
    before = calls()
    ipc('openForm', 'personal'); settle(); ipc('openForm', 'enterprise'); settle()
    ipc('fail', 'personal', 'WifiClientDisconnected', 'false'); settle()
    f = form()
    assert f['failText'] == '' and f['passwordFor'] == '' and new_calls(before) == [['connect', ''], ['connect', uuid]], (f, calls())
    # Échec en attente derrière le formulaire d'un autre réseau (panneau épinglé, pas de notification) : montré à sa fermeture.
    ipc('reset', 'personal'); ipc('openForm', 'personal'); settle()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    f = form()
    assert f['title'] == ['Password for Home'] and f['failurePending'] and notified() == [], f
    fill(password='wpa'); ipc('click', 'Connect'); settle()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['failText'].startswith('Campus refused the saved password'), f
    assert calls()[-1] == ['psk', 'wpa'], calls()
    # Même attente, puis panneau refermé sans soumettre : notification à la fermeture, formulaire à la réouverture.
    ipc('openForm', 'enterprise'); settle(); ipc('openForm', 'personal'); settle()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert form()['title'] == ['Password for Home'] and notified() == [], form()
    ipc('closePanel'); settle()
    assert notified()[3:] == ['Campus refused the saved password: it may have expired',
                              'Open the Wi-Fi panel to enter the new one.'], notified()
    ipc('reopenPanel'); settle()
    assert form()['title'] == ['Sign in to Campus'], form()
    notify_log.unlink()
    # « Cancel » d'un autre réseau en cours (pas celui suivi) : la connexion suivie continue.
    fill(password='z'); ipc('enter', 'Password'); settle()
    ipc('setState', 'enterprise', 'Disconnected'); ipc('setState', 'personal', 'Connecting'); ipc('cancel'); settle()
    assert form()['signingIn'], form()
    ipc('setState', 'personal', 'Disconnected'); ipc('setState', 'enterprise', 'Connecting'); ipc('cancel'); settle()
    assert not form()['signingIn'] and form()['failText'] == '', form()
    ipc('setState', 'enterprise', 'Disconnected'); settle()

    # Profil tout juste créé, écriture en cours : un nouveau clic sur le réseau ne l'abandonne pas ; Wi-Fi coupé : abandon sans
    # message (profil créé supprimé).
    ipc('reset', 'enterprise'); ipc('silent', 'true'); settle()
    ipc('openForm', 'enterprise'); settle(); fill(username='alice', password='w'); ipc('enter', 'Password'); settle(0.5)
    pending_uuid = added()[-1]
    profile('enterprise', pending_uuid)
    before = calls()
    ipc('openForm', 'enterprise'); settle()
    assert new_calls(before) == [] and form()['signingIn'], calls()
    ipc('wifiOff'); settle()
    f = form()
    assert new_calls(before) == [['forget', pending_uuid]] and not f['signingIn'] and not f['failurePending'], (f, calls())
    assert f['failText'] == '' and notified() == [], f
    ipc('configure', json.dumps({'wifiEnabled': True})); ipc('silent', 'false'); settle()

    # Deux créations rapprochées (nouveau réseau, puis un autre pendant `nmcli`) : la première est abandonnée et son profil
    # supprimé à la fin de `nmcli` ; la seconde suit son cours.
    ipc('reset', 'enterprise'); settle()
    ipc('openForm', 'enterprise'); settle(); fill(username='alice', password='p1'); ipc('enter', 'Password')
    ipc('openForm', 'library'); settle(); fill(username='alice', password='p2'); ipc('enter', 'Password'); settle(0.8)
    first, second = added()[-2:]
    assert first in deleted() and second not in deleted(), invocations()
    before = calls()
    profile('library', second, 'peap')
    assert new_calls(before) == [['write', {'802-1x': {'password': 'p2'}}], ['connect', second]], calls()
    ipc('setState', 'library', 'Connected'); settle(); ipc('setState', 'library', 'Disconnected'); settle()

    # Garde-fou : profil jamais apparu (créé : supprimé), puis écriture sans réponse (mot de passe d'un profil existant gardé).
    ipc('openForm', 'enterprise'); settle(); fill(username='alice', password='p3'); ipc('enter', 'Password'); settle(0.5)
    stuck = added()[-1]
    settle(2.6)
    f = form()
    assert not f['signingIn'] and f['passwordFor'] == 'Campus' and f['failText'] == 'Could not connect to Campus', f
    assert stuck in deleted(), invocations()
    before = calls()
    ipc('openForm', 'library'); settle(); ipc('fail', 'library', 'NoSecrets', 'false'); settle()
    ipc('silent', 'true'); fill(password='p4'); ipc('enter', 'Password'); settle(2.9)
    f = form()
    assert not f['signingIn'] and f['passwordFor'] == 'Library' and f['failText'].startswith('Could not connect'), f
    assert new_calls(before) == [['connect', second],
                                 ['write', {'802-1x': {'identity': 'alice@campus.example', 'password': 'p4',
                                                    'password-flags': 0}}]], calls()
    ipc('silent', 'false')

    # Profil oublié par un autre moyen pendant la tentative (objet détruit) : échec signalé, sans erreur.
    fill(password='p5'); ipc('enter', 'Password'); settle()
    ipc('destroyProfile', 'library'); settle()
    ipc('fail', 'library', 'NoSecrets', 'false'); settle()
    f = form()
    assert f['title'] == ['Wrong username or password for Library'] and not f['signingIn'], f

    # Connexion réussie avant la fin de `nmcli` : profil gardé.
    (work / 'nmcli-delay').write_text('1.0')
    ipc('reset', 'enterprise'); ipc('openForm', 'enterprise'); settle()
    fill(username='alice', password='fast'); ipc('enter', 'Password'); settle(0.2)
    fast = added()[-1]
    profile('enterprise', fast)
    ipc('setState', 'enterprise', 'Connected'); settle(1.2)
    assert fast not in deleted() and calls()[-1] == ['write', {'connection': {'autoconnect': True}}], (invocations(), calls())
    ipc('setState', 'enterprise', 'Disconnected'); settle()
    (work / 'nmcli-delay').write_text('0.3')

    # Réseau disparu (hors de portée) avant l'ouverture du panneau : message seul, sans erreur.
    ipc('makeTemp', 'Lab'); profile('temp', 'lab-uuid', 'peap')
    ipc('openForm', 'temp'); settle(); ipc('closePanel'); settle()
    ipc('fail', 'temp', 'NoSecrets', 'false'); settle(); ipc('destroyTemp'); settle()
    ipc('reopenPanel'); settle()
    f = form()
    assert f['failText'] == 'Lab refused the saved password: it may have expired' and f['passwordFor'] == '', f
    notify_log.unlink()

    # Formulaire d'un réseau qui disparaît (objet détruit) : Qt remet `passwordFor` (propriété `var`) à null, le formulaire se
    # ferme et se vide, rien n'est lancé.
    ipc('makeTemp', 'Annex'); ipc('openForm', 'temp'); settle(); fill(username='alice', password='gone')
    before = invocations()
    ipc('destroyTemp'); settle(); ipc('enter', 'Password'); settle(0.5)
    f = form()
    assert invocations() == before and f['passwordFor'] == '' and not f['password']['visible'], f
    assert f['password']['text'] == '' and not f['holdOpen'], f

    # « Forget » d'un réseau dont l'échec attend (panneau fermé) : l'échec part avec lui.
    ipc('closePanel'); settle(); ipc('background', 'enterprise', 'NoSecrets'); settle()
    assert form_pending(ipc)
    ipc('forget', 'enterprise'); settle()
    assert not form_pending(ipc)
    ipc('reopenPanel'); settle()
    assert form()['passwordFor'] == '' and form()['failText'] == '', form()
    notify_log.unlink()
    profile('enterprise', fast)

    # « Forget » du réseau suivi : abandon voulu, pas un échec.
    before = calls()
    ipc('openForm', 'enterprise'); settle(); ipc('forget', 'enterprise'); settle(1.2)
    f = form()
    assert new_calls(before) == [['connect', fast], ['forgetNetwork', 'Campus']] and not f['signingIn'], (f, calls())
    assert f['failText'] == '' and not f['failurePending'], f

    # `nmcli` en échec (réseau sans profil) : message, saisie reprise, rien d'écrit ; profil éventuellement créé supprimé.
    ipc('reset', 'enterprise'); settle()
    ipc('openForm', 'enterprise'); settle()
    before = calls()
    fill(username='bogus', password='x'); ipc('enter', 'Password'); settle(0.6)
    f = form()
    assert f['failText'] == 'Could not connect to Campus' and f['username']['text'] == 'bogus' and calls() == before, f
    assert added()[-1] in deleted(), invocations()

    # WPA : mot de passe seul, bouton compris.
    ipc('openForm', 'personal'); settle()
    f = form()
    assert f['title'] == ['Password for Home'] and not f['username']['visible'] and not f['domain']['visible'], f
    assert not f['tabs']['visible'] and f['connect'] == {'visible': True, 'enabled': False}, f
    fill(password='wpa key'); ipc('click', 'Connect'); settle()
    assert calls()[-1] == ['psk', 'wpa key'] and form()['pending'] == 'Home', calls()
    print('PASS QML: enterprise form (Connect button, TTLS needs a domain, translated nmcli, new profile removed on failure, '
          'retry, expired saved password via the watched list or a click, existing profile kept, closed or previewed panel, '
          'cancel of the tracked attempt only, other connection, overlapping creations, watchdog, vanished network, nmcli '
          'failure), WPA form')


def form_pending(ipc):
    return ipc('failurePending') == 'true'


PLACEHOLDERS = {'username': 'Username', 'password': 'Password', 'domain': 'Server domain'}


def qml_test(work):
    stage = work / 'shell'
    # Actual code, with only the native backend and external effects substituted.
    for name in ('services', 'config', 'modules'):
        shutil.copytree(REPO / name, stage / name)
    (stage / 'assets').symlink_to(REPO / 'assets', target_is_directory=True)
    network = (stage / 'services/Network.qml').read_text().replace('Networking.', 'Backend.')
    # Accelerate the ten-second timer; disable /proc sampling so route changes are deterministic.
    network = network.replace('interval: 10000', 'interval: 100')
    # Garde-fou de la connexion entreprise : 2,5 s avant la connexion, 6 s pendant.
    network = network.replace('signInRequest.connecting ? 90000 : 60000', 'signInRequest.connecting ? 6000 : 2500')
    assert 'signInRequest.connecting ? 6000 : 2500' in network, 'sign-in watchdog not shortened'
    assert 'interval: 100\n' in network, 'portal timer not shortened'
    network = network.replace('running: true\n        repeat: true\n        triggeredOnStart: true',
                              'running: false\n        repeat: true\n        triggeredOnStart: false', 1)
    (stage / 'services/Network.qml').write_text(network)
    for name in ('Backend', 'FakeWifi', 'FakeProfile'):
        shutil.copy2(REPO / f'scripts/tests/network/{name}.qml', stage / f'services/{name}.qml')
    shutil.copy2(REPO / 'scripts/tests/network/shell.qml', stage / 'shell.qml')
    (stage / 'services/Launch.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var commands: []; function exec(args) { commands = commands.concat([args]); } }\n')
    bindir = work / 'bin'
    bindir.mkdir()
    # `nmcli connection …` : arguments enregistrés (séparés par \x1f) ; `add` lent (0,3 s), sortie traduite, échec si
    # l'identifiant est « bogus ».
    nmcli_log = work / 'nmcli.log'
    (bindir / 'nmcli').write_text(f'''#!/bin/sh
[ "$1" = "connection" ] || exit 0
(IFS=$(printf '\\037'); echo "$*") >> {shlex.quote(str(nmcli_log))}
[ "$2" = "add" ] || exit 0
sleep "$(cat {shlex.quote(str(work / 'nmcli-delay'))} 2>/dev/null || echo 0.3)"
case " $* " in *" bogus "*) echo "Erreur : échec" >&2; exit 1 ;; esac
echo "Connexion « Campus » ajoutée avec succès."
''')
    (bindir / 'nmcli').chmod(0o755)
    # `notify-send` : arguments enregistrés (aucune notification réelle sur la session).
    notify_log = work / 'notify.log'
    (bindir / 'notify-send').write_text(f"#!/bin/sh\nprintf '%s\\n' \"$@\" >> {shlex.quote(str(notify_log))}\n")
    (bindir / 'notify-send').chmod(0o755)
    # Rendu logiciel direct : sur un banc sans GPU, Mesa essaie d'abord Zink et journalise son échec.
    env = dict(os.environ, QS_TEST='1', XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'),
               GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1', LIBGL_ALWAYS_SOFTWARE='1',
               PATH=str(bindir) + ':' + os.environ['PATH'])
    log = work / 'qml.log'
    with log.open('w') as output:
        proc = subprocess.Popen(['qs', '-p', str(stage)], env=env, stdout=output, stderr=subprocess.STDOUT,
                                start_new_session=True)
        try:
            def ipc(method, *args):
                return run('qs', 'ipc', '--pid', str(proc.pid), 'call', 'test', method, *args)
            def snap(): return json.loads(ipc('snapshot'))
            def config(**values):
                ipc('configure', json.dumps(values))
                time.sleep(0.04)
            for _ in range(100):
                if proc.poll() is not None: raise AssertionError(log.read_text())
                try:
                    snap()
                    break
                except subprocess.CalledProcessError:
                    time.sleep(0.05)
            else: raise AssertionError(log.read_text())
            config(interfaceName='test-wifi', connectivity=4)
            assert not snap()['portal'] and not snap()['buttonVisible']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before, 'normal connectivity must not poll'
            config(connectivity=2)
            assert snap()['portal'] and snap()['buttonVisible'] and not snap()['commands']
            ipc('stale'); assert not snap()['commands']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] > before, 'portal must poll with all panels closed'
            ipc('capture', str(work / 'portal.png')); time.sleep(0.15)
            # Exercise the actual WifiPanel handler, including exclusive keyboard release.
            ipc('openPanel'); time.sleep(0.1)
            ipc('activate'); result = snap()
            assert result['commands'] == [['xdg-open', 'http://ping.omacom.io/nm-check.txt']]
            assert result['closedBeforeLaunch']
            config(connectivity=4)
            before = snap()['checks']; time.sleep(0.25)
            assert not snap()['portal'] and snap()['checks'] == before
            config(connectivity=3)
            assert not snap()['portal']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] > before
            config(connectivity=2, connectivityCheckEnabled=False)
            assert not snap()['portal'] and not snap()['limited'] and snap()['connectivity'] == 0
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before
            config(connectivityCheckEnabled=True)
            assert snap()['portal'] and snap()['checks'] > before
            config(canCheckConnectivity=False)
            assert not snap()['portal']
            config(canCheckConnectivity=True, wired=True, interfaceName='test-ethernet')
            assert not snap()['portal'] and not snap()['limited']
            config(wired=False, joined=False)
            assert not snap()['portal']
            before = snap()['checks']; config(joined=True)
            assert snap()['portal'] and snap()['checks'] > before
            config(connectivity=4)
            before = snap()['checks']
            ipc('panels', 'false', '1'); time.sleep(0.04)
            assert snap()['checks'] == before, 'hover preview must not request a check'
            assert snap()['scanner'], 'hover preview must list the networks (scanner on)'
            ipc('panels', 'false', '0'); time.sleep(0.04)
            assert not snap()['scanner'], 'scanner off once the panel is closed'
            ipc('panels', 'false', '1'); time.sleep(0.04)
            ipc('panels', 'true', '1'); time.sleep(0.04)
            assert snap()['checks'] > before
            ipc('panels', 'true', '2')
            config(connectivity=2)
            before = snap()['checks']; time.sleep(0.32)
            assert 2 <= snap()['checks'] - before <= 4, 'one timer across multiple panels'
            form_test(ipc, nmcli_log, notify_log, work)
            config(wifiEnabled=False)
            assert not snap()['portal']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before
            # Journal en couleurs : codes ANSI retirés avant le filtre des catégories.
            lines = [re.sub(r'\x1b\[[0-9;]*m', '', line) for line in log.read_text().splitlines()]
            errors = [line for line in lines if ('WARN' in line or 'ERROR' in line)
                      and 'qt.qpa.services:' not in line and 'qt.qpa.wayland.textinput:' not in line]
            assert not errors, '\n'.join(errors)
            print('PASS QML: portal/full/limited, guarded click, browser argv, polling, disabled checks/radio, route attribution, reconnect, preview/pinned, multiple panels')
            for name in ('portal', 'enterprise-form', 'enterprise-refused'):
                if (work / f'{name}.png').exists():
                    print('Capture:', work / f'{name}.png')
                else:
                    print(f'Capture {name} indisponible : banc sans rendu ou fenêtre masquée.')
        finally:
            stop_group(proc)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--setup-only', action='store_true')
    parser.add_argument('--keep', type=Path, help='Keep logs and capture in this new directory')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='qs-network-test-') as tmp:
        work = Path(tmp)
        installation_test(work)
        concurrent_installation_test(work)
        try:
            if not args.setup_only: qml_test(work)
        finally:
            if args.keep: shutil.copytree(work, args.keep, symlinks=True)
