import QtQuick
import qs.config

// Module texte de la barre : icône en Hack Nerd Font collée à du texte Inter (THEME.md § 2), dans une seule ligne.
// Utilisé par les mises à jour, le GPU, le CPU, la mémoire, le réseau et l'horloge.
Item {
    id: root

    property color color: Theme.color.text
    property bool shown: true
    property int horizontalPadding: Theme.bar.modulePadding
    property int minWidth: 0
    // Dernier module affiché de sa pilule (Bar.qml) : lui seul a un padding droit. Entre deux modules, un seul padding
    // au lieu de deux (ta demande du 2026-10-20).
    property bool trailing: true
    readonly property int rightPadding: trailing ? horizontalPadding : 0
    // Survol : contrastes inversés, comme le bouton Arch (fond de la couleur du module, texte `mantle`) ; `held` : gardé sans survol
    // (calendrier épinglé).
    property bool highlightOnHover: false
    property bool held: false
    readonly property alias hovered: hover.hovered
    readonly property bool ownHighlight: highlightOnHover && (hovered || held)
    // Pilule survolée en bloc (Bar.qml) : `pillHighlight` en donne la couleur (null : pas de survol en bloc), la pilule
    // dessine le fond et met `pillHighlighted` ; le texte passe en `mantle`.
    property var pillHighlight: null
    property bool pillHighlighted: false
    // Rangée de modules de la pilule (Pill.qml : rangée → Loader → module) : un clic sur l'un d'eux referme le panneau commun.
    readonly property Item pillRow: parent?.parent ?? null
    readonly property bool highlighted: ownHighlight || pillHighlighted

    // [[police, texte, valeurs?, écart?], …] ; valeurs : tous les textes que le segment peut afficher. Il prend la largeur du plus large,
    // mesurée dans sa police, et s'aligne à droite dedans : la pilule ne change jamais de taille, et n'est pas plus large que
    // nécessaire (ta demande du 2026-10-20). Écart : marge gauche du segment, en pixels.
    // Valeurs : liste constante, lue dans un service et pas construite ici : elle n'est mesurée qu'une fois (à chaque nouvelle
    // valeur affichée, cette mesure faisait plus de 80 % du temps QML au repos, qmlprofiler, docs/PERFORMANCE.md).
    property var segments: []

    signal clicked

    implicitWidth: Math.max(minWidth, row.implicitWidth + horizontalPadding + rightPadding)
    implicitHeight: reference.implicitHeight + 2 * Theme.bar.modulePadding

    Rectangle {
        anchors.fill: parent
        visible: root.ownHighlight
        // Le fond suit l'arrondi intérieur de la pilule (module seul dans sa pilule).
        radius: Theme.bar.pillRadius - Theme.bar.pillBorder
        color: root.color
    }

    // Un Text par segment, pour la largeur fixe.
    Row {
        id: row
        // Centrée dans l'espace entre les paddings (largeur minimale plus grande que le contenu : réseau).
        x: root.horizontalPadding + Math.max(0, root.width - root.horizontalPadding - root.rightPadding - implicitWidth) / 2
        anchors.verticalCenter: parent.verticalCenter
        height: reference.implicitHeight

        // Hauteur et ligne de base de la ligne entière (texte d'un seul tenant), que suivent les segments. Elles dépendent des polices,
        // pas des valeurs : un chiffre à la place de chacune, le texte riche n'est pas remis en page à chaque valeur.
        RichLabel {
            id: reference
            visible: false
            segments: Array.from(root.segments ?? []).map(([family, content, values]) => [family, values?.length ? "0" : content])
        }

        Repeater {
            // Le nombre de segments, pas le tableau : les Text restent en place quand seules les valeurs changent.
            model: root.segments?.length ?? 0

            Text {
                id: label

                required property int index
                readonly property var segment: root.segments[index] ?? []

                anchors.baseline: reference.baseline
                // Arrondi au pixel : la mesure et le texte affiché peuvent différer d'une fraction de pixel. Le dessin compte
                // aussi : les icônes Nerd Font débordent de leur avance (jusqu'à 11 px), l'espace qui suit doit rester visible.
                readonly property rect ink: metrics.tightBoundingRect(text)
                width: Math.ceil(Math.max(implicitWidth, leftPadding + ink.x + ink.width, leftPadding + reserved))

                // Largeur du plus large texte de `segment[2]`, remesurée seulement si la liste ou la police change.
                property var measuredValues: null
                property real reserved: 0

                function measure(): void {
                    const values = segment[2] ?? null;
                    if (values === measuredValues)
                        return;
                    measuredValues = values;
                    reserved = values ? values.reduce((widest, s) => Math.max(widest, metrics.advanceWidth(s)), 0) : 0;
                }

                onSegmentChanged: measure()
                Component.onCompleted: measure()

                // Valeurs à largeur réservée : alignées à droite ; icônes : à gauche, leur débord tombe dans la largeur ajoutée.
                horizontalAlignment: segment[2] ? Text.AlignRight : Text.AlignLeft
                leftPadding: segment[3] ?? 0
                font.family: segment[0] ?? Theme.font.text
                font.pixelSize: Theme.font.barText
                color: root.highlighted ? Theme.module.highlightText : root.color
                text: segment[1] ?? ""

                FontMetrics {
                    id: metrics
                    font: label.font
                    onFontChanged: {
                        label.measuredValues = null;
                        label.measure();
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
