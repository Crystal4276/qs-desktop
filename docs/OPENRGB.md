# OpenRGB au démarrage

Le service système `openrgb.service` du paquet contrôle seul le matériel, dès le démarrage, sans session graphique. Les clients
OpenRGB se connectent sur `127.0.0.1:6742`. Aucun second serveur, ni chargement du profil à chaque connexion.

## Incident du 2026-11-05

`openrgb -p purple` était correct : OpenRGB 1.1 lit `profiles/purple.json`, pas l'ancien `purple.orp`.
Cependant, le profil migré était incompatible avec les contrôleurs actuels : Ornata Chroma, 6 modes enregistrés contre 9 détectés ;
carte mère, 12 modes contre 7 détectés. Le gestionnaire de profils ne restaure le mode actif que si les nombres de modes sont égaux,
mais peut envoyer les couleurs des LED (ici noires) même quand il laisse le contrôleur en mode Direct.
Les numéros `hidraw` ne sont pas utilisés pour la correspondance et ne doivent pas être corrigés à la main.

Source : [ProfileManager.cpp, branche release_1.1](https://github.com/CalcProgrammer1/OpenRGB/blob/release_1.1/ProfileManager.cpp),
`LoadControllerFromListWithOptions`. Un message « Profile loaded successfully » ne prouve pas que chaque contrôleur a été restauré.

Le profil a été réexporté depuis la version installée, en réappliquant les modes **par leur nom**, avec les luminosités et vitesses
précédentes. Les effets multicolores sont conservés. Les profils et leurs sauvegardes restent hors Git.

## Mise en place

Prérequis : paquet `openrgb` et son service système ; `python` pour préparer et valider les réglages. Le paquet fournit les règles
udev et le chargement d'`i2c-dev`. Aucun paquet n'est installé par le script. L'instance système tourne sous root, comme le service
fourni par Arch : les ACL de la session utilisateur ne sont pas disponibles avant connexion.

Préparer un dossier avec `OpenRGB.json` et `profiles/purple.json` validé sur les contrôleurs réellement connectés. Ne pas y copier
une ancienne `Configuration.json` : elle peut contenir des définitions périmées ou des doublons. Les réglages matériels personnalisés
(taille de zones, calibration) doivent être vérifiés sur la détection actuelle avant un nouvel export.

```sh
scripts/openrgb-setup.sh --dry-run install DOSSIER
scripts/openrgb-setup.sh install DOSSIER
# Arrêter l'instance temporaire par son PID exact avant enable.
scripts/openrgb-setup.sh enable
systemctl status openrgb.service
journalctl -b -u openrgb.service
```

`install` sauvegarde la configuration système et l'éventuelle surcharge précédente dans `/var/lib/qs-desktop/openrgb-setup`.
Il prépare le profil de démarrage du service (`service_startup_profile`), désactive les autostarts et profils de fermeture,
et installe `dotfiles/openrgb/service.conf`. Il refuse de remplacer la configuration d'un service actif.
Un second argument après le dossier permet de choisir un autre nom de profil (`purple` par défaut).
`enable` refuse une instance autonome concurrente. L'installation système et l'activation demandent l'accord pour `sudo`.

Après validation du service, retirer `openrgb -p purple` des autostarts machine Sway et Hyprland. Pour ouvrir l'interface sans lancer
une détection matérielle concurrente, utiliser `openrgb --gui --nodetect` (connexion locale automatique). Les profils chargés ou enregistrés
via ce client appartiennent au serveur dans `/etc/openrgb` ; la copie utilisateur ne se synchronise pas automatiquement.

## Vérifications et retour arrière

Vérifier les effets à l'œil, les modes du profil exporté, l'écoute locale et une seule instance matérielle. Tester un démarrage à
froid jusqu'à l'écran de connexion, puis Sway et Hyprland, déconnexion et reconnexion. Une panne RGB ne doit pas bloquer la session.

```sh
scripts/openrgb-setup.sh --dry-run uninstall
scripts/openrgb-setup.sh uninstall
```

Le retour arrière arrête le service, restaure les fichiers et son état d'activation initial. La configuration courante est conservée
dans `/etc/openrgb.before-restore-DATE`, pour préserver aussi les nouveaux profils. Si le service était auparavant désactivé,
remettre `exec openrgb -p purple` dans l'autostart machine Sway et `"openrgb -p purple",` dans celui d'Hyprland ; garder le profil
utilisateur corrigé. La sauvegarde `purple.json.before-qs-DATE` permet de retrouver l'ancien profil, mais reproduirait l'incident.
