import QtQuick
import Quickshell
import Quickshell.Io

// Veilleuse sous Sway (NightLight.qml) : gammastep (wlr-gamma-control). Plutôt que wlsunset (ta demande du 2026-10-26) : fondu
// d'environ 4 s à l'allumage et à l'extinction, là où wlsunset change la température d'un coup.
Scope {
    id: root

    required property bool enabled
    required property int temperature

    // gammastep ne sert qu'à chauffer l'écran avec fondu : même température de jour comme de nuit (heures sans effet, mais
    // nécessaires : sans elles, il cherche une position géographique).
    function configText(fade: bool): string {
        return ["[general]", "adjustment-method=wayland", `fade=${fade ? 1 : 0}`, "dawn-time=06:00", "dusk-time=18:00",
            `temp-day=${temperature}`, `temp-night=${temperature}`, ""].join("\n");
    }

    // Température modifiée, veilleuse allumée : saut net (sous Hyprland, hyprsunset fait un fondu). gammastep ne change pas de
    // température en marche : arrêté sec (SIGKILL : le compositeur rend aussitôt le gamma neutre, sans fondu de sortie), puis
    // relancé aussitôt, sans fondu d'entrée (`jump`). Ce gammastep-là s'éteint donc sans fondu lui aussi. Rafale (molette,
    // clavier) : un seul saut, 400 ms après le dernier cran (`settle`). Éteinte : nouvelle température au prochain lancement, ou
    // au rallumage pendant le fondu de sortie (saut).
    property bool jump: false
    property int launched: 0   // température du gammastep en marche

    onTemperatureChanged: {
        failures = 0;
        if (enabled)
            settle.restart();
    }

    // Écrit avant chaque lancement (la config ne passe que par un fichier).
    FileView {
        id: configFile
        path: Quickshell.statePath("gammastep.ini")
        blockWrites: true
        printErrors: false
    }

    // État dans gammastep : il démarre activé, SIGUSR1 bascule (fondu dans les deux sens, réversible à tout moment : la réactiver
    // pendant le fondu de retour repart aussitôt vers la nuit). Désactivée, il est arrêté une fois revenu au neutre (`release`),
    // pour libérer le réglage gamma des écrans (exclusif). SIGUSR1 seulement une fois son gestionnaire installé (`ready`) :
    // l'action par défaut du signal le tuerait.
    property bool gammaOn: false
    property bool ready: false
    property real startedAt: 0
    property int failures: 0   // arrêts juste après le lancement, à la suite

    function launch(): void {
        configFile.setText(configText(!jump));   // écriture bloquante
        jump = false;
        launched = temperature;
        gammaOn = true;
        ready = false;
        startedAt = Date.now();
        gammastep.running = true;
        readyDelay.restart();
    }

    function apply(): void {
        release.stop();
        if (!gammastep.running) {
            if (enabled)
                launch();
            return;
        }
        if (enabled && launched !== temperature) {
            if (!jump) {
                jump = true;
                ready = false;
                gammastep.signal(9);
            }
            return;   // relancé par onExited
        }
        if (!ready)
            return;   // readyDelay rappelle apply()
        if (gammaOn !== enabled) {
            gammastep.signal(10);   // SIGUSR1
            gammaOn = enabled;
        }
        if (!enabled)
            release.restart();
    }

    onEnabledChanged: {
        failures = 0;
        jump = false;
        settle.stop();
        apply();
    }
    Component.onCompleted: apply()

    Process {
        id: gammastep
        // Arrêté avec Quickshell (`qs kill`) : un gammastep orphelin garderait le gamma, la veilleuse ne répondrait plus (vu le 2026-10-27).
        command: ["setpriv", "--pdeathsig", "TERM", "gammastep", "-c", configFile.path]
        // Réglage gamma tenu par un autre client (programme tiers, gammastep d'avant un rechargement encore en fondu de sortie) :
        // gammastep ne quitte pas, il tourne sans effet en le signalant ; arrêté, donc relancé (onExited). Vérifié le 2026-10-26.
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("Zero outputs support gamma adjustment")) {
                    root.ready = false;
                    gammastep.signal(15);
                }
            }
        }
        // Arrêt : relancé 1 s plus tard si la veilleuse est activée ; après 10 arrêts de suite dans les 5 s qui suivent le lancement
        // (autre client gamma qui garde la main, aucun écran, config refusée), une fois par minute seulement, et aussitôt qu'un
        // écran apparaît ou que la config change.
        onExited: {
            readyDelay.stop();
            root.gammaOn = false;
            root.ready = false;
            if (root.jump) {   // arrêté pour changer de température (onTemperatureChanged) : relancé aussitôt
                root.apply();
                return;
            }
            root.failures = Date.now() - root.startedAt < 5000 ? root.failures + 1 : 0;
            if (root.failures === 10)
                console.warn("NightLight: gammastep s'arrête aussitôt lancé, nouvel essai chaque minute (autre client gamma ?)");
            if (root.enabled) {
                retry.interval = root.failures >= 10 ? 60000 : 1000;
                retry.start();
            }
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.apply()
    }

    Timer {
        id: readyDelay
        interval: 1000
        onTriggered: {
            root.ready = true;
            root.apply();
        }
    }

    // Fondu de retour terminé (environ 4 s) : arrêt, sans effet visible.
    Timer {
        id: release
        interval: 6000
        onTriggered: {
            root.ready = false;
            gammastep.signal(15);
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: root.apply()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.failures = 0;
            if (retry.running) {
                retry.stop();
                root.apply();
            }
        }
    }
}
