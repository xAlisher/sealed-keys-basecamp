# Sealed — receive-key collection module (0.1.0)

A Basecamp module for the **Sealed** collection (the on-chain wing of the Museum of Civil Liberties). **0.1.0 scope: key collection only** — a recipient creates/opens a wallet, generates the **receive-key** (npk + vpk) a curator shields their sealed record to, and exports it as a `.keys` file to send back. It does **not** yet display or unseal NFTs — that is **0.1.1**.

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

> On-chain **auto-discovery** of a record's `definition_id` + `metadata.uri` (printed-copy → master →
> metadata account) is not wired yet — 0.1.1 takes them via the "Add a sealed record" form (the curator
> ships them with the NFT). That resolution is the 0.1.2 step.

## Status — BUILD GREEN (0.1.1), install pending
`nix build .#lgx-portable` → exit 0; `.lgx` carries `sealed_keys_plugin.so` with all **10** methods in
the dispatch table (version 0.1.1). QML passes `qmllint` (exit 0). **Not yet installed** — a GUI install
into Basecamp + a live walkthrough (sync → unseal → copy) is wetware. Crypto/transport are proven
(`logos-nft-research/experiments/sealed-collection/` + the wallet `unseal` command).

## Roadmap
- **0.1.0:** receive-key collection. ✓
- **0.1.1 (this):** sealed gallery — sync, redaction art, **unseal** (decrypt `metadata.uri` with the viewing key) + copy. ✓ builds
- **0.1.2:** on-chain auto-discovery of each owned record's `definition_id` + `metadata.uri`; optional Logos Storage for >100 KiB media.
