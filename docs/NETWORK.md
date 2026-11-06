# Portails captifs

La carte Wi-Fi affiche **Sign-in required: captive portal** et **Open Captive Portal** lorsque NetworkManager identifie un
portail sur la connexion Wi-Fi. Le bouton ferme le panneau, libère son clavier exclusif et ouvre le navigateur par défaut.
Après identification, l'état revient automatiquement à « Connected ». Une panne ordinaire reste « Connected without Internet
access », sans bouton de portail. Aucune fenêtre ne s'ouvre automatiquement et aucun VPN n'est modifié.

## Sonde HTTP et installation

La sonde et le navigateur utilisent `http://ping.omacom.io/nm-check.txt`, hébergé par Omarchy. Le HTTP permet au réseau de rediriger
vers son formulaire. L'adresse Arch (`ping.archlinux.org`) est couverte par HSTS : le navigateur la transforme en HTTPS, ce qui
empêche cette interception. Source : [configuration Omarchy](https://github.com/omacom/omarchy/blob/quattro/etc/NetworkManager/conf.d/omarchy-connectivity.conf).

Le fichier versionné `dotfiles/NetworkManager/conf.d/90-qs-desktop-connectivity.conf` fixe l'URI et attend une réponse vide / 204.
Il conserve la fréquence normale et le choix de désactiver les vérifications. La carte relance une vérification à la connexion,
à l'ouverture épinglée du panneau et toutes les 10 s pendant un portail ou un accès limité, même panneau fermé. Une seule
minuterie sert toutes les barres ; Internet rétabli, le calendrier normal de NetworkManager reprend.

Prévisualiser, puis installer **après accord pour les écritures système** :

```sh
scripts/network-setup.sh --dry-run install
scripts/network-setup.sh install
```

Le script utilise `sudo`, sauvegarde le fichier existant dans `/var/lib/qs-desktop/network-setup`, installe le fichier et appelle
`nmcli general reload conf`. Il ne redémarre pas le service et ne recharge ni les profils de connexion ni le DNS. Une seconde
installation conserve la sauvegarde d'origine. Si le rechargement est refusé, corriger l'autorisation et relancer l'installation.
Une configuration de priorité supérieure ou une désactivation des sondes par l'utilisateur peut toujours prévaloir.

Retour arrière :

```sh
scripts/network-setup.sh --dry-run uninstall
scripts/network-setup.sh uninstall
```

Le fichier initial et ses permissions sont restaurés, ou le fichier ajouté est retiré. Un contenu modifié depuis l'installation
est conservé à côté, avec le suffixe `.before-restore-…` (non lu par NetworkManager). Aucun autre fichier de configuration n'est
touché. `install.sh` (phase 12) devra reprendre ces commandes avec sa confirmation système et son retour arrière.

## Vérification

Le mode `--root DIR` écrit dans une arborescence temporaire, sans `sudo` ni rechargement. Il sert à la préparation et aux tests :

```sh
python3 scripts/test-network.py --setup-only
```

Sur un **banc Wayland isolé**, avec `SWAYSOCK` **et** `I3SOCK` du banc sous Sway, ou sa signature sous Hyprland :

```sh
dbus-run-session -- python3 scripts/test-network.py --keep /tmp/qs-network-results
```

Le test copie le code courant, remplace le backend et les lancements par des objets factices et accélère la minuterie. Il teste
la détection, le vrai gestionnaire du bouton dans `WifiPanel`, la commande du navigateur, la reprise de connectivité, les sondes
désactivées, la radio coupée, le changement de route, la reconnexion, aperçu / panneau épinglé et plusieurs panneaux. Journaux
et capture sont gardés avec `--keep` (destination nouvelle). Les sondes système et connexions réelles ne sont pas sollicitées.

Reste à vérifier sur un réseau réel d'hôtel ou d'aéroport : redirection, acceptation des conditions, disparition de l'avertissement
et navigation. Un VPN ou le mode HTTPS strict du navigateur peut empêcher l'accès au formulaire ; ces réglages restent à la main.
