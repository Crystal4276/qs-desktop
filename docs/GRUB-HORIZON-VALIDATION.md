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

## Ordre explicite du menu et action Restart

Correction après retour sur le vrai laptop : le tri natif UKI plaçait LTS avant standard, et Advanced options prenait la place
du premier secours. Le module remet maintenant les objets natifs dans l'ordre standard, LTS, Advanced options, UEFI,
Restart ; les entrées supplémentaires gardent leur ordre relatif à la suite. Le défaut initial est conservé par identifiant,
y compris dans Advanced options. Restart, absent du menu du laptop, est ajouté avec la commande GRUB native `reboot` ;
une entrée existante est réutilisée.

Module reconstruit depuis les archives GRUB 2.16/Gnulib dont les empreintes sont épinglées dans le manifeste. Compilation
sans avertissement. Tests hors VM PASS : ordre des identifiants dans le générateur après regroupement, idempotence,
restauration et appels sudo de l'installateur. Syntaxe Python et contrôles de diff OK.

GRUB réel à 800×600 et 1920×1200, entrées initialement inversées, Restart initialement absent : ordre des cinq titres
vérifié dans la sortie série native et visuellement. Avec Restart préexistant : toujours cinq entrées, sans doublon.
Défaut numérique, défaut par identifiant et défaut mémorisé dans le sous-menu préservés. Navigation vers les deux secours,
retour clavier et interruption du délai validés ; aucune erreur GRUB. Le banc vérifie désormais automatiquement cet ordre
et le nombre de lignes. Captures `*-shuffled*/menu.png` dans `.shots/grub-horizon/`.

Sélection effective du nouveau bouton Restart en VM : événement QMP `RESET`, `guest=true`, `reason=guest-reset`, conservé
dans `.shots/grub-horizon/restart-verified.json`. Aucun redémarrage de l'hôte n'est déclenché par ce test.

Première tentative de déploiement de cette correction sur le laptop : authentification polkit fermée (« Request dismissed »).
Aucun fichier système modifié par cette tentative. Après accord explicite pour relancer polkit, correction déployée :
ordre des identifiants confirmé dans grub.cfg, module installé identique au module testé, grub-script-check PASS.
Empreintes des dix fichiers de démarrage EFI/initramfs/noyaux et commandes de démarrage identiques avant/après.
Second passage « Horizon déjà à jour », grub.cfg inchangé. Journal `.shots/grub-horizon/deploy-order.log`.
Reste à vérifier visuellement le menu du firmware au prochain redémarrage manuel ; aucun redémarrage de l'hôte déclenché.

## Saturation du journal TPM — correction du 12 novembre 2026

Travail sur copie isolée ; aucune écriture dans /boot ou /etc du laptop. Le sélecteur
généré passe de 609 à 24 lignes : préparation native des ressources communes,
cache par résolution dans le module, fontes chargées une seule fois après succès.
Deux appels légers sont conservés au menu principal (précontrôle et hauteur finale),
contre trois préparations complètes auparavant. Les sous-menus réutilisent la préparation.

Validations locales : test-grub-horizon.py PASS ; test-install.py 0 échec ;
test-tpm-eventlog.py PASS (preuves positives/négatives, banques et troncatures).
Compilation native GRUB 2.16 depuis les archives et Gnulib épinglés, sans avertissement
sur le module Horizon ; empreintes source/binaire actualisées ensemble.

Rendu réel QEMU : 1920×1200, 2560×1440, 3440×1440 et 3840×2160 ; ordre initial inversé,
Restart initialement absent, regroupement, sous-menu et retour clavier : PASS.
Pannes natives en 1920×1200 : liste vide, non terminée, NUL incorporé, fonte absente,
dernière ressource absente ; deux tentatives échouent sans activer le thème : PASS.
Module absent, fond absent et PNG corrompu : repli texte utilisable. Défilement 12 entrées : PASS.
Aperçu avec swtpm réellement raccordé : PASS ; résultats séparés et nettoyage des deux processus.

### Trois revues indépendantes

1. **TPM / cause racine** : contrôle de présence des PNG corrigé vers le type natif
   GET_SIZE, pour éviter une mesure supplémentaire avant le vrai rendu. Les lectures
   réelles restent mesurées. Sélection finale de l'aperçu réalignée sur le générateur.
2. **Sûreté / C** : rejet des NUL incorporés avant tout chargement ; allocations,
   erreurs, cache de module et contrats de regroupement examinés. Correction revérifiée.
3. **Tests / livraison** : marqueurs d'analyse limités aux PCR/types/tags attendus,
   lectures de fontes comptées en PCR9 ; contre-exemples ajoutés et vérifiés. Nettoyage
   QEMU/swtpm renforcé par ExitStack, terminate/wait/kill bornés ; résultats TPM distincts.
   Dernière passe sur le diff après corrections : aucun défaut statique ouvert.

Le budget du démarrage complet et la navigation prolongée font l'objet d'une validation
UKI séparée : un aperçu synthétique qui exécute halt ne les prouve pas.

Complément après revue TPM : les pilules utilisent trois tranches verticales W/C/E
natives au lieu de neuf. Même SVG, mêmes caps, même pas et même centre du texte/icône ;
les anciennes tranches sont supprimées. Comparaison pixel à pixel en 1920×1200 : zéro
pixel différent dans la zone du menu principal et du sous-menu, hors compte à rebours.
Matrice 2560×1440, 3440×1440 et 3840×2160 repassée avec ces ressources : PASS.
Les revues TPM et sûreté ont revérifié le découpage, les 98 géométries et l'absence
physique des tranches inutilisées. L'installation vérifie aussi l'inventaire exact pour
ne pas laisser une ancienne tranche rajoutée rétablir silencieusement les lectures.

Calibration UKI : swtpm SHA-256 seul, 247 commandes bénignes de fixture avant
Horizon ; le journal témoin contient 41 178 octets avant le premier sélecteur,
65 372 octets au total et seulement deux des trois lectures de chaque fonte
attendues. Le premier essai libtpms à quatre banques a été écarté : il saturait
avant Horizon. Sur la même surcharge SHA-256, la première correction (avant
optimisation des pilules) démarre complètement à 52 424 octets, avec une seule
lecture de chaque fonte, les mesures .linux/.initrd en PCR11 et SMBIOS type1
en PCR1. OVMF ne fournit pas les mêmes tables SMBIOS que le laptop.
Deux vrais UKI de secours ont ensuite été construits avec mkinitcpio -S plymouth
dans l'overlay uniquement ; les empreintes des deux UKI normales restent identiques.

Contrôle du banc : un premier stress après transfert tar a été écarté car le
paquet source dans la VM conservait les anciennes tranches malgré leur suppression
dans le dépôt. Les noms des lectures PCR9 ont révélé cette erreur de transfert.
Le transfert remplace maintenant le dossier source complet, et les fichiers déployés
sont vérifiés avant redémarrage. `check-grub-horizon-tpm.py` rejette automatiquement
un journal provenant d'anciennes tranches, des mauvaises banques ou d'un démarrage
sans les mesures UKI/SMBIOS réelles. Une petite taille de journal seule n'est pas une preuve.

Raffinement final : les sous-menus choisissent leur thème directement depuis le module
avec les API natives (résolution, nombre de lignes, préparation déjà réussie, contrôle
de présence, set/export theme), sans relire select.cfg. Le parent garde son contexte
et ses entrées ; thème enfant absent ou corrompu → texte utilisable, Échap → parent
graphique. Ces deux pannes ont été exécutées en GRUB réel. Les trois revues ont examiné
ce chemin, la libération mémoire et les mesures conservées.
Le stress avec trois tranches mais encore le bootstrap shell passait à 65 458 octets ;
la marge de 78 octets était insuffisante, d'où ce dernier retrait de commandes répétées.

### Résultats finaux acceptés (13 novembre 2026)

- Démarrage standard après trois allers-retours, 100 déplacements et 60 secondes
  d'attente : **60 676 octets**, budget 65 536, marge 4 860 octets.
- Démarrage normal LTS : **52 235 octets**, budget 57 344 ; marge au plafond
  firmware 13 301 octets. Dans les deux cas : préfixe 41 178 octets, SHA-256 seul,
  toutes les fontes attendues mesurées une fois, .linux/.initrd et SMBIOS type1
  présents ; bootctl confirme Measured UKI=yes et Measured OS=yes.
- Le stress contient exactement deux lectures de select.cfg sur tout le boot,
  trois invocations de sous-menu et 42 lectures des tranches de pilules (6×7 vues).
- Les sous-menus absents/corrompus sont maintenant capturés après deux frames
  identiques et présence des lignes de texte. Les deux entrées sont visibles ;
  bande des entrées : 67 908 pixels non noirs dans chaque cas. Échap restaure
  le menu graphique. L'ancienne capture de corruption, prise pendant le redessin,
  a été écartée puis remplacée.
- Dans la vraie VM : échec grub-mkconfig injecté (code 99), restauration vérifiée
  par empreintes des quatre fichiers suivis, deuxième installation sans changement,
  retrait puis second retrait réussis ; UKI normales inchangées.
- Dernière matrice avec le module final et captures stables : les quatre résolutions
  passent. Aucun écran virtuel ni processus d'aperçu n'est laissé sur le bureau réel.

Ces résultats valident les parcours ci-dessus sous OVMF ; ils ne remplacent pas
l'essai du firmware physique après déploiement séparément autorisé.

Dernier essai : sélection mémorisée `advanced-options>arch-linux-lts~rescue.efi`,
invite LUKS en texte, déverrouillage puis démarrage LTS 6.18.62-1-lts. bootctl
confirme le stub `/EFI/Linux/arch-linux-lts~rescue.efi` et les mesures UKI/OS ; les
deux UKI normales gardent leurs empreintes. La VM est ensuite retirée du banc.
Le firmware physique du laptop reste inchangé et son essai reste à faire après
validation du déploiement.
