# Sealed records — a private-NFT Basecamp app (PoC)

> **Disclaimer.** This is an independent community project intended to demonstrate some of the capabilities and potential uses of the Logos technology stack. It has been developed independently by its contributor(s) and is not built for, on behalf of, or as part of the work of Logos or the Institute of Free Technology. It has not been reviewed, audited, approved, or endorsed by Logos or the Institute of Free Technology. The project, including its code, documentation, views, and functionality, is the sole responsibility of its contributor(s) and should not be attributed to Logos or the Institute of Free Technology.
>
> Proof-of-concept only — test / dev-mode, throwaway keys, local testnet. Do not use in production.

A Basecamp app for **Sealed records** — the on-chain wing of the *Museum of Civil Liberties*. It shows a collection of NFTs grouped into exhibit halls; each is **sealed** (a redacted paper with a wax stamp, owner hidden, contents encrypted). The holder **unseals** with their own viewing key to reveal the document's title, source and link — proving ownership privately, on their terms. It shells the Logos LEZ `wallet` CLI (with the NFT commands this PoC added on a fork). Research + findings: [xAlisher/logos-nft-research](https://github.com/xAlisher/logos-nft-research).

## Why key-collection first
Distribution is **shield-to-recipient**: the curator must have each recipient's `(npk, vpk)` before they can encrypt the payload to that viewing key and shield the NFT. So collecting keys is the first real step (see `logos-nft-research/docs/journey-and-architecture.md`).

## Structure (universal core module + ui_qml)
```
metadata.json                         core module config: interface "universal" + codegen.impl_header
src/sealed_keys_impl.h                SealedKeysImpl : public LogosModuleContext (the contract)
src/sealed_keys_impl.cpp              methods -> wallet CLI (popen); returns StdLogosResult (JSON)
plugins/sealed_keys_ui/manifest.json  installed ui_qml manifest (depends on sealed_keys)
plugins/sealed_keys_ui/qml/Main.qml   the key-collection UI
CMakeLists.txt                        logos_module(NAME sealed_keys SOURCES … ) — builder glue
```

## Integration
Modern **universal** interface: the contract is derived from `src/sealed_keys_impl.h`
(`SealedKeysImpl : public LogosModuleContext`, methods return `StdLogosResult`, take
`const std::string&`). The `logos-module-builder` generates the plugin glue (`logos_module_dispatch` /
`_get_methods`) — no hand-written QObject. It is **Qt-free** and **shells out to the `wallet` CLI**
via `popen` (no FFI in 0.1.0). QML calls it with `logos.callModule("sealed_keys", "<method>", [args])`
(double-JSON-encoded return; unwrap with the `parse()` helper). Methods:
- `getStatus` / `setCliPath` / `setWalletHome` — locate the wallet binary + home dir.
- `createPrivateAccount` → `account new private` (the recipient's identity + mnemonic to back up).
- `generateReceiveKey` → `account new private-accounts-key` → `{ npk, vpk }` (the vsk stays in the wallet, never shared).
- `showKeys(accountId)` → `account show-keys` → `{ npk, vpk }`.
- `exportReceiveKeyFile(npk, vpk, path)` → writes a `.keys` file (npk line 1, vpk line 2, the CLI `--to-keys` format).

## Receiver flow (the UI)
1. Wallet CLI status / set path.  2. **Create wallet** (back up the mnemonic).  3. **Generate receive-key** (shows npk + vpk).  4. **Export `.keys`** and send it to the curator out-of-band.

## Build
Nix (Basecamp module builder):
```
TMPDIR=/extra/tmp nix build .#lgx-portable
```
Produces `logos-sealed_keys-module-lib.lgx` (linux-amd64 variant, `sealed_keys_plugin.so`, all
seven methods in the dispatch table). **New source files must be `git add`-ed first** — nix flakes
only copy git-tracked files, so an untracked `.h`/`.cpp` fails codegen with "Failed to open header file".

## 0.1.1 — the sealed gallery + unseal
Two tabs: **My sealed** (gallery) and **Get key** (the 0.1.0 flow). The gallery: `syncPrivate`,
render each record as **redaction art** (deterministic from the definition id), and **Unseal** — which
fetches the wallet's own viewing secret (`account show-keys --viewing-secret`, stays inside the module)
and calls the wallet CLI `unseal` to decrypt the on-chain `metadata.uri` payload, flipping the card to
**UNSEALED** with the curator's note + a copy-able link. The `unseal` wallet command is proven live
(`lez-work` branch `nft/epic-a-wallet`: unit round-trip + a real-binary run — right key returns the
exact payload, wrong key errors). New methods: `syncPrivate`, `listSealed`, `unseal`.

## 0.1.2 — on-chain auto-discovery
The gallery now **discovers your sealed records on-chain** — no pasting ids or uris. `listSealed` calls
the wallet CLI `sealed-records`, which walks every account the wallet holds, keeps the NFT holdings, and
resolves each `definition_id → definition → metadata_id → metadata.uri`, returning the `sealed:v1:`
records as `[{account, definitionId, name, metadataUri}]`. **Sync** then **Discover** populates the
cards; a manual "Add a record" form remains as a fallback. Proven live on the Sneg node (define an NFT
with a sealed uri → print → `sealed-records` returns the resolved record — see
`logos-nft-research/experiments/nft-discovery/`).

## Status — BUILD GREEN (0.1.2), install pending
`nix build .#lgx-portable` → exit 0; `.lgx` carries `sealed_keys_plugin.so` with all **10** methods in
the dispatch table (version 0.1.2). QML passes `qmllint` (exit 0). The wallet commands it stands on
(`unseal`, `sealed-records`) are **proven live** on the node. **Not yet installed** — a GUI install into
Basecamp + a live walkthrough (sync → discover → unseal → copy) is wetware.

## Roadmap
- **0.1.0:** receive-key collection. ✓
- **0.1.1:** sealed gallery — sync, redaction art, **unseal** (decrypt `metadata.uri` with the viewing key) + copy. ✓
- **0.1.2 (this):** on-chain auto-discovery of each owned record's `definition_id` + `metadata.uri`. ✓ builds + proven live
- **0.1.3:** optional Logos Storage for >100 KiB media; private-account discovery hardening.
