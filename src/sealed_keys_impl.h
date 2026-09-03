#pragma once

#include <string>

#include <logos_module_context.h>
#include <logos_result.h>

/**
 * @brief Sealed — receive-key collection (0.1.0). Universal (Qt-free) module.
 *
 * The recipient of a sealed record needs a wallet and the receive-key
 * (npk + vpk) a curator shields the NFT to. This module drives the Logos
 * `wallet` CLI via a subprocess (no FFI in 0.1.0) and returns JSON to the
 * ui_qml front-end, which calls us through `logos.callModule("sealed_keys", …)`.
 *
 * Scope 0.1.0: key collection only (create wallet · generate receive-key ·
 * export a .keys file). Displaying + unsealing NFTs is 0.1.1.
 */
class SealedKeysImpl : public LogosModuleContext
{
public:
    SealedKeysImpl();

    // ── wallet CLI location ────────────────────────────────────────────────────
    /// { cliFound: bool, cliPath: string } — is a runnable wallet binary set?
    StdLogosResult getStatus();
    /// Point at the wallet binary; returns the same shape as getStatus.
    StdLogosResult setCliPath(const std::string& path);
    /// Point at the wallet home dir (config + keystore); returns { ok, walletHome }.
    StdLogosResult setWalletHome(const std::string& path);

    // ── key collection ─────────────────────────────────────────────────────────
    /// `account new private` → { raw } (UI scrapes the account id + mnemonic).
    StdLogosResult createPrivateAccount();
    /// `account new private-accounts-key` → { npk, vpk } (vsk stays in the wallet).
    StdLogosResult generateReceiveKey();
    /// `account show-keys <id>` → { npk, vpk }.
    StdLogosResult showKeys(const std::string& accountId);
    /// Write a two-line .keys file (npk\nvpk) → { ok, path }.
    StdLogosResult exportReceiveKeyFile(const std::string& npk,
                                        const std::string& vpk,
                                        const std::string& path);

    // ── 0.1.1: gallery + unseal ─────────────────────────────────────────────────
    /// `account sync-private` — pull shielded state to the tip → { ok, raw }.
    StdLogosResult syncPrivate();
    /// `account list --long` — accounts the wallet holds → { accounts:[…], raw }.
    StdLogosResult listSealed();
    /// Unseal a sealed record with the wallet's own viewing key (vsk never leaves here):
    /// `account show-keys --viewing-secret <id>` → (d,z), then `unseal …` → { url, note, … }.
    StdLogosResult unseal(const std::string& accountId,
                          const std::string& metadataUri,
                          const std::string& definitionId);

    std::string name() const { return "sealed_keys"; }
    std::string version() const { return "0.1.1"; }

private:
    struct CliResult { int code; std::string out; };
    /// Run the wallet CLI with the given argv tail; captures stdout+stderr.
    CliResult runCli(const std::string& args);
    /// First runnable wallet binary: the set path, else search PATH.
    std::string resolveCli();
    /// Parse "npk <hex>" / "vpk <hex>" (and prefix variants) from CLI output.
    static std::string scrapeKey(const std::string& out, const std::string& label);

    std::string m_cliPath;      // explicit wallet binary, if set
    std::string m_walletHome;   // LEE_WALLET_HOME_DIR, if set
};
