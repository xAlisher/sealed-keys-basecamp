import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Sealed — 0.1.1: receive-key collection + the sealed gallery (view & unseal).
// Tab 1 "Get key": create/open wallet -> generate receive-key (npk+vpk) -> export .keys.
// Tab 2 "My sealed": sync -> a record renders as redaction art (SEALED) -> Unseal reveals
// the curator's note + a copy-able link (UNSEALED). Unsealing uses your own viewing key,
// which never leaves the wallet.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#0b0d12"

    // ── Palette (matches the Sealed collection) ──────────────────────────────
    readonly property color panel:   "#12151d"
    readonly property color border:   "#262a35"
    readonly property color ink:      "#e8dfc8"
    readonly property color inkDim:   "#9a917c"
    readonly property color wax:      "#b5303a"
    readonly property color ok:       "#1f7a52"
    readonly property color paper:    "#f3efe4"
    readonly property color redact:   "#111318"

    // ── State ────────────────────────────────────────────────────────────────
    property bool   cliFound: false
    property string cliPath:  ""
    property string accountId: ""
    property string mnemonic:  ""
    property string npk: ""
    property string vpk: ""
    property string status: ""

    // logos.callModule returns a double-JSON-encoded string; unwrap to an object.
    function parse(s) { try { var v = JSON.parse(s); if (typeof v === "string") v = JSON.parse(v); return v } catch(e) { return { raw: s } } }
    function call(method, args) {
        if (typeof logos === "undefined" || !logos.callModule) return { raw: "bridge unavailable" }
        return parse(logos.callModule("sealed_keys", method, args || []))
    }

    function refreshStatus() {
        var st = call("getStatus", [])
        cliFound = !!st.cliFound; cliPath = st.cliPath || ""
    }
    Component.onCompleted: refreshStatus()

    // ── Header + tabs ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        ColumnLayout {
            spacing: 4
            Text { text: "SEALED · MUSEUM OF CIVIL LIBERTIES"; color: root.wax
                   font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 3 }
            Text { text: "Your sealed records"; color: root.ink; font.pixelSize: 26 }
        }

        // CLI status
        Rectangle {
            Layout.fillWidth: true; radius: 8; color: root.panel; border.color: root.border; border.width: 1
            implicitHeight: statusRow.implicitHeight + 20
            RowLayout {
                id: statusRow; anchors.fill: parent; anchors.margins: 10; spacing: 10
                Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 5; color: root.cliFound ? root.ok : root.wax }
                Text { color: root.inkDim; font.family: "monospace"; font.pixelSize: 12
                       text: root.cliFound ? ("wallet CLI: " + root.cliPath) : "wallet CLI not found — set its path" }
                Item { Layout.fillWidth: true }
                TextField { id: cliField; placeholderText: "path to wallet binary"; Layout.preferredWidth: 200
                            color: root.ink; font.pixelSize: 12 }
                Button { text: "Set"; onClicked: { root.call("setCliPath",[cliField.text]); root.refreshStatus() } }
            }
        }

        TabBar {
            id: tabs; Layout.fillWidth: true
            TabButton { text: "My sealed" }
            TabButton { text: "Get key" }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            // ── TAB 1 · GALLERY ────────────────────────────────────────────────
            GalleryView { }

            // ── TAB 2 · KEY COLLECTION ─────────────────────────────────────────
            KeyCollectionView { }
        }
    }

    // ── Sealed gallery ──────────────────────────────────────────────────────────
    component GalleryView: ColumnLayout {
        id: gallery
        spacing: 12
        property var records: []   // [{account, definitionId, name, metadataUri}]
        property bool showAdd: false

        // Discover the wallet's sealed records on-chain (0.1.2) and populate the gallery.
        function discover() {
            var r = root.call("listSealed", [])
            if (r && r.records) { records = r.records; syncMsg.text = "Found " + records.length + " sealed record(s)." }
            else { syncMsg.text = "Discover: " + ((r && (r.error || r.raw)) || "nothing found") }
        }
        Component.onCompleted: if (root.cliFound) discover()

        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { color: root.inkDim; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap
                   text: "Sync pulls shielded state to the tip; your sealed records are then discovered on-chain. Unseal opens one with your viewing key (which never leaves the wallet)." }
            Button { text: "Sync"; onClicked: {
                var r = root.call("syncPrivate", [])
                if (!r.ok) { syncMsg.text = "Sync: " + (r.error || r.raw || "failed"); return }
                gallery.discover() } }
            Button { text: "Discover"; onClicked: gallery.discover() }
        }
        Text { id: syncMsg; color: root.inkDim; font.family: "monospace"; font.pixelSize: 11; text: "" }

        // Manual add — optional fallback (a curator can paste a record before it's synced).
        RowLayout {
            Layout.fillWidth: true
            Text { text: gallery.showAdd ? "▾ Add a record manually" : "▸ Add a record manually"
                   color: root.inkDim; font.pixelSize: 12
                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: gallery.showAdd = !gallery.showAdd } }
            Item { Layout.fillWidth: true }
        }
        Rectangle {
            visible: gallery.showAdd
            Layout.fillWidth: true; radius: 8; color: root.panel; border.color: root.border; border.width: 1
            implicitHeight: addCol.implicitHeight + 20
            ColumnLayout {
                id: addCol; anchors.fill: parent; anchors.margins: 10; spacing: 6
                TextField { id: fAcc;  Layout.fillWidth: true; color: root.ink; font.pixelSize: 12; placeholderText: "your account id (Private/… or Public/…)" }
                TextField { id: fDef;  Layout.fillWidth: true; color: root.ink; font.pixelSize: 12; placeholderText: "NFT definition id (base58)" }
                TextField { id: fUri;  Layout.fillWidth: true; color: root.ink; font.pixelSize: 12; placeholderText: "metadata.uri (sealed:v1:…)" }
                Button { text: "Add to gallery"; enabled: fDef.text !== "" && fUri.text !== ""
                    onClicked: {
                        var arr = gallery.records.slice()
                        arr.push({ account: fAcc.text, definitionId: fDef.text, name: "", metadataUri: fUri.text })
                        gallery.records = arr; fAcc.text=""; fDef.text=""; fUri.text=""
                    } }
            }
        }

        // The cards.
        Flow {
            Layout.fillWidth: true; spacing: 16
            Repeater {
                model: gallery.records
                delegate: SealedCard {
                    account: modelData.account
                    definitionId: modelData.definitionId
                    recordName: modelData.name || ""
                    metadataUri: modelData.metadataUri
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    // ── One sealed card: redaction art -> Unseal -> note + copy link ────────────
    component SealedCard: Rectangle {
        id: card
        property string account
        property string definitionId
        property string recordName
        property string metadataUri
        property bool   unsealed: false
        property string url: ""
        property string note: ""
        property string errText: ""
        property string copyMsg: ""
        width: 260; height: 380; radius: 6
        color: root.paper; border.color: root.border; border.width: 1

        // Deterministic redaction art from the definition id (stable per record).
        function seed() { var h = 2166136261; for (var i=0;i<definitionId.length;i++){ h ^= definitionId.charCodeAt(i); h = (h*16777619)>>>0 } return h }

        Canvas {
            id: art; anchors.fill: parent; anchors.margins: 1
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                ctx.fillStyle = "#f3efe4"; ctx.fillRect(0,0,width,height)
                // faux "document" lines, then redaction bars over most of them
                var s = card.seed(); function rnd(){ s = (s*1103515245+12345)>>>0; return (s>>>8)/16777216 }
                var y = 26, x0 = 20, w = width-40
                ctx.fillStyle = card.unsealed ? "#c9c3b2" : "#111318"
                for (var i=0;i<18;i++){
                    var lw = w*(0.35+rnd()*0.6)
                    var barH = 12
                    if (card.unsealed) { ctx.fillStyle = "#cfc9b8"; ctx.fillRect(x0, y, lw, 6) }
                    else { ctx.fillStyle = "#111318"; ctx.fillRect(x0, y, lw, barH) }
                    y += card.unsealed ? 12 : 18
                    if (y > height-30) break
                }
            }
        }
        // Record name (top strip)
        Text {
            visible: card.recordName !== "" && !card.unsealed
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 10
            text: card.recordName; color: "#20242c"; font.pixelSize: 12; font.bold: true
            elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        }

        // "SEALED" wax stamp, hidden once unsealed
        Rectangle {
            visible: !card.unsealed
            anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
            width: 150; height: 44; radius: 4; color: "transparent"; border.color: root.wax; border.width: 2; rotation: -8
            Text { anchors.centerIn: parent; text: "SEALED"; color: root.wax; font.pixelSize: 22; font.letterSpacing: 6; font.bold: true }
        }
        // UNSEALED overlay: note + copy link
        Rectangle {
            visible: card.unsealed
            anchors.fill: parent; anchors.margins: 14; color: "#00000000"
            ColumnLayout {
                anchors.fill: parent; spacing: 8
                Text { text: "UNSEALED"; color: root.ok; font.pixelSize: 12; font.letterSpacing: 4; font.bold: true }
                Text { text: card.note; color: "#20242c"; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true; Layout.fillHeight: true }
                Text { text: card.url; color: "#3a4a6a"; font.family: "monospace"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                RowLayout {
                    Button { text: card.copyMsg !== "" ? card.copyMsg : "Copy link"
                             onClicked: { card.copyToClipboard(card.url) } }
                    Item { Layout.fillWidth: true }
                }
            }
        }
        // hidden helper to copy without a JS clipboard API
        TextEdit { id: clip; visible: false }
        function copyToClipboard(t) { clip.text = t; clip.selectAll(); clip.copy(); card.copyMsg = "Copied ✓";
                                      copyReset.restart() }
        Timer { id: copyReset; interval: 1400; onTriggered: card.copyMsg = "" }

        // Unseal button (below the art)
        Rectangle {
            visible: !card.unsealed
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 10
            height: 34; radius: 4; color: root.redact
            Text { anchors.centerIn: parent; text: "Unseal"; color: root.paper; font.pixelSize: 14; font.letterSpacing: 2 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var r = root.call("unseal", [card.account, card.metadataUri, card.definitionId])
                    if (r && r.ok && r.url) { card.url = r.url; card.note = r.note || ""; card.unsealed = true; art.requestPaint() }
                    else { card.errText = (r && (r.error || r.raw)) || "unseal failed" }
                } }
        }
        Text { visible: card.errText !== ""; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
               anchors.bottomMargin: 48; width: parent.width-20; horizontalAlignment: Text.AlignHCenter
               text: card.errText; color: root.wax; font.pixelSize: 10; wrapMode: Text.WordWrap }
    }

    // ── Key collection (0.1.0 flow, unchanged) ─────────────────────────────────
    component KeyCollectionView: ColumnLayout {
        spacing: 14
        Text { Layout.maximumWidth: 640; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 14
               text: "Generate the key a curator will shield your sealed record to, then export it and send it back. Your viewing secret never leaves this wallet." }

        StepCard {
            title: "1 · Your wallet"
            body: root.accountId ? ("Account: " + root.accountId) : "Create a private account to hold your keys."
            actionText: root.accountId ? "New account" : "Create wallet"
            onAction: {
                var r = root.call("createPrivateAccount", [])
                var m = (r.raw || "").match(/Private\/([1-9A-HJ-NP-Za-km-z]+)/)
                if (m) root.accountId = m[1]
                var mn = (r.raw || "").match(/([a-z]+ ){22,}[a-z]+/i)
                if (mn) root.mnemonic = mn[0].trim()
            }
        }
        Rectangle {
            visible: root.mnemonic !== ""; Layout.fillWidth: true; radius: 6
            color: "#14120c"; border.color: root.wax; border.width: 1
            implicitHeight: mnCol.implicitHeight + 18
            ColumnLayout { id: mnCol; anchors.fill: parent; anchors.margins: 10; spacing: 4
                Text { text: "⚠ BACK UP THIS MNEMONIC — it is shown once and cannot be recovered."; color: root.wax; font.pixelSize: 11; font.family: "monospace" }
                Text { text: root.mnemonic; color: root.ink; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }
        StepCard {
            title: "2 · Generate receive-key"
            body: root.npk ? ("npk " + root.npk.substring(0,20) + "…  ·  vpk " + root.vpk.substring(0,16) + "…") : "Produce the npk + vpk the curator shields to."
            actionText: "Generate"
            onAction: { var r = root.call("generateReceiveKey", []); root.npk = r.npk || ""; root.vpk = r.vpk || "" }
        }
        StepCard {
            title: "3 · Export & send"
            body: root.status !== "" ? root.status : "Save a .keys file and send it to the curator (out-of-band)."
            actionText: "Export .keys"
            enabled: root.npk !== "" && root.vpk !== ""
            onAction: {
                var r = root.call("exportReceiveKeyFile", [root.npk, root.vpk, "sealed-receive.keys"])
                root.status = r.ok ? ("Saved " + r.path + " — send it to the curator.") : (r.error || r.raw || "export failed")
            }
        }
        Item { Layout.fillHeight: true }
    }

    // Reusable step card
    component StepCard: Rectangle {
        property string title; property string body; property string actionText
        property bool enabled: true
        signal action()
        Layout.fillWidth: true; radius: 8; color: root.panel; border.color: root.border; border.width: 1
        implicitHeight: row.implicitHeight + 22
        RowLayout {
            id: row; anchors.fill: parent; anchors.margins: 11; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; spacing: 3
                Text { text: title; color: root.ink; font.pixelSize: 15 }
                Text { text: body; color: root.inkDim; font.pixelSize: 12.5; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Button { text: actionText; enabled: parent.parent.enabled; onClicked: parent.parent.action() }
        }
    }
}
