import QtQuick
import Quickshell
import Quickshell.Io

// Veilleuse sous Hyprland (NightLight.qml, ta demande du 2026-11-18) : hyprsunset (hyprland-ctm-control), température changée
// à chaud par `hyprctl hyprsunset temperature`. Hyprland fond chaque changement de matrice de couleur en 500 ms (animation
// interne `__internal_fadeCTM`, linéaire ; `render:ctm_animation` en auto : actif, sauf Nvidia avant le pilote 575), à
// l'allumage, à l'extinction et à chaque température. hyprsunset ne tourne que veilleuse allumée : arrêté, Hyprland rend la
// matrice neutre.
Scope {
    id: root

    required property bool enabled
    required property int temperature
    property int sent: 0   // température en vigueur dans hyprsunset
    property real startedAt: 0
    property int failures: 0   // arrêts juste après le lancement, à la suite
    property bool stopping: false   // arrêté par nous (veilleuse éteinte)
    property int sendFailures: 0

    function apply(): void {
        if (enabled && !sunset.running) {
            sent = temperature;
            sendFailures = 0;
            startedAt = Date.now();
            sunset.exec(["setpriv", "--pdeathsig", "TERM", "hyprsunset", "-t", String(temperature)]);
        } else if (!enabled && sunset.running) {
            retry.stop();
            stopping = true;
            sunset.signal(15);
        }
    }

    // Une commande à la fois ; la dernière température demandée est envoyée à la fin de la précédente. Changée pendant le
    // lancement : envoyée une fois hyprsunset prêt.
    function send(): void {
        if (sunset.running && !setter.running && sent !== temperature) {
            sent = temperature;
            setter.exec(["hyprctl", "hyprsunset", "temperature", String(temperature)]);
        }
    }

    onEnabledChanged: {
        failures = 0;
        apply();
    }
    onTemperatureChanged: send()
    Component.onCompleted: apply()

    // Arrêté avec Quickshell (`qs kill`), comme gammastep. Il quitte aussi quand un autre client tient déjà la matrice (le
    // hyprsunset d'avant un rechargement, le temps qu'il s'arrête) : relancé 1 s plus tard ; après 10 arrêts de suite dans les
    // 5 s qui suivent le lancement, une fois par minute.
    Process {
        id: sunset
        onRunningChanged: if (running) root.send()
        onExited: {
            if (root.stopping) {   // rallumée pendant l'arrêt : relancée aussitôt
                root.stopping = false;
                root.apply();
                return;
            }
            root.failures = Date.now() - root.startedAt < 5000 ? root.failures + 1 : 0;
            if (root.failures === 10)
                console.warn("NightLight: hyprsunset s'arrête aussitôt lancé, nouvel essai chaque minute");
            if (root.enabled) {
                retry.interval = root.failures >= 10 ? 60000 : 1000;
                retry.start();
            }
        }
    }

    // Échec (socket pas encore ouvert juste après le lancement) : nouvel essai 200 ms plus tard, 10 fois au plus ; ensuite, au
    // prochain changement de température.
    Process {
        id: setter
        onExited: code => {
            if (code === 0) {
                root.sendFailures = 0;
                root.send();
                return;
            }
            root.sent = 0;
            if (++root.sendFailures < 10)
                resend.start();
            else if (root.sendFailures === 10)
                console.warn("NightLight: hyprsunset ne répond pas à hyprctl");
        }
    }

    Timer {
        id: resend
        interval: 200
        onTriggered: root.send()
    }

    Timer {
        id: retry
        onTriggered: root.apply()
    }
}
