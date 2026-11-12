# Réglages BIOS du laptop actuel

Ces réglages résident uniquement dans le BIOS du laptop actuel. Ils sont conservés indépendamment de l'installation du bureau
et ne sont appliqués par aucun script à d'autres machines.

## Rétroéclairage du clavier

Réglages appliqués et relus le 2026-11-09 :

| Option du BIOS | Valeur |
|---|---|
| Keyboard Backlight Timeout on AC | Never |
| Keyboard Backlight Timeout on Battery | 30s |

Extinction après 30 secondes sans activité sur batterie ; toujours allumé sur secteur, **sauf écrans en veille** : le bureau
l'éteint alors et remet son niveau à la reprise (`services/Idle.qml`, 2026-11-12).

Le BIOS signale un redémarrage nécessaire : à faire par l'utilisateur, puis essai réel sur batterie et secteur.

Pour revenir à l'état précédent, remettre les deux délais à **10s** dans le BIOS. Aucun service de session ni paquet ajouté.
