import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
    id: root
    moduleName: "clevo.rgb"
    ipcTarget: "clevo.rgb"
    property var device: null
    property string message: "Reading keyboard…"
    property int level: 0
    property var channels: [0, 0, 0]
    property real pickerHue: 0
    property bool showRgb: false
    readonly property color selectedColor: Qt.rgba(
        channels[0] / channelMaximum(0), channels[1] / channelMaximum(1),
        channels[2] / channelMaximum(2), 1)
    readonly property var presets: [
        {name: "White", color: "#ffffff"}, {name: "Red", color: "#ff0000"},
        {name: "Orange", color: "#ff8000"}, {name: "Yellow", color: "#ffff00"},
        {name: "Green", color: "#00ff00"}, {name: "Cyan", color: "#00ffff"},
        {name: "Blue", color: "#0000ff"}, {name: "Purple", color: "#a040ff"}
    ]
    function channelMaximum(index) { return device ? device.limits[names[index]] : 255 }
    function chooseColor(color, immediate) {
        if (!ready) return
        channels = [Math.round(color.r * channelMaximum(0)),
                    Math.round(color.g * channelMaximum(1)),
                    Math.round(color.b * channelMaximum(2))]
        pendingColor = ["set", String(level)].concat(channels.map(String))
        if (immediate) {
            colorDelay.stop()
            flushColor()
        } else if (!colorDelay.running) {
            colorDelay.start()
        }
    }
    property var pendingColor: null
    function flushColor() {
        if (!pendingColor || worker.running) return
        var args = pendingColor
        pendingColor = null
        run(args)
    }
    Timer {
        id: colorDelay
        interval: 80
        onTriggered: root.flushColor()
    }
    onSelectedColorChanged: {
        if (selectedColor.hsvSaturation > 0 && selectedColor.hsvValue > 0)
            pickerHue = selectedColor.hsvHue
    }
    readonly property var names: ["red", "green", "blue"]
    readonly property bool ready: device !== null && device.writable && (!worker.running || worker.writing)
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("led.py").toString().replace(/^file:\/\//, ""))
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function run(args) {
        if (worker.running) return
        worker.writing = args[0] === "set"
        worker.command = ["python3", helper].concat(args)
        worker.running = true
    }
    function refresh() { if (!pendingColor) run(["state"]) }
    Component.onCompleted: refresh()
    onOpenedChanged: if (opened) refresh()

    Process {
        id: worker
        property bool received: false
        property bool writing: false
        onStarted: received = false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                worker.received = true
                try {
                    var result = JSON.parse(text)
                    if (!result.ok) throw new Error(result.error)
                    root.device = result
                    if (!root.pendingColor) {
                        root.level = result.brightness
                        root.channels = root.names.map(function(name) { return result.rgb[name] })
                    }
                    root.message = result.writable ? "Ready" : "Write access required — see README setup."
                } catch (error) {
                    root.pendingColor = null
                    colorDelay.stop()
                    root.device = null
                    root.message = String(error)
                }
            }
        }
        onExited: function(code, status) {
            if (!received) {
                root.pendingColor = null
                colorDelay.stop()
                root.device = null
                root.message = "Keyboard helper could not run (exit " + code + ")."
            }
            Qt.callLater(function() {
                if (root.pendingColor && !colorDelay.running) root.flushColor()
            })
        }
    }
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰌌"
        onPressed: root.toggle()
    }
    component Label: Text {
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Commons.Color.popups.text
        textFormat: Text.PlainText
    }

    component SliderCard: BorderSurface {
        id: card
        property string label: ""
        property string description: ""
        property real value: 0
        property real maximum: 255
        signal adjusted(real value)
        radius: Style.cornerRadius
        color: Style.controlFill(false, false, Commons.Color.popups.text, Commons.Color.accent)
        borderSpec: Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
        implicitHeight: cardContent.implicitHeight + Style.space(24)
        Column {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(4)
            Item {
                width: parent.width
                height: title.implicitHeight
                Label {
                    id: title
                    text: card.label
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }
                Label {
                    anchors.right: parent.right
                    text: Math.round(card.value)
                    opacity: 0.65
                }
            }
            Label {
                width: parent.width
                visible: card.description !== ""
                text: card.description
                font.pixelSize: Style.font.caption
                opacity: 0.65
                wrapMode: Text.Wrap
            }
            PanelSlider {
                width: parent.width
                bar: root.bar
                minimum: 0
                maximum: card.maximum
                step: 1
                integer: true
                value: card.value
                enabled: root.ready
                onMoved: function(v) { card.adjusted(Math.round(v)) }
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: scroll
        contentWidth: fittedContentWidth(Style.space(380))
        contentHeight: fittedContentHeight(content.implicitHeight, Style.space(680))
        Flickable {
            id: scroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            focus: true
            Keys.onEscapePressed: root.close()
            Column {
                id: content
                width: parent.width
                spacing: Style.space(10)
                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Label {
                        text: "󰌌"
                        font.pixelSize: Style.font.iconLarge
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        Label {
                            text: "Keyboard RGB"
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }
                        Label {
                            text: "Set the brightness and color of your keyboard"
                            opacity: 0.65
                        }
                    }
                }
                PanelSeparator { foreground: Commons.Color.popups.text }
                Label {
                    width: parent.width
                    text: root.message === "Ready" ? "Ready to customize" : root.message
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    opacity: 0.65
                    wrapMode: Text.Wrap
                }
                Label {
                    width: parent.width
                    text: "Colors apply instantly; sliders use Apply."
                    wrapMode: Text.Wrap
                }
                Label {
                    text: "Brightness"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    opacity: 0.65
                }
                SliderCard {
                    width: parent.width
                    label: "Keyboard backlight"
                    description: root.level === 0 ? "Off — your selected color is preserved" : "Set to zero to turn the backlight off"
                    value: root.level
                    maximum: root.device ? root.device.maximum : 255
                    onAdjusted: function(v) { root.level = v }
                }
                Label {
                    text: "Color"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    opacity: 0.65
                }
                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle {
                        width: Style.space(24)
                        height: width
                        radius: Style.space(4)
                        color: root.selectedColor
                        border.color: Commons.Color.popups.text
                        border.width: 1
                    }
                    Label {
                        text: String(root.selectedColor).toUpperCase()
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Rectangle {
                    id: colorField
                    width: parent.width
                    height: Style.space(100)
                    color: Qt.hsva(root.pickerHue, 1, 1, 1)
                    enabled: root.ready
                    opacity: enabled ? 1 : 0.5
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "white" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: "black" }
                        }
                    }
                    Rectangle {
                        width: Style.space(12)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: root.selectedColor.hsvValue > 0.6 ? "black" : "white"
                        border.width: 2
                        x: Math.max(0, Math.min(parent.width - width,
                            root.selectedColor.hsvSaturation * parent.width - width / 2))
                        y: Math.max(0, Math.min(parent.height - height,
                            (1 - root.selectedColor.hsvValue) * parent.height - height / 2))
                    }
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        function pick(mouse) {
                            root.chooseColor(Qt.hsva(root.pickerHue,
                                Math.max(0, Math.min(1, mouse.x / width)),
                                1 - Math.max(0, Math.min(1, mouse.y / height)), 1))
                        }
                        onPressed: function(mouse) { pick(mouse) }
                        onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
                    }
                }
                Label { text: "Hue"; opacity: 0.65; font.pixelSize: Style.font.caption }
                PanelSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 0
                    maximum: 359
                    step: 1
                    value: root.pickerHue * 359
                    enabled: root.ready
                    onMoved: function(v) {
                        root.pickerHue = v / 359
                        root.chooseColor(Qt.hsva(root.pickerHue,
                            root.selectedColor.hsvSaturation, root.selectedColor.hsvValue, 1))
                    }
                }
                Grid {
                    width: parent.width
                    columns: 4
                    spacing: Style.space(6)
                    Repeater {
                        model: root.presets
                        Rectangle {
                            id: swatch
                            required property var modelData
                            readonly property color presetColor: modelData.color
                            width: (content.width - Style.space(18)) / 4
                            height: Style.space(48)
                            radius: Style.cornerRadius
                            color: Style.controlFill(activeFocus, mouse.containsMouse,
                                Commons.Color.popups.text, Commons.Color.accent)
                            border.color: activeFocus ? Commons.Color.accent : Qt.rgba(Commons.Color.popups.text.r, Commons.Color.popups.text.g, Commons.Color.popups.text.b, 0.25)
                            border.width: 1
                            enabled: root.ready
                            activeFocusOnTab: true
                            Accessible.name: modelData.name
                            Accessible.role: Accessible.Button
                            function select() { root.chooseColor(presetColor, true) }
                            Keys.onReturnPressed: select()
                            Keys.onSpacePressed: select()
                            Column {
                                anchors.centerIn: parent
                                spacing: Style.space(4)
                                Rectangle {
                                    width: Style.space(24)
                                    height: Style.space(10)
                                    radius: Style.space(3)
                                    color: swatch.presetColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label { text: swatch.modelData.name; font.pixelSize: Style.font.caption }
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: swatch.select()
                            }
                        }
                    }
                }
                Button {
                    text: root.showRgb ? "Hide RGB sliders" : "Fine-tune RGB"
                    focusable: true
                    onClicked: root.showRgb = !root.showRgb
                }
                Repeater {
                    model: root.showRgb ? root.names : []
                    SliderCard {
                        required property string modelData
                        required property int index
                        width: content.width
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        value: root.channels[index]
                        maximum: root.device ? root.device.limits[modelData] : 255
                        onAdjusted: function(v) {
                            var copy = root.channels.slice()
                            copy[index] = v
                            root.channels = copy
                        }
                    }
                }
                Row {
                    spacing: Style.space(8)
                    Button {
                        text: "Apply"
                        bordered: true
                        focusable: true
                        enabled: root.ready && !worker.running && !root.pendingColor
                        onClicked: root.run(["set", String(root.level)].concat(root.channels.map(String)))
                    }
                    Button {
                        text: "Refresh"
                        bordered: true
                        focusable: true
                        enabled: !worker.running
                        onClicked: root.refresh()
                    }
                }
            }
        }
    }
}
