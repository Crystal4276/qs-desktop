# GRUB Horizon

Thème du profil **travail**, pour **GRUB 2.16 x86_64-efi + UKI**. Le générateur natif `uki` reste en place ; aucune image,
ligne de commande ou clé LUKS n'est modifiée ; les entrées de secours restent accessibles et le choix de démarrage est conservé. `10_linux` reste désactivé sur ces machines.
Le GRUB classique à initramfs séparés et les autres plates-formes ne sont pas intégrés à cette première version.

## Entrées

Les presets mkinitcpio sont associés aux fichiers UKI **réellement présents**, même si leurs PRETTY_NAME sont identiques :

| Image | Titre |
|---|---|
| linux / default | Arch Linux (standard) |
| linux-lts / default | Arch Linux LTS |
| linux / fallback | Arch Linux (standard, fallback) |
| linux-lts / fallback | Arch Linux LTS (fallback) |
| linux / rescue | Arch standard (secours sans Plymouth) |
| linux-lts / rescue | Arch LTS (secours sans Plymouth) |

Le module `horizon.mod` ajoute une classe `arch` et remplace le titre des identifiants UKI reconnus ; ni sourcecode,
ni paramètres ne changent ; le choix par défaut est conservé lors du regroupement et du tri. Les images inconnues gardent leur présentation. Une nouvelle image demande de
relancer l'installation pour actualiser l'association ; le chargement des images reste natif et dynamique.
Une déclaration fallback commentée n'est pas une preuve que l'image existe. Aucun fallback n'est construit par ce chantier.

Les actions présentes portant les identifiants `advanced-options`, `uefi-firmware` et `restart` reçoivent respectivement
les icônes de couches, puce et redémarrage de la référence approuvée, en couleur texte. Le générateur UEFI natif utilise
`uefi-firmware` : l'icône s'applique aussi au menu installé. Pour une entrée personnalisée Advanced options ou Restart,
utiliser l'identifiant correspondant ou la classe native `advanced`/`restart`. L'action **Restart** est créée si elle manque,
avec la commande native `reboot` ; une entrée existante portant cet identifiant est réutilisée. Aucun réglage UEFI n'est ajouté
si le générateur natif n'en fournit pas.

Après découverte native des UKI et regroupement des secours, le menu affiche **Arch Linux (standard)**, **Arch Linux LTS**,
**Advanced options**, **UEFI Firmware Settings**, puis **Restart**, dans cet ordre. Les noyaux ou sous-menus absents sont
omis ; les entrées supplémentaires restent accessibles à la suite, dans leur ordre relatif initial. Les objets natifs sont
simplement reliés dans le nouvel ordre, sans recopier leurs commandes. Le défaut numérique est ramené à l'identifiant de
l'entrée initialement choisie, et un défaut mémorisé dans le sous-menu reste valide. Une stratégie automatique `$fallback`
préexistante conserve son ordre et ses index ; elle exclut ce tri et l'ajout de Restart.

Les variantes de secours présentes (`fallback` et `rescue` sans Plymouth) sont regroupées sous **Advanced options**, sans
doublons au premier niveau. Sur le laptop, cela regroupe les deux images `.bak.efi`, en conservant leurs titres explicites
standard/LTS et « secours sans Plymouth ». Les noyaux normaux restent au premier niveau. Le module
conserve les objets natifs d'origine et en copie intégralement commandes, arguments, identifiants, droits et raccourcis à
l'ouverture du sous-menu natif. La sélection par défaut est adaptée à son nouveau chemin, y compris si elle était numérique
ou déjà mémorisée dans ce sous-menu. Sans ressources graphiques ou sans module, les variantes restent directement accessibles
dans le menu texte et une sélection mémorisée est ramenée à leur identifiant natif. Un sous-menu Advanced options déjà
personnalisé ou une stratégie automatique `$fallback` préexistante est conservé sans réorganisation automatique.
Sans image de secours présente, aucun sous-menu vide n'est ajouté.

Le centre vertical de la liste visible est celui du symbole : 48 % de la hauteur. Chaque résolution possède sept fichiers
`theme-1.txt` à `theme-7.txt`, partageant les mêmes ressources. Le module choisit le nombre de lignes après découverte des
entrées ; sept lignes au maximum, puis défilement natif. Le compte à rebours est placé sous la zone maximale de la liste,
en conservant le pied de page dégagé. Le sélecteur peut être réutilisé dans le sous-menu sans recharger le module ni les fontes.
Une préparation native vérifie les ressources communes une seule fois par résolution réussie.
Les images ne sont ouvertes pour leur présence qu’avec le type natif GET_SIZE ; leurs lectures
par le moteur graphique conservent les vérificateurs et les mesures TPM. Le manifeste resources.lst
est généré depuis les PNG/PF2 livrés et toute liste invalide ou incomplète refuse la préparation.
Le menu principal utilise deux appels légers au sélecteur : précontrôle avant regroupement pour
préserver le secours texte, puis choix de la hauteur finale après regroupement et tri.
Le sous-menu choisit directement sa hauteur et son thème par les API natives du module,
sans rejouer le sélecteur shell ; une nouvelle résolution exige une nouvelle préparation.
Un thème enfant absent ou corrompu laisse les secours accessibles en texte ; Échap
restaure le contexte graphique parent. Le cache est privé au module,
indépendant des environnements temporaires des sous-menus ; un échec n’est jamais mémorisé.

## Utilisation

```sh
python3 scripts/grub-horizon-build.py
python3 scripts/grub-horizon-preview.py
python3 scripts/grub-horizon-preview.py --modes 2560x1440 --entries 12
python3 scripts/grub-horizon-preview.py --modes 1024x768 --broken
python3 scripts/grub-horizon-preview.py --modes 1024x768 --missing-module
python3 scripts/grub-horizon-preview.py --modes 3440x1440 --auto
python3 scripts/grub-horizon-preview.py --modes 1920x1200 --shuffled --without-restart
python3 scripts/grub-horizon-setup.py audit
python3 scripts/grub-horizon-setup.py install --dry-run
python3 scripts/test-grub-horizon.py
```

L'aperçu fabrique un exécutable GRUB autonome et lance QEMU/OVMF sans réseau ni disque de l'hôte. Les captures QMP, journaux,
configuration de test et résultats sont dans `.shots/grub-horizon/`. Les entrées des aperçus synthétiques exécutent `halt`.
Elles servent à tester le menu ; ce ne sont pas des noyaux installés. `--auto` conserve le choix automatique du firmware.

L'installation réelle est **à approuver séparément après examen des captures et de l'audit privilégié** :

```sh
pkexec python3 "$PWD/scripts/grub-horizon-setup.py" audit
# Après accord explicite seulement :
python3 scripts/grub-horizon-setup.py install
python3 scripts/grub-horizon-setup.py status
python3 scripts/grub-horizon-setup.py uninstall
```

La commande demande polkit, sauvegarde dans `/var/lib/qs-desktop/grub-horizon`, copie le thème sous
`/boot/grub/themes/qs-horizon`, ajoute `/etc/grub.d/99_qs_horizon` et un hook pacman. Elle configure le menu à deux secondes,
gfxmode auto et gfxterm, puis produit et valide un nouveau grub.cfg avant remplacement. Aucun `grub-install`, mkinitcpio ou
redémarrage. Un échec de génération restaure les fichiers et la configuration précédents. Les modifications ultérieures des
réglages suivis provoquent un refus de retrait automatique : les examiner avant restauration.
`install.sh` reprend cette étape uniquement avec les étapes système, profil travail, si `15_uki` existe ; passage en jeux ou
`--uninstall` : retrait des ajouts suivis. Aucun paquet GRUB n'est installé automatiquement.
Dans `install.sh`, installation et retrait utilisent sudo comme les autres étapes système, en réutilisant son authentification
en cache ; aucune fenêtre polkit supplémentaire. Le mode simulation n'appelle aucun outil d'élévation. L'outil Horizon lancé
seul en utilisateur conserve sa demande polkit.

## Résolutions et secours

14 ressources exactes, dessin identique, fontes PF2 Inter, emblèmes vectoriels et identité DM Sans 600 ; fontes et licences
embarquées. Le sélecteur lit la résolution active avec `grub_video_get_info`, sans résolution Linux ni variable GRUB supposée.
Un mode inconnu provoque un nouvel essai en 1024×768 puis 800×600 ; après relecture du mode réel, aucune image n'est étirée.
Si un fichier ou le module manque, le menu texte natif prend le relais dans gfxterm, sinon dans la console du firmware.
GRUB assure lui-même défilement, sous-menus et interruption du délai. Les pourcentages sont entiers avec correction en pixels :
le parseur cible n'accepte pas les pourcentages décimaux. Les pilules utilisent trois tranches verticales W/C/E natives, avec hauteur et espacement
compensés pour préserver exactement leur géométrie tout en réduisant les mesures TPM.

Le délai vient exclusivement de GRUB : label `__timeout__` « Booting in %d s », progression native verte, aucune attente ajoutée.

Un hook de mise à jour du paquet grub retire le module : menu texte jusqu'à reconstruction puis réinstallation d'Horizon.
Le module livré est lié à la version du paquet enregistrée dans `module.json` ; toute autre version est refusée. La version du
binaire EFI déjà installé doit également correspondre : ne pas déployer sur un ancien binaire de chargeur non mis à jour.
Secure Boot/lockdown peut refuser le module externe : conserver le menu natif ; aucun contournement ni changement de signature.

## Reconstruction du module

Sources officielles : archive `grub-2.16` de
https://gitlab.freedesktop.org/gnu-grub/grub/-/archive/grub-2.16/grub-grub-2.16.tar.gz ; empreinte dans
`dotfiles/grub/horizon/module.json`. Gnulib : commit `9f48fb992a3d7e96610c4ce8be969cff2d61a01b`.
Dans un dossier de travail jetable, extraire GRUB et ce commit de Gnulib dans `gnulib/`, puis :

```sh
./bootstrap --no-git --gnulib-srcdir=gnulib --skip-po
./configure --target=x86_64 --with-platform=efi --disable-werror
# Depuis le dépôt :
python3 scripts/grub-horizon-build.py --grub-build /chemin/vers/les/sources-configurees
```

Le script ajoute la définition du module, régénère les Makefiles et produit `horizon.mod` ; aucune installation de GRUB.
Revoir la version et l'empreinte des sources dans le manifeste pour tout changement de version ; retester en VM.
Le code du module est GPL-3.0-or-later (`scripts/grub/COPYING`). Les dessins Core Lab et KAUST conservent la provenance du dépôt.
DM Sans : Google Fonts, `ofl/dmsans/DMSans[opsz,wght].ttf`, licence OFL jointe ; axes optique 22, graisse 600.

Résultats et limites des essais : [validation VM](GRUB-HORIZON-VALIDATION.md).

## Retour arrière sans démarrage normal

Démarrer un support Arch, déverrouiller et monter la racine et l'ESP comme pour une réparation de la machine. Dans le chroot,
restaurer les fichiers numérotés de `/var/lib/qs-desktop/grub-horizon/original` : `0` = `/etc/default/grub`, `1` = générateur
Horizon préexistant, `2` = hook préexistant, `3` = ancienne configuration GRUB. Si `1`/`2` sont absents, retirer uniquement
`/etc/grub.d/99_qs_horizon` et `/etc/pacman.d/hooks/91-qs-horizon-module.hook`. Retirer le dossier du thème puis régénérer et
valider grub.cfg. La copie `3` permet aussi de remettre immédiatement la configuration précédente. Aucun noyau/UKI n'est retiré.

## Régression TPM

Le banc graphique accepte `--tpm` (swtpm jetable raccordé à QEMU, dossier de résultat distinct
`*-tpm`). Les résultats notent explicitement le raccordement. Cette option teste le menu,
pas un démarrage Linux : la validation du budget exige aussi une VM UKI complète.
La matrice courante est 1920×1200, 2560×1440, 3440×1440 et 3840×2160.

Les injections `--resource-fault empty|unterminated|nul|missing-font|missing-last`
remplacent uniquement la liste embarquée dans l’image de test. Le sélecteur est appelé
deux fois : un échec ne doit pas devenir un succès grâce au cache. Le repli texte doit
rester utilisable. `--broken`, `--missing-module` et `--corrupt-background` couvrent les
autres pannes du rendu. `--missing-child-theme` et `--corrupt-child-theme`
vérifient le repli texte du sous-menu et le retour graphique au parent.

`python3 scripts/tpm-eventlog.py <journal-binaire>` fournit tailles, comptes par PCR,
lectures de fontes et marqueurs SMBIOS/UKI strictement typés. Il ne publie pas les
commandes mesurées, variables EFI ni identifiants du matériel.
`python3 scripts/test-tpm-eventlog.py` couvre les marqueurs trompeurs et les troncatures.
`python3 scripts/check-grub-horizon-tpm.py <journal> [--stress] [--mode 1920x1200]` applique les critères
de banque, calibration, inventaire réellement mesuré, marqueurs, fontes et budget.

Pour comparer témoin et correctif, employer un overlay de la VM UKI documentée dans
DEVELOPMENT.md, une copie de ses variables OVMF et un état swtpm neuf préparé avec
`swtpm_setup --tpm2 --tpm-state <dossier> --pcr-banks sha256`. Raccorder cet état via
`-chardev socket,id=chrtpm,path=<socket> -tpmdev emulator,id=tpm0,chardev=chrtpm
-device tpm-tis,tpmdev=tpm0`. Ne pas raccorder le TPM physique.
La surcharge bénigne du générateur de test placé juste avant Horizon doit être calibrée
dans le journal réel : environ 40 Kio avant le premier chargement du sélecteur, SHA-256
seul comme le laptop. Le témoin et le correctif utilisent exactement cette même surcharge.
Les quatre banques par défaut de libtpms remplissent trop tôt le journal et ne constituent
pas une contre-épreuve représentative.

Critères : démarrage UKI complet sous 56 Kio, mesures UKI/SMBIOS présentes, puis trois
allers-retours dans Advanced options et 100 déplacements clavier sans saturation du
budget 64 Kio. Le moteur graphique peut relire les PNG quand le chemin du thème change :
le cache des fontes ne dispense pas de mesurer ce scénario. Tout échec bloque le déploiement.

## Noms des secours compatibles avec systemd

Les secours QS utilisent `<image>.bak.efi`. Le caractère `~` des anciens noms était
accepté par GRUB mais refusé par le lecteur BLS de systemd. La restriction de noms
est définie dans la [Boot Loader Specification](https://uapi-group.org/specifications/specs/boot_loader_specification/).
Le suffixe `.bak.efi` garde l'image normale avant son secours dans le tri décroissant
filevercmp, y compris sans le module Horizon.

À l'installation d'Horizon, les anciens secours dont le preset porte notre marqueur
sont migrés dans la même transaction que grub.cfg : copie vérifiée par empreinte,
mise à jour des presets et des identifiants, validation de la configuration, puis
retrait des anciens noms. Aucun noyau ni initramfs n'est reconstruit. Une destination
différente est refusée ; tout échec restaure les noms et les réglages précédents.
Les anciennes sélections explicites ou mémorisées sont traduites par le menu Horizon
vers les nouveaux identifiants. Les images ne sont pas supprimées au retrait d'Horizon :
elles appartiennent à l'étape Plymouth, qui lit leur chemin courant dans le preset.
`install.sh` exécute cette migration après l'étape Plymouth ; un appel isolé à l'ancien
installateur Plymouth ne migre pas les noms déjà gérés.
