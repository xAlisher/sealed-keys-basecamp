# Sealed — receive-key collection module (0.1.0)

A Basecamp module for the **Sealed** collection (the on-chain wing of the Museum of Civil Liberties). **0.1.0 scope: key collection only** — a recipient creates/opens a wallet, generates the **receive-key** (npk + vpk) a curator shields their sealed record to, and exports it as a `.keys` file to send back. It does **not** yet display or unseal NFTs — that is **0.1.1**.

## Why key-collection first
Distribution is **shield-to-recipient**: the curator must have each recipient's `(npk, vpk)` before they can encrypt the payload to that viewing key and shield the NFT. So collecting keys is the first real step (see `logos-nft-research/docs/journey-and-architecture.md`).

## Structure (mirrors `logos-wallet-basecamp`)
```
metadata.json                         core-plugin build config (Qt6 + cmake)
modules/sealed_keys/manifest.json     installed core manifest (.so per platform)
plugins/sealed_keys_ui/manifest.json  installed ui_qml manifest (depends on sealed_keys)
src/plugin/SealedKeysPlugin.{h,cpp}   C++ plugin: Q_INVOKABLE methods -> wallet CLI (QProcess)
plugins/sealed_keys_ui/qml/Main.qml   the key-collection UI
CMakeLists.txt                        nix-builder path + local-dev path
```

## Integration
The plugin **shells out to the `wallet` CLI** via `QProcess` (same approach as `logos-wallet-basecamp`; no FFI in 0.1.0). QML calls it with `logos.callModule("sealed_keys", "<method>", [args])`. Methods:
- `getStatus` / `getConfig` / `setCliPath` — locate the wallet binary.
- `createPrivateAccount` → `account new private` (the recipient's identity + mnemonic to back up).
- `generateReceiveKey` → `account new private-accounts-key` → `{ npk, vpk }` (the vsk stays in the wallet, never shared).
- `showKeys(accountId)` → `account show-keys` → `{ npk, vpk }`.
- `exportReceiveKeyFile(npk, vpk, path)` → writes a `.keys` file (npk line 1, vpk line 2, the CLI `--to-keys` format).

## Receiver flow (the UI)
1. Wallet CLI status / set path.  2. **Create wallet** (back up the mnemonic).  3. **Generate receive-key** (shows npk + vpk).  4. **Export `.keys`** and send it to the curator out-of-band.

## Build
Nix (Basecamp module builder), same as the reference:
```
nix build .#lgx-portable      # once flake.nix is wired to the module-builder input
```
Local dev (needs Qt6 + the Logos C++ SDK via `LOGOS_CPP_SDK_ROOT` / `LOGOS_LIBLOGOS_HEADERS`):
```
cmake -B build && cmake --build build
```

## Status — SCAFFOLD
Skeleton + plugin methods + UI are written and mirror a known-good module. **Not yet built/installed** — that needs the Basecamp module build env (nix flake input + C++ SDK) and a GUI install to verify, which is wetware. Crypto/transport it feeds are already proven (`logos-nft-research/experiments/sealed-collection/`).

## Roadmap
- **0.1.0 (this):** receive-key collection.
- **0.1.1:** sealed gallery — `sync`, list holdings, render redaction art, **unseal** (decrypt the `metadata.uri` payload with the viewing key) + copy; optional Logos Storage for >100 KiB media.
