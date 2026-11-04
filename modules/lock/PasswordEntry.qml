import QtQuick

// Saisie du mot de passe, commune au verrouillage (LockScreen) et à l'écran de connexion (modules/greeter) : texte tapé,
// verrouillage majuscules deviné à la frappe. Entrée émet `submitted` ; Échap et Ctrl+Retour arrière vident le champ.
QtObject {
    id: root

    property string text: ""
    property bool capsLock: false

    signal submitted
    signal typed   // caractère ajouté

    function reset(): void {
        text = "";
        capsLock = false;   // deviné à la frappe : l'état de la saisie précédente ne vaut plus
    }

    function key(event: var): void {
        const k = event.key;
        // Verrouillage majuscules : déduit d'une lettre tapée (majuscule sans Maj, ou minuscule avec Maj).
        if (event.text.length === 1 && event.text.toLowerCase() !== event.text.toUpperCase()) {
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            capsLock = (event.text === event.text.toUpperCase()) !== shift;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter)
            submitted();
        else if (k === Qt.Key_Escape)
            text = "";
        else if (k === Qt.Key_Backspace)
            text = (event.modifiers & Qt.ControlModifier) ? "" : text.slice(0, -1);
        else if (event.text !== "" && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {   // Suppr. : U+007F
            text += event.text;
            typed();
        }
    }
}
