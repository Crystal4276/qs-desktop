# Validation ZeroTier — 12 novembre 2026

## Environnement

QEMU 11.1.3 / KVM, x86_64, 4 vCPU, 8 Gio, disque virtuel 40 Gio.
Image officielle Arch basic `20261101.620452`, SHA-256 vérifié auprès du miroir Arch :
`bc52e4dc79cd55b55ae2d1c119b1ffe61e93f5545ea800d5183a04668de1e962`.
Overlay indépendant, image initiale conservée pour restaurer un état vierge.
Réseau QEMU utilisateur avec administration SSH sur localhost uniquement ; aucune modification
libvirt ou du réseau de l'hôte. La méthode QEMU directe reprend le banc existant de DEVELOPMENT.md.

## Installation et résultats

Révision de départ : `e982dd1260d6551f0af5974d2aa27c035e789807`, complétée par les changements
ZeroTier de cette intervention dans la copie invitée. Aucun installateur alternatif ni faux paquet.
Prérequis : git, NetworkManager, sudo ; nom d'hôte fixe. Compte arch ajouté à wheel.
L'image avait `/etc/sudoers.d/arch` aux mauvaises permissions : correction en 0440 dans l'invité.

Commande réelle : `./install.sh --yes --profil travail`.

| Contrôle | Résultat observé |
|---|---|
| Premier passage | Code 0 ; paquets, configurations et étapes système réellement exécutés |
| Deuxième passage après reboot | Code 0 ; permissions sudoers corrigées, configuration différée finalisée |
| Troisième et quatrième passages | Codes 0 ; aucune jonction, activation ou réécriture ZeroTier supplémentaire |
| Redémarrage | Boot ID changé ; même Node ID ; service ZeroTier actif et activé |
| Graphique | Greeter affiché, authentification puis session Sway avec bureau QS Desktop |
| Sans autorisation | ACCESS_DENIED correctement signalé ; aucune adresse privée attribuée |
| Coupure réelle du lien virtuel | Configuration conservée et aucun faux succès |
| Service redémarré sans lien | REQUESTING_CONFIGURATION jusqu'au délai, diagnostic explicite et code 3 |
| Reconnexion | Retour ONLINE puis ACCESS_DENIED, sans nouvelle identité ni perte d'adhésion |
| Profil jeux / --no-system | Simulations code 0 ; pas d'installation complète du profil jeux |

La panne a été testée sur l'étape système ZeroTier réellement utilisée par install.sh ;
l'installateur complet a été exécuté connecté, pas entièrement pendant la coupure.
L'idempotence ZeroTier est confirmée ; le script complet retente toujours le clonage optionnel du
DigitalMicrograph privé inaccessible (notamment une ligne `+ mkdir -p` pour son parent déjà présent).
Ce rappel préexistant n'est pas présenté comme une installation DigitalMicrograph réussie.

## Paquets et services

`pacman -Q` : zerotier-one 1.16.2-2, gvfs et gvfs-smb 1.62.0-3,
smbclient 2:4.25.1-1, openssh 10.6p1-3, iperf3 3.22-2.
`gvfsd-smb`, `gvfsd-smb-browse` et `smb.mount` présents.
`smbclient --version`, `ssh -V` et `iperf3 --version` exécutés avec succès.
ZeroTier : `active` et `enabled`. sshd de bootstrap désactivé avant le dernier passage :
il reste `disabled`, comme avahi-daemon et iperf3. Le SSH actif pendant l'administration était
celui de l'image de test ; aucun nouveau serveur SSH n'est activé par install.sh.
Samba historique préservé selon le choix utilisateur, sans nouveau partage ou compte.
Route par défaut conservée sur le réseau virtuel ; DNS ZeroTier, routes globales et par défaut désactivés.

## Tests complémentaires et limites

`test-install.py` : 0 échec ; `test-zerotier.py`, `test-reflector.py`,
`test-sudo-pacman.py` : PASS. Syntaxe Bash et `git diff --check` : OK.
Les tests isolés complètent les exécutions réelles ; ils ne prouvent aucune connectivité.

Autorisation Central non accordée, conformément au choix utilisateur : **aucune IP ZeroTier et
aucun test de connectivité VM-desktop validés**. Autoriser le nouveau membre reste nécessaire.
Aucune identité, clé ou jeton du desktop n'a été transféré ; les Node ID sont distincts.
Le retrait du bureau conserve le service et les adhésions ZeroTier ; leur retrait est une opération réseau explicite.

Preuves brutes ignorées par Git : `.shots/zerotier-validation/` (journaux, codes de sortie,
capture Sway). VM arrêtée, disque temporaire sous `/tmp/qs-zerotier-validation/`.
Les VM préexistantes et les services/réseaux du desktop n'ont pas été modifiés.
L'instance réelle QS Desktop et l'état ZeroTier du desktop sont inchangés à la fin des contrôles.
