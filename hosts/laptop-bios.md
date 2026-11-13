# Réglages BIOS du laptop actuel

Ces réglages résident uniquement dans le BIOS du laptop actuel. Ils sont conservés indépendamment de l'installation du bureau
et ne sont appliqués par aucun script à d'autres machines.

## Rétroéclairage du clavier

Réglages appliqués le 2026-11-09, rétablis et relus le 2026-11-13 après l'incident de démarrage :

| Option du BIOS | Valeur |
|---|---|
| Keyboard Backlight Timeout on AC | Never |
| Keyboard Backlight Timeout on Battery | 30s |

Extinction après 30 secondes sans activité sur batterie ; toujours allumé sur secteur, **sauf écrans en veille** : le bureau
l'éteint alors et remet son niveau à la reprise (`services/Idle.qml`, 2026-11-12).
Le délai de **30s sur batterie est volontaire** ; une frappe rallume le clavier.

Au contrôle du 2026-11-13, le BIOS signale encore un redémarrage nécessaire (`pending_reboot=1`). Après celui-ci : vérifier
que le clavier reste allumé sur secteur plus de 30 secondes, puis qu'il s'éteint après 30 secondes sans activité sur batterie
et se rallume à la frappe. La veille des écrans reste une exception à ces délais.

Une [réinitialisation RTC Dell](https://www.dell.com/support/kbdoc/en-us/000125880/) peut restaurer les réglages BIOS par défaut,
dont les délais observés à **10s** après l'incident. Recontrôler alors séparément les valeurs secteur et batterie du tableau.
Pour revenir aux délais d'origine observés sur cette machine, remettre les deux à **10s**. Aucun service ni paquet ajouté
pour ces réglages BIOS.
