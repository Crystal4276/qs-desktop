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
doublons au premier niveau. Sur le laptop, cela regroupe les deux images `~rescue.efi`, en conservant leurs titres explicites
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
en conservant le pied de page dégagé. Le sélecteur peut être réutilisé dans le sous-menu sans recharger le module.

## Utilisation

```sh
python3 scripts/grub-horizon-build.py
python3 scripts/grub-horizon-preview.py
python3 scripts/grub-horizon-preview.py --modes 800x600 --entries 12
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
le parseur cible n'accepte pas les pourcentages décimaux. Les tranches ont un découpage vertical adapté au calcul natif de
`item_height`, pour éviter le chevauchement constaté lors du premier test.

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
