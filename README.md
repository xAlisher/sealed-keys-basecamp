# Sealed records — a private-NFT Basecamp app (PoC)

> **Disclaimer.** This is an independent community project intended to demonstrate some of the capabilities and potential uses of the Logos technology stack. It has been developed independently by its contributor(s) and is not built for, on behalf of, or as part of the work of Logos or the Institute of Free Technology. It has not been reviewed, audited, approved, or endorsed by Logos or the Institute of Free Technology. The project, including its code, documentation, views, and functionality, is the sole responsibility of its contributor(s) and should not be attributed to Logos or the Institute of Free Technology.
>
> Proof-of-concept only — test / dev-mode, throwaway keys, local testnet. Do not use in production.

A Logos Basecamp app that demonstrates **private NFT ownership** on the Logos Execution Zone (LEZ). It presents **Sealed records** — the on-chain wing of the *Museum of Civil Liberties*: a collection of NFTs whose ownership and contents are hidden on-chain, revealed only by the holder with their own viewing key.

Research + findings: [xAlisher/nft-research-for-logos](https://github.com/xAlisher/nft-research-for-logos).

## What it does
- **A gallery of sealed records**, grouped into exhibit "halls" (I · Control of Money, II · Surveillance State, …), each a numbered A4 "paper".
- **Sealed by default:** each card shows redaction art + a wax stamp. Owner reads **"unknown"**; the title, source and link are **encrypted** on-chain.
- **Unseal on your terms:** click a card and the app decrypts it with *your* viewing key (which never leaves the wallet). The paper reveals the document title + issuer/year; the curator's note and a copy-able archive link appear below. Owner flips to **"you (private)."**
- **Request NFT:** a modal walks a recipient through creating a wallet, generating a receive-key (npk + vpk), and copying it to share with a curator — who then shields an NFT to that key.

The collection's **structure is public** (which hall, which number, encoded in the NFT name), while the **contents are private** (title / source / note / link sealed in the encrypted payload).

## How it works
- A **universal** core module (`sealed_keys`) — the contract is derived from `src/sealed_keys_impl.h` (`SealedKeysImpl : public LogosModuleContext`, methods return `StdLogosResult`). Qt-free; it **shells the LEZ `wallet` CLI** via `popen`.
- A **ui_qml** plugin (`sealed_keys_ui`) — the gallery UI. It calls the core with `logos.callModule("sealed_keys", "<method>", [args])` and unwraps the `{success, value, error}` result.
- The NFT commands it drives (`new-nft`, `print-nft`, a transfer fix, `seal`, `unseal`, `sealed-records`) were added on an R&D fork of the LEZ wallet — the upstream wallet doesn't ship them yet.

Core methods: `getStatus`, `setCliPath`, `setWalletHome`, `createPrivateAccount`, `generateReceiveKey`, `showKeys`, `syncPrivate`, `listSealed`, `unseal` (+ a `.keys` export helper).

```
metadata.json                         core module config: interface "universal" + codegen.impl_header
src/sealed_keys_impl.{h,cpp}          SealedKeysImpl (the contract + wallet-CLI shelling)
plugins/sealed_keys_ui/               the ui_qml plugin: metadata.json + qml/Main.qml + flake.nix + icon
CMakeLists.txt                        logos_module(NAME sealed_keys …) — builder glue
```

## Build
Nix (Logos Basecamp module builder):
```
# core module
TMPDIR=/extra/tmp nix build .#lgx-portable
# ui plugin (separate lgx)
cd plugins/sealed_keys_ui && TMPDIR=/extra/tmp nix build .#lgx-portable
```
Produces two `.lgx` bundles (core + ui). **New source files must be `git add`-ed first** — nix flakes only copy git-tracked files, so an untracked `.h`/`.cpp` fails codegen with "Failed to open header file".

## Runtime
The core shells a local LEZ `wallet` binary (with the NFT commands) pointed at a running LEZ node. Set it via `LEE_WALLET_BIN` + `LEE_WALLET_HOME_DIR` (or the in-app "Set path" field), with `RISC0_DEV_MODE=1` for dev-mode. Then in the app: **Sync → Discover** to load your records, **click a card to Unseal**, **Copy link**.

## Status
Built and demonstrated end-to-end in an isolated Basecamp against a local LEZ testnet node: a 5-piece collection across 3 halls, discovered and unsealed. Dev-mode / PoC only. The reliable seeding script and the full findings (including bugs found and fixed by dogfooding) live in the [research repo](https://github.com/xAlisher/nft-research-for-logos).

## What this demonstrates
The one thing no other major chain offers: **an NFT you own privately** — invisible on-chain, transferable without a trace, revealed on your terms. See the research repo for the evidence and the comparison with Ethereum / Solana / Bitcoin Ordinals.
