import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Sealed records — the on-chain wing of the Museum of Civil Liberties.
// The collection STRUCTURE is public (exhibit + number, in the NFT name); the CONTENTS
// (title, source, note, link) are encrypted and revealed only by unsealing with your viewing key.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#0b0d12"

    Material.theme: Material.Dark
    Material.accent: "#b5303a"
    Material.primary: "#b5303a"
    Material.background: "#12151d"
    Material.foreground: "#e8dfc8"

    // ── Palette ───────────────────────────────────────────────────────────────
    readonly property color panel:  "#12151d"
    readonly property color border:  "#262a35"
    readonly property color ink:     "#e8dfc8"
    readonly property color inkDim:  "#9a917c"
    readonly property color wax:     "#b5303a"
    readonly property color ok:      "#1f7a52"
    readonly property color paper:   "#f3efe4"

    // ── State ─────────────────────────────────────────────────────────────────
    property bool   cliFound: false
    property string cliPath:  ""
    property var    grouped: []              // [{exhibit, items:[record,…]}]
    property string statusText: "Ready — Sync pulls your shielded state, then Discover finds your records."
    property int    statusKind: 0            // 0 idle · 1 ok · 2 error

    function parse(s) {
        try { var t = JSON.parse(s); if (typeof t === "string") { try { return JSON.parse(t) } catch(e) { return t } } return t }
        catch(e) { return { raw: s } }
    }
    function call(method, args) {
        if (typeof logos === "undefined" || !logos.callModule) return { raw: "bridge unavailable" }
        var r = parse(logos.callModule("sealed_keys", method, args || []))
        if (r && typeof r === "object" && r.value !== undefined && r.success !== undefined) return r.value
        return r
    }

    function refreshStatus() { var st = call("getStatus", []); cliFound = !!st.cliFound; cliPath = st.cliPath || "" }

    // Build exhibit-grouped, number-sorted structure from the flat records.
    // record.name is "<exhibit>||<nn>" (public); title etc. stay sealed until unseal.
    function rebuildGroups(records) {
        var order = ["I · Control of Money", "II · Surveillance State", "III · Censored World",
                     "IV · Failure of Voice", "V · Systems of Control"]
        var byEx = {}
        for (var i = 0; i < records.length; i++) {
            var nm = records[i].name || ""
            var parts = nm.split("||")
            var ex = parts.length > 1 ? parts[0] : "Uncategorised"
            var nn = parts.length > 1 ? parts[1] : ("" + (i + 1))
            var rec = { account: records[i].account, definitionId: records[i].definitionId,
                        metadataUri: records[i].metadataUri, exhibit: ex, nn: nn }
            if (!byEx[ex]) byEx[ex] = []
            byEx[ex].push(rec)
        }
        var out = []
        function pushEx(ex) { if (byEx[ex]) { byEx[ex].sort(function(a,b){return a.nn.localeCompare(b.nn)}); out.push({ exhibit: ex, items: byEx[ex] }); delete byEx[ex] } }
        for (var k = 0; k < order.length; k++) pushEx(order[k])
        for (var rest in byEx) pushEx(rest)
        grouped = out
    }

    function discover() {
        var r = call("listSealed", [])
        if (r && r.records) {
            rebuildGroups(r.records)
            var n = r.records.length
            statusText = n + " sealed record" + (n === 1 ? "" : "s") + " discovered · " + grouped.length + " exhibit" + (grouped.length === 1 ? "" : "s") + "."
            statusKind = 1
        } else { statusText = "Discover failed: " + ((r && (r.error || r.raw)) || "nothing found"); statusKind = 2 }
    }

    Component.onCompleted: { refreshStatus(); if (cliFound) discover() }

    // Shared clipboard sink.
    TextEdit { id: clip; visible: false }
    function copyText(t) { clip.text = t; clip.selectAll(); clip.copy() }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // Top bar: wallet pill (left) · Request NFT CTA (right)
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle {
                radius: 14; color: root.panel; border.width: 1
                border.color: root.cliFound ? root.ok : root.wax
                implicitHeight: pillRow.implicitHeight + 12; implicitWidth: pillRow.implicitWidth + 24
                RowLayout {
                    id: pillRow; anchors.centerIn: parent; spacing: 7
                    Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: root.cliFound ? root.ok : root.wax }
                    Text { text: root.cliFound ? "Wallet connected" : "Wallet not found"
                           color: root.ink; font.pixelSize: 12; font.family: "monospace" }
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Request NFT"; highlighted: true
                onClicked: { reqModal.reset(); reqModal.open() }
            }
        }

        // Centered header
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                   text: "MUSEUM OF CIVIL LIBERTIES"; color: root.wax
                   font.pixelSize: 30; font.bold: true; font.letterSpacing: 4 }
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                   text: "Sealed records · NFT collection on Logos testnet 0.2.1"; color: root.inkDim
                   font.family: "monospace"; font.pixelSize: 12; font.letterSpacing: 1 }
        }

        // Status chip + Sync / Discover
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; radius: 6
                color: root.statusKind === 1 ? "#10261c" : (root.statusKind === 2 ? "#2a1416" : root.panel)
                border.width: 1
                border.color: root.statusKind === 1 ? root.ok : (root.statusKind === 2 ? root.wax : root.border)
                implicitHeight: chipRow.implicitHeight + 16
                RowLayout {
                    id: chipRow; anchors.fill: parent; anchors.margins: 8; spacing: 9
                    Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 5
                        color: root.statusKind === 1 ? root.ok : (root.statusKind === 2 ? root.wax : root.inkDim) }
                    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.statusText; color: root.ink; font.pixelSize: 12 }
                }
            }
            Button { text: "Sync"; onClicked: {
                var r = root.call("syncPrivate", [])
                if (!r.ok) { root.statusText = "Sync failed: " + (r.error || r.raw || "?"); root.statusKind = 2; return }
                root.statusText = "Synced to tip."; root.statusKind = 1; root.discover() } }
            Button { text: "Discover"; onClicked: root.discover() }
        }

        // The collection — halls (exhibits) → numbered A4 cards
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            ColumnLayout {
                width: root.width - 40
                spacing: 26
                Repeater {
                    model: root.grouped
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 10
                        Text { text: modelData.exhibit; color: root.ink; font.pixelSize: 20
                               topPadding: 6; bottomPadding: 2 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.border }
                        Flow {
                            Layout.fillWidth: true; spacing: 22
                            Repeater {
                                model: modelData.items
                                delegate: SealedCard {
                                    required property var modelData
                                    account: modelData.account
                                    definitionId: modelData.definitionId
                                    metadataUri: modelData.metadataUri
                                    nn: modelData.nn
                                    exhibit: modelData.exhibit
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: root.grouped.length === 0
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; topPadding: 40
                    color: root.inkDim; wrapMode: Text.WordWrap
                    text: "No sealed records yet. Click Sync, then Discover — or Request NFT to get a receive-key for a curator to shield one to you."
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── One A4 card: paper image · caption below · reveal below that ─────────────
    component SealedCard: ColumnLayout {
        id: card
        property string account
        property string definitionId
        property string metadataUri
        property string nn
        property string exhibit
        property bool   unsealed: false
        property string url: ""
        property string note: ""
        property string title: ""
        property string meta: ""
        property string errText: ""
        property string copyMsg: ""
        width: 210; spacing: 0

        function seed() { var h = 2166136261; for (var i=0;i<definitionId.length;i++){ h ^= definitionId.charCodeAt(i); h = (h*16777619)>>>0 } return h }
        function idShort() { var s = definitionId || ""; return s.length > 8 ? s.substring(0,8) : s }

        // A4 paper (200 : 283 ≈ 1 : 1.414)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 1.414
            radius: 4; color: root.paper; border.color: "#cfc7b2"; border.width: 1; clip: true
            Canvas {
                id: art; anchors.fill: parent; anchors.margins: 1
                property bool rev: card.unsealed
                onRevChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.fillStyle = "#f3efe4"; ctx.fillRect(0,0,width,height)
                    var s = card.seed(); function rnd(){ s = (s*1103515245+12345)>>>0; return (s>>>8)/16777216 }
                    var X = width*0.11, right = width*0.89
                    if (!card.unsealed) {
                        var y = height*0.09, step = height*0.066
                        for (var i=0;i<13;i++){ if (rnd()>0.82){ y+=step; continue }
                            var w = Math.min((right-X)*(0.3+rnd()*0.7), right-X)
                            ctx.fillStyle = "#141210"; ctx.globalAlpha = 0.84+rnd()*0.14
                            ctx.fillRect(X, y, w, height*0.032); y += step }
                        ctx.globalAlpha = 1
                    } else {
                        // faded document lines
                        var yy = height*0.40, st2 = height*0.05
                        for (var j=0;j<9;j++){ ctx.fillStyle="#d7d2c2"; ctx.fillRect(X, yy, (right-X)*(0.5+rnd()*0.5), height*0.016); yy+=st2 }
                        // title (wrapped) + meta, drawn on the paper
                        ctx.fillStyle = "#1a1712"; ctx.font = "600 " + Math.round(width*0.075) + "px Spectral, serif"
                        var words = (card.title||"").split(" "), line = "", ty = height*0.16, lines = []
                        for (var wi=0; wi<words.length; wi++){ var t=(line+" "+words[wi]).trim(); if (t.length>18){ lines.push(line.trim()); line=words[wi] } else line=t }
                        if (line) lines.push(line.trim()); lines = lines.slice(0,3)
                        for (var li=0; li<lines.length; li++){ ctx.fillText(lines[li], X, ty + li*width*0.085) }
                        ctx.fillStyle = "#6f6a5c"; ctx.font = "italic " + Math.round(width*0.052) + "px Spectral, serif"
                        if (card.meta) ctx.fillText(card.meta, X, ty + lines.length*width*0.085 + width*0.04)
                    }
                }
            }
            // SEALED wax stamp
            Rectangle {
                visible: !card.unsealed; anchors.centerIn: parent; rotation: -8
                width: parent.width*0.7; height: parent.width*0.22; radius: 4
                color: "transparent"; border.color: root.wax; border.width: 2
                Text { anchors.centerIn: parent; text: "SEALED"; color: root.wax
                       font.pixelSize: Math.round(parent.width*0.16); font.letterSpacing: 5; font.bold: true }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (card.unsealed) return
                    var r = root.call("unseal", [card.account, card.metadataUri, card.definitionId])
                    if (r && r.ok && (r.url || r.title)) {
                        card.url = r.url||""; card.note = r.note||""; card.title = r.title||""; card.meta = r.meta||""
                        card.unsealed = true
                    } else { card.errText = (r && (r.error || r.raw)) || "unseal failed" }
                }
            }
        }

        // Caption below the image
        Text {
            Layout.fillWidth: true; Layout.topMargin: 9; horizontalAlignment: Text.AlignHCenter
            font.family: "monospace"; font.pixelSize: 11; color: root.inkDim; wrapMode: Text.WordWrap
            text: "Nº " + card.nn + " · " + card.idShort() + " · "
                  + (card.unsealed ? "UNSEALED" : "SEALED")
            textFormat: Text.RichText
        }
        Text {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            font.family: "monospace"; font.pixelSize: 10
            color: card.unsealed ? root.ok : root.inkDim
            text: card.unsealed ? "Owner: you (private)" : "Owner: unknown"
        }

        // Reveal block (below caption) — appears only when unsealed
        Rectangle {
            visible: card.unsealed; Layout.fillWidth: true; Layout.topMargin: 8
            radius: 5; color: "#14120c"; border.color: root.wax; border.width: 0
            implicitHeight: revCol.implicitHeight + 16
            ColumnLayout {
                id: revCol; anchors.fill: parent; anchors.margins: 9; spacing: 6
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: card.note
                       color: root.ink; font.pixelSize: 12 }
                Rectangle {
                    Layout.fillWidth: true; height: 30; radius: 4; color: "transparent"; border.color: root.border; border.width: 1
                    Text { anchors.centerIn: parent; width: parent.width-16; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                           text: card.copyMsg !== "" ? card.copyMsg : ("🔗 " + card.url.replace(/^https?:\/\//,""))
                           color: card.copyMsg !== "" ? root.ok : "#8fa6c8"; font.family: "monospace"; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.copyText(card.url); card.copyMsg = "Copied ✓"; copyReset.restart() } }
                }
            }
        }
        Timer { id: copyReset; interval: 1500; onTriggered: card.copyMsg = "" }
        Text { visible: card.errText !== ""; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
               text: card.errText; color: root.wax; font.pixelSize: 10; wrapMode: Text.WordWrap }
    }

    // ── Request NFT modal: get a receive-key for a curator to shield to ─────────
    Popup {
        id: reqModal
        anchors.centerIn: Overlay.overlay
        width: 460; modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        property string account: ""
        property string npk: ""
        property string vpk: ""
        property string mnemonic: ""
        property string status: ""
        property string copyMsg: ""
        function reset() { account=""; npk=""; vpk=""; mnemonic=""; status=""; copyMsg="" }

        background: Rectangle { color: root.panel; border.color: root.border; border.width: 1; radius: 10 }
        contentItem: ColumnLayout {
            spacing: 12
            Rectangle { Layout.fillWidth: true; Layout.margins: 0; color: "transparent"; implicitHeight: 1 }
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 18; spacing: 12
                Text { text: "REQUEST AN NFT"; color: root.wax; font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 3 }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 13
                       text: "Generate the receive-key a curator shields your sealed NFT to, then copy it to them. Your viewing secret never leaves this wallet." }

                // Step 1 — wallet
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "1 · Your wallet"; color: root.ink; font.pixelSize: 14 }
                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 12
                               text: reqModal.account ? ("Account: " + reqModal.account) : "Create a private account to hold your NFT." } }
                    Button { text: reqModal.account ? "New" : "Create wallet"
                        onClicked: {
                            var r = root.call("createPrivateAccount", [])
                            var m = (r.raw||"").match(/Private\/([1-9A-HJ-NP-Za-km-z]+)/); if (m) reqModal.account = m[1]
                            var mn = (r.raw||"").match(/([a-z]+ ){22,}[a-z]+/i); if (mn) reqModal.mnemonic = mn[0].trim()
                        } }
                }
                Rectangle {
                    visible: reqModal.mnemonic !== ""; Layout.fillWidth: true; radius: 6; color: "#14120c"; border.color: root.wax; border.width: 1
                    implicitHeight: mnT.implicitHeight + 16
                    Text { id: mnT; anchors.fill: parent; anchors.margins: 8; wrapMode: Text.WordWrap
                           text: "⚠ Back up: " + reqModal.mnemonic; color: root.ink; font.pixelSize: 11; font.family: "monospace" }
                }

                // Step 2 — generate receive-key
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "2 · Generate receive-key"; color: root.ink; font.pixelSize: 14 }
                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 12
                               text: reqModal.npk ? "Receive-key ready — copy it below." : "Produce the npk + vpk the curator shields to." } }
                    Button { text: reqModal.npk ? "Regenerate" : "Generate"
                        onClicked: { var r = root.call("generateReceiveKey", []); reqModal.npk = r.npk||""; reqModal.vpk = r.vpk||"" } }
                }
                Rectangle {
                    visible: reqModal.npk !== ""; Layout.fillWidth: true; radius: 6; color: "#0e1117"; border.color: root.border; border.width: 1
                    implicitHeight: keyCol.implicitHeight + 16
                    ColumnLayout { id: keyCol; anchors.fill: parent; anchors.margins: 9; spacing: 4
                        Text { text: "npk"; color: root.inkDim; font.pixelSize: 10 }
                        Text { Layout.fillWidth: true; text: reqModal.npk; color: root.ink; font.family: "monospace"; font.pixelSize: 10; wrapMode: Text.WrapAnywhere }
                        Text { text: "vpk"; color: root.inkDim; font.pixelSize: 10; topPadding: 3 }
                        Text { Layout.fillWidth: true; text: reqModal.vpk; color: root.ink; font.family: "monospace"; font.pixelSize: 9; wrapMode: Text.WrapAnywhere; maximumLineCount: 3; elide: Text.ElideRight }
                    }
                }

                // Step 3 — copy public key
                Button {
                    Layout.fillWidth: true; enabled: reqModal.npk !== "" && reqModal.vpk !== ""; highlighted: true
                    text: reqModal.copyMsg !== "" ? reqModal.copyMsg : "Copy public key"
                    onClicked: { root.copyText("npk " + reqModal.npk + "\nvpk " + reqModal.vpk); reqModal.copyMsg = "Copied ✓ — send it to the curator"; reqCopyReset.restart() }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 11
                       text: "Share it with the collection curator so they can shield your sealed NFT to you." }
                Timer { id: reqCopyReset; interval: 1800; onTriggered: reqModal.copyMsg = "" }

                Button { Layout.alignment: Qt.AlignRight; text: "Close"; flat: true; onClicked: reqModal.close() }
            }
        }
    }
}
