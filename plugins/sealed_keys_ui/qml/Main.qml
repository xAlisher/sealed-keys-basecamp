import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
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

    // Dark controls that match the Sealed palette (wax accent), instead of the default light style.
    Material.theme: Material.Dark
    Material.accent: "#b5303a"
    Material.primary: "#b5303a"
    Material.background: "#12151d"
    Material.foreground: "#e8dfc8"

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

    // Canonical callModule unwrap: outer parse, then a guarded inner parse so a plain-string
    // return (e.g. "ready") survives instead of throwing into the catch. (basecamp-skills:
    // callmoduleparse-canonical-form)
    function parse(s) {
        try {
            var tmp = JSON.parse(s)
            if (typeof tmp === "string") { try { return JSON.parse(tmp) } catch(e) { return tmp } }
            return tmp
        } catch(e) { return { raw: s } }
    }
    function call(method, args) {
        if (typeof logos === "undefined" || !logos.callModule) return { raw: "bridge unavailable" }
        var r = parse(logos.callModule("sealed_keys", method, args || []))
        console.warn("[sealed] " + method + " -> " + JSON.stringify(r))
        // The bridge may hand back the whole {success, value, error} envelope — unwrap to value.
        if (r && typeof r === "object" && r.value !== undefined && r.success !== undefined) return r.value
        return r
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
            Layout.fillWidth: true; spacing: 4
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                   text: "MUSEUM OF CIVIL LIBERTIES"; color: root.wax
                   font.pixelSize: 30; font.bold: true; font.letterSpacing: 4 }
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                   text: "Sealed records · NFT collection on Logos testnet 0.2.1"; color: root.inkDim
                   font.family: "monospace"; font.pixelSize: 12; font.letterSpacing: 1 }
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
        property string statusText: "Ready — click Sync to pull shielded state, then Discover."
        property int statusKind: 0   // 0 idle · 1 ok · 2 error

        // Discover the wallet's sealed records on-chain (0.1.2) and populate the gallery.
        function discover() {
            var r = root.call("listSealed", [])
            if (r && r.records) {
                records = r.records
                statusText = records.length + " sealed record" + (records.length === 1 ? "" : "s") + " discovered on-chain."
                statusKind = 1
            } else { statusText = "Discover failed: " + ((r && (r.error || r.raw)) || "nothing found"); statusKind = 2 }
        }
        Component.onCompleted: if (root.cliFound) discover()

        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { color: root.inkDim; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap
                   text: "Sync pulls shielded state to the tip; your sealed records are then discovered on-chain. Unseal opens one with your viewing key (which never leaves the wallet)." }
            Button { text: "Sync"; onClicked: {
                var r = root.call("syncPrivate", [])
                if (!r.ok) { gallery.statusText = "Sync failed: " + (r.error || r.raw || "?"); gallery.statusKind = 2; return }
                gallery.statusText = "Synced to tip."; gallery.statusKind = 1
                gallery.discover() } }
            Button { text: "Discover"; onClicked: gallery.discover() }
        }
        // Clear status chip.
        Rectangle {
            Layout.fillWidth: true; radius: 6
            color: gallery.statusKind === 1 ? "#10261c" : (gallery.statusKind === 2 ? "#2a1416" : "#12151d")
            border.color: gallery.statusKind === 1 ? root.ok : (gallery.statusKind === 2 ? root.wax : root.border)
            border.width: 1; implicitHeight: chipRow.implicitHeight + 16
            RowLayout {
                id: chipRow; anchors.fill: parent; anchors.margins: 8; spacing: 9
                Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 5
                    color: gallery.statusKind === 1 ? root.ok : (gallery.statusKind === 2 ? root.wax : root.inkDim) }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: gallery.statusText
                       color: root.ink; font.pixelSize: 12 }
            }
        }

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
        property string title: ""
        property string meta: ""
        property string exhibit: ""
        property string errText: ""
        property string copyMsg: ""
        width: 300
        implicitHeight: cardCol.implicitHeight
        radius: 6; color: root.paper; border.color: root.border; border.width: 1; clip: true

        // Deterministic redaction art from the definition id (stable per record).
        function seed() { var h = 2166136261; for (var i=0;i<definitionId.length;i++){ h ^= definitionId.charCodeAt(i); h = (h*16777619)>>>0 } return h }
        // Clipboard without a JS API.
        TextEdit { id: clip; visible: false }
        function copyToClipboard(t) { clip.text = t; clip.selectAll(); clip.copy(); card.copyMsg = "Copied ✓"; copyReset.restart() }
        Timer { id: copyReset; interval: 1400; onTriggered: card.copyMsg = "" }

        ColumnLayout {
            id: cardCol; width: parent.width; spacing: 0

            // ── IMAGE (top) — redaction art; SEALED stamp until revealed ──────────
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 190
                Canvas {
                    id: art; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        ctx.fillStyle = "#f3efe4"; ctx.fillRect(0,0,width,height)
                        var s = card.seed(); function rnd(){ s = (s*1103515245+12345)>>>0; return (s>>>8)/16777216 }
                        var y = 18, x0 = 18, w = width-36
                        for (var i=0;i<16;i++){
                            var lw = w*(0.35+rnd()*0.6)
                            if (card.unsealed) { ctx.fillStyle = "#d7d2c2"; ctx.fillRect(x0, y, lw, 6); y += 11 }
                            else { ctx.fillStyle = "#111318"; ctx.fillRect(x0, y, lw, 12); y += 17 }
                            if (y > height-14) break
                        }
                    }
                }
                // SEALED wax stamp
                Rectangle {
                    visible: !card.unsealed; anchors.centerIn: parent
                    width: 150; height: 44; radius: 4; color: "transparent"; border.color: root.wax; border.width: 2; rotation: -8
                    Text { anchors.centerIn: parent; text: "SEALED"; color: root.wax; font.pixelSize: 22; font.letterSpacing: 6; font.bold: true }
                }
            }

            // ── DETAILS (below the image) ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 5

                // Sealed: no title (it is encrypted). Generic placeholder + Unseal.
                Text { visible: !card.unsealed; text: "◼ SEALED RECORD"; color: "#8b8574"
                       font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 2 }
                Text { visible: !card.unsealed; Layout.fillWidth: true; wrapMode: Text.WordWrap
                       text: "Title, source and note are encrypted. Unseal with your viewing key to reveal them."
                       color: "#6f6a5c"; font.pixelSize: 11 }

                // Unsealed: exhibit → title → issuer·year → note → link.
                Text { visible: card.unsealed && card.exhibit !== ""; text: card.exhibit
                       color: root.wax; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
                Text { visible: card.unsealed; Layout.fillWidth: true; wrapMode: Text.WordWrap
                       text: card.title || "(untitled)"; color: "#1b1e24"; font.pixelSize: 15; font.bold: true }
                Text { visible: card.unsealed && card.meta !== ""; text: card.meta
                       color: "#6f6a5c"; font.pixelSize: 11; font.italic: true }
                Text { visible: card.unsealed; Layout.fillWidth: true; wrapMode: Text.WordWrap
                       text: card.note; color: "#33383f"; font.pixelSize: 13 }
                Text { visible: card.unsealed; Layout.fillWidth: true; text: card.url
                       color: "#3a4a6a"; font.family: "monospace"; font.pixelSize: 10; elide: Text.ElideRight }

                // Action button
                Rectangle {
                    Layout.topMargin: 6; Layout.fillWidth: true; height: 34; radius: 4
                    color: card.unsealed ? "transparent" : root.redact
                    border.color: card.unsealed ? root.border : "transparent"; border.width: 1
                    Text { anchors.centerIn: parent
                           text: card.unsealed ? (card.copyMsg !== "" ? card.copyMsg : "Copy link") : "Unseal"
                           color: card.unsealed ? "#1b1e24" : root.paper; font.pixelSize: 13; font.letterSpacing: 1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.unsealed) { card.copyToClipboard(card.url); return }
                            var r = root.call("unseal", [card.account, card.metadataUri, card.definitionId])
                            if (r && r.ok && (r.url || r.title)) {
                                card.url = r.url || ""; card.note = r.note || ""
                                card.title = r.title || ""; card.meta = r.meta || ""; card.exhibit = r.exhibit || ""
                                card.unsealed = true; art.requestPaint()
                            } else { card.errText = (r && (r.error || r.raw)) || "unseal failed" }
                        } }
                }
                Text { visible: card.errText !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap
                       text: card.errText; color: root.wax; font.pixelSize: 10 }
            }
        }
    }

    // ── Key collection (0.1.0 flow, unchanged) ─────────────────────────────────
    component KeyCollectionView: ColumnLayout {
        spacing: 14
        Text { Layout.maximumWidth: 640; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 14
               text: "Generate the receive-key a curator shields your NFT to, then copy it and share it with them. Your viewing secret never leaves this wallet." }

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
            title: "2 · Generate key to receive your NFT"
            body: root.npk ? "Receive-key ready — see it below." : "Produce the receive-key the curator shields your NFT to."
            actionText: root.npk ? "Regenerate" : "Generate"
            onAction: { var r = root.call("generateReceiveKey", []); root.npk = r.npk || ""; root.vpk = r.vpk || "" }
        }
        // The receive-key, unfolded (npk + vpk) once generated.
        Rectangle {
            visible: root.npk !== ""; Layout.fillWidth: true; radius: 6
            color: "#0e1117"; border.color: root.border; border.width: 1
            implicitHeight: keyCol.implicitHeight + 18
            ColumnLayout { id: keyCol; anchors.fill: parent; anchors.margins: 10; spacing: 6
                Text { text: "npk (nullifier public key)"; color: root.inkDim; font.pixelSize: 10; font.letterSpacing: 1 }
                Text { text: root.npk; color: root.ink; font.family: "monospace"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                Text { text: "vpk (viewing public key)"; color: root.inkDim; font.pixelSize: 10; font.letterSpacing: 1; topPadding: 4 }
                Text { text: root.vpk; color: root.ink; font.family: "monospace"; font.pixelSize: 10; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; maximumLineCount: 4; elide: Text.ElideRight }
            }
        }
        StepCard {
            title: "3 · Copy public key"
            body: root.status !== "" ? root.status : "Share it with the collection curator so they can shield your sealed NFT to you."
            actionText: "Copy public key"
            enabled: root.npk !== "" && root.vpk !== ""
            onAction: {
                keyClip.text = "npk " + root.npk + "\nvpk " + root.vpk
                keyClip.selectAll(); keyClip.copy()
                root.status = "Copied ✓ — paste it to the curator."
            }
        }
        TextEdit { id: keyClip; visible: false }
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
                Text { text: body; color: root.inkDim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Button { text: actionText; enabled: parent.parent.enabled; onClicked: parent.parent.action() }
        }
    }
}
