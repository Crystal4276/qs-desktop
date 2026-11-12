# Horizon — validation du 12 novembre 2026

GRUB 2:2.16-1, QEMU 11.1.3, OVMF 202608. Ressources régénérées, fontes PF2 reconstruites et module compilé depuis les sources
GRUB 2.16. Lors de cette validation initiale : aucun paquet installé, aucun changement de `/boot` ou `/etc` sur l'hôte.
Bureau réel vivant, PID 2001. Déploiement ultérieur et clarification des secours : voir la dernière section.
Les captures sont des images **du moteur GRUB dans QEMU**, pas des maquettes produites par le générateur SVG.

## Rendu réel

| Mode demandé | Framebuffer capturé | Résultat |
|---|---|---|
| 800×600 | 800×600 | validé |
| 1024×768 | 1024×768 | validé |
| 1366×768 | 1360×768 | **échec du framebuffer virtuel : image déformée** |
| 1920×1080 | 1920×1080 | validé |
| 1920×1200 | 1920×1200 | validé |
| 2560×1440 | 2560×1440 | validé |
| 3440×1440 | 3440×1440 | validé |
| 3840×2160 | 3840×2160 | validé |

Sept modes corrects inspectés ; en 1366×768, GOP annonce 1366 mais QMP expose 1360, avec lignes décalées. Reproduit avec VGA
et virtio-vga ; ne pas utiliser ces captures comme validation de ce mode. Le thème 1366 reste généré pour du matériel offrant
un framebuffer correct ; essai physique nécessaire. Les autres variantes du kit sont générées, pas toutes testées en VM.

`--auto` testé avec géométries GPU 1024×768 et 3440×1440 : ce firmware choisit **800×600**, le module charge cette variante.
Cela démontre la sélection selon le mode actif ; cela ne prouve pas que le firmware choisira le mode natif d'un moniteur.
Mode inconnu 1280×1024 : repli réellement obtenu en 1024×768. Aucun choix fait d'après Sway, xrandr ou la machine d'installation.

Palette, sélection grise, quatre icônes Arch et fontes Inter vérifiées dans les captures. Les proportions sont conservées.
Contrôle de 12 669 points des 14 SVG : erreur radiale maximale 0,000688 pixel (< 0,002), même rayon horizontal et vertical.
Un premier essai a révélé des pilules superposées ; le découpage vertical des neuf tranches a été corrigé puis retesté.

## Fonctionnement et pannes

- 4 et 7 entrées ; 12 entrées en 800×600, sélection finale accessible et titre long : captures `menu`, `navigation`, `scroll`.
- Sous-menu ouvert puis retour par Échap : capture `submenu`. Navigation au clavier et sélection grise inspectées.
- Délai natif 2 → 1 seconde et barre verte : capture `countdown` ; après navigation, le menu reste présent au-delà du délai.
- Fond manquant et module absent : menu texte natif utilisable, navigation toujours active.
- Fond PNG corrompu : repli texte et navigation validés ; résultat dans `.shots/grub-horizon/1024x768-7-corrupt/`.
- Les indications standard/LTS/fallback restent explicites ; une image absente ne produit pas d'entrée.

## Installation et vrai démarrage UKI

Overlay jetable de `laptop-state.qcow2`, base et variables d'origine conservées. Installation réelle de l'intégration dans
l'invité : succès ; deuxième passage « Horizon déjà à jour ». Empreintes des deux UKI identiques juste avant/après installation.
La VM contient uniquement `arch-linux.efi` et `arch-linux-lts.efi` : **aucun fallback ni rescue réel à tester dans cette image**.
Les six associations de libellés sont vérifiées séparément sur une racine synthétique.

Capture du menu installé : `.shots/grub-horizon/uki/installed-menu.png` : Arch Linux LTS, Arch Linux (standard), réglages UEFI.
L'ordre natif est conservé, donc LTS reste en tête dans cette VM. Démarrages complets avec déverrouillage LUKS :
LTS `6.18.62-1-lts`, puis standard `7.2.15-arch1-1`. Essais initialement en TCG, puis KVM pour le dernier parcours.
Retrait réel réussi, second retrait sans changement, dossier du thème absent et `GRUB_TIMEOUT=5` restauré.
La vérification d'empreinte après le dernier redémarrage n'a pas pu réutiliser sa liste située dans `/tmp` (effacée au boot) ;
ne pas confondre avec la comparaison réussie juste avant/après installation, conservée dans `uki/install.log`.

## Contrôles locaux

`python3 scripts/test-grub-horizon.py` : PASS (noms distincts, images absentes, simulation, paramètres conservés, idempotence,
refus d'écraser des réglages modifiés, retrait/réinstallation, restauration après panne injectée).
`python3 scripts/test-install.py` : **0 échec**, exécuté avec HOME et D-Bus jetables. Premier lancement dans le sandbox bloqué
sur sa socket D-Bus ; relance autorisée hors sandbox réussie. Syntaxe Python/Bash, `grub-script-check` du sélecteur et de la
configuration réelle de l'invité, `git diff --check` : OK.

Restent hors validation : écran physique 1366×768, firmware réel, Secure Boot, démarrage réel de variantes fallback/rescue
absentes de la VM et chargeurs non UKI. Le déploiement ultérieur sur le laptop est décrit à la fin du document.

## Correction des icônes d'actions

Après revue utilisateur : les icônes Advanced options, UEFI Firmware Settings et Restart manquaient dans l'implémentation
initiale. Ajout des trois SVG exacts de la référence approuvée et des 42 PNG (trois par déclinaison), avec les classes natives
`advanced`, `uefi-firmware` et `restart`. Aucune nouvelle entrée créée : association aux identifiants existants seulement.
Le banc utilise ces mêmes associations après création de ses entrées, ce qui vérifie le chargement réel des classes.

Régénération complète et nouveaux essais GRUB/QEMU en **800×600, 1920×1200, 3440×1440 et 3840×2160** : trois icônes visibles,
proportions et transparence conservées. Dimensions et contenu des 42 PNG vérifiés. Tests d'installation locale et de syntaxe
réussis ; idempotence et retrait toujours couverts par `test-grub-horizon.py`.

Nouvel overlay jetable UKI sur le disque d'essai précédent : installation réelle et deuxième passage sans changement, puis
redémarrage et capture du menu installé. L'entrée UEFI du générateur natif porte maintenant sa puce ; les seules entrées
restent les deux UKI et UEFI. Capture : `.shots/grub-horizon/uki-icons/installed-menu.png` ; aperçu des trois glyphes :
`.shots/grub-horizon/action-icons-detail.png`. Aucun changement du chargeur réel. Limite 1366×768 inchangée.

## Centrage et fallback sous Advanced options

Liste centrée sur le symbole selon le nombre d'entrées, puis limitée à sept lignes visibles. Le compte à rebours est placé
sous la zone maximale de liste ; footer dégagé. 98 géométries vérifiées (14 résolutions × 7 hauteurs), rendu GRUB contrôlé
avec 3, 4, 7 et 12 entrées avant regroupement. Sur les sept lignes, les centres observés dans les captures diffèrent de moins
de deux pixels du centre SVG, selon les arrondis et la rastérisation. Les lignes et le symbole restent à la même échelle.

Après regroupement : les quatre variantes de noyau du scénario donnent trois lignes principales (standard, LTS, Advanced
options) ; avec UEFI et Restart, cinq lignes. Le sous-menu contient exactement les deux fallback, avec leurs noms et icônes.
Rendu et navigation réelle validés en 800×600, 1920×1200, 3440×1440 et 3840×2160. Échap retourne au menu principal ; les deux
listes sont centrées. Défilement des 12 entrées avant regroupement revérifié en 800×600. Aucun kernel/initramfs supplémentaire
n'est créé. Sélection initiale numérique `2` et sélection mémorisée `advanced-options>fallback-standard` : toutes deux
préservées dans le journal GRUB ; absence de message d'erreur. Les commandes originales sont conservées par l'API native.

Un premier essai du sous-menu a révélé que `insmod` par chemin tentait de charger le module déjà présent. Le sélecteur
mémorise désormais son chargement dans le contexte GRUB exporté ; ouverture du sous-menu et retour sans cette erreur.

Tests locaux de déploiement PASS, dont un seul fallback disponible et absence de tout fallback (aucun sous-menu généré).
Syntaxe Python/Bash, sélecteur GRUB et empreintes du module reconstruits vérifiés.

Dans un nouvel overlay UKI, installation réelle du module et de la configuration mise à jour : deuxième passage sans
changement, aucun sous-menu Advanced options ajouté puisque cette VM n'a pas de fallback. Pour valider le démarrage d'une
entrée native après déplacement, un générateur **de test uniquement dans cet overlay** regroupe ses deux UKI **normales**.
Leurs titres restent standard/LTS : elles ne sont pas présentées comme de vrais fallback. Ouverture du sous-menu natif,
sélection du noyau standard et déverrouillage LUKS : démarrage `7.2.15-arch1-1` réussi. Empreintes des deux images inchangées
après ce démarrage. Captures et journaux : `.shots/grub-horizon/uki-group/`. La VM ne valide toujours pas le contenu d'un
initramfs fallback réel absent de cette image ; elle valide le déplacement et l'exécution des commandes UKI natives.

Deuxième démarrage du banc natif sans navigation : la sélection d'origine LTS est conservée malgré son déplacement dans le
sous-menu ; `6.18.62-1-lts` atteint la session après déverrouillage. Les deux SHA-256 sont toujours identiques. Générateur de
test retiré, retrait d'Horizon réussi et idempotent, délai initial 5 secondes restauré. Le mode texte sans module avec une
sélection mémorisée imbriquée a également été vérifié : elle redevient `fallback-standard`, directement accessible en secours.

## Secours du laptop dans Advanced options

Clarification utilisateur : les « deux fallback » désignent ici les UKI `arch-linux~rescue.efi` et
`arch-linux-lts~rescue.efi`, déjà présents. Ils sont désormais regroupés au même endroit que les éventuels presets
fallback classiques ; leurs titres restent « Arch standard (secours sans Plymouth) » et « Arch LTS (secours sans Plymouth) ».
Les noyaux normaux restent au premier niveau. Aucun changement du module GRUB ni des images n'est nécessaire.

`test-grub-horizon.py` PASS : coexistence fallback/rescue, secours seuls comme sur le laptop, un secours absent, absence
de tout secours, paramètres et images conservés, idempotence et retrait. GRUB réel QEMU à 800×600 et 1920×1200 : menu
principal, ouverture du sous-menu, titres standard/LTS, retour et interruption du compte à rebours vérifiés ; aucune erreur
GRUB dans les journaux. Les entrées de ce banc sont synthétiques, elles ne démarrent pas les vrais secours du laptop.
Captures : `.shots/grub-horizon/rescue/<résolution>/menu.png` et `submenu.png`.

Correction déployée sur le laptop via l'outil transactionnel avec polkit. `grub-script-check` PASS ; les deux identifiants
`~rescue.efi` figurent dans la commande de regroupement du grub.cfg généré. Empreintes des dix fichiers de démarrage
EFI/initramfs/noyaux identiques avant/après ; commandes de démarrage identiques. Deuxième installation : « Horizon déjà à jour »,
grub.cfg identique. Journal : `.shots/grub-horizon/deploy-rescue.log`. Aucun redémarrage de l'hôte déclenché ; rendu du
firmware physique et démarrage des secours à vérifier lors d'un essai manuel.
