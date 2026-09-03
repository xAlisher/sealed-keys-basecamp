import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Sealed — 0.1.0 receive-key collection.
// Flow: (1) create/open wallet -> (2) generate receive-key (npk+vpk) -> (3) export .keys
// to send to the curator, who shields an NFT to it. No NFT display/unseal yet (that is 0.1.1).
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

    function refreshStatus() {
        if (typeof logos === "undefined" || !logos.callModule) { status = "Basecamp bridge unavailable"; return }
        var st = parse(logos.callModule("sealed_keys", "getStatus", []))
        cliFound = !!st.cliFound; cliPath = st.cliPath || ""
    }

    Component.onCompleted: refreshStatus()

    // ── Layout ───────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        // Header
        ColumnLayout {
            spacing: 4
            Text { text: "SEALED · MUSEUM OF CIVIL LIBERTIES"; color: root.wax
                   font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 3 }
            Text { text: "Get your receive-key"; color: root.ink; font.pixelSize: 26 }
            Text { Layout.maximumWidth: 640; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 14
                   text: "Generate the key a curator will shield your sealed record to, then export it and send it back. Your viewing secret never leaves this wallet." }
        }

        // CLI status / settings
        Rectangle {
            Layout.fillWidth: true; radius: 8; color: root.panel; border.color: root.border; border.width: 1
            implicitHeight: statusRow.implicitHeight + 20
            RowLayout {
                id: statusRow; anchors.fill: parent; anchors.margins: 10; spacing: 10
                Rectangle { width: 9; height: 9; radius: 5; color: root.cliFound ? root.ok : root.wax }
                Text { color: root.inkDim; font.family: "monospace"; font.pixelSize: 12
                       text: root.cliFound ? ("wallet CLI: " + root.cliPath) : "wallet CLI not found — set its path" }
                Item { Layout.fillWidth: true }
                TextField { id: cliField; placeholderText: "path to wallet binary"; Layout.preferredWidth: 220
                            color: root.ink; font.pixelSize: 12 }
                Button { text: "Set"; onClicked: { logos.callModule("sealed_keys","setCliPath",[cliField.text]); root.refreshStatus() } }
            }
        }

        // Step 1 — wallet
        StepCard {
            title: "1 · Your wallet"
            body: root.accountId ? ("Account: " + root.accountId) : "Create a private account to hold your keys."
            actionText: root.accountId ? "New account" : "Create wallet"
            onAction: {
                var r = root.parse(logos.callModule("sealed_keys","createPrivateAccount",[]))
                var m = (r.raw || "").match(/Private\/([1-9A-HJ-NP-Za-km-z]+)/)
                if (m) root.accountId = m[1]
                var mn = (r.raw || "").match(/mnemonic[:\s]+([a-z ]{20,})/i)
                if (mn) root.mnemonic = mn[1].trim()
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

        // Step 2 — receive-key
        StepCard {
            title: "2 · Generate receive-key"
            body: root.npk ? ("npk " + root.npk.substring(0,20) + "…  ·  vpk " + root.vpk.substring(0,16) + "…") : "Produce the npk + vpk the curator shields to."
            actionText: "Generate"
            enabled: root.accountId !== "" || true
            onAction: {
                var r = root.parse(logos.callModule("sealed_keys","generateReceiveKey",[]))
                root.npk = r.npk || ""; root.vpk = r.vpk || ""
            }
        }

        // Step 3 — export
        StepCard {
            title: "3 · Export & send"
            body: root.status !== "" ? root.status : "Save a .keys file and send it to the curator (out-of-band)."
            actionText: "Export .keys"
            enabled: root.npk !== "" && root.vpk !== ""
            onAction: {
                var path = "sealed-receive.keys"
                var r = root.parse(logos.callModule("sealed_keys","exportReceiveKeyFile",[root.npk, root.vpk, path]))
                root.status = r.ok ? ("Saved " + r.path + " — send it to the curator.") : (r.raw || "export failed")
            }
        }

        Item { Layout.fillHeight: true }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.inkDim; font.pixelSize: 11; font.family: "monospace"
               text: "0.1.0 — key collection only. Displaying and unsealing your sealed record arrives in 0.1.1." }
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
            Button {
                text: actionText; enabled: parent.parent.enabled
                onClicked: parent.parent.action()
            }
        }
    }
}
