import QtQuick
import qs.config

// Une ligne de texte où chaque segment a sa police, comme le label Pango de Waybar (THEME.md § 2, « Règles pour Qt ») :
// mêmes avances et même ligne de base qu'un texte d'un seul tenant.
// segments : [[police, texte], …] ; le texte est échappé ici.
Text {
    property var segments: []

    textFormat: Text.RichText
    font.family: Theme.font.text
    font.pixelSize: Theme.font.barText
    text: Array.from(segments ?? []).filter(s => s).map(([family, content]) => `<span style="font-family:'${family}'; white-space:pre">${escapeHtml(content)}</span>`).join("")

    function escapeHtml(s: string): string {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
}
