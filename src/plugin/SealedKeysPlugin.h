#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QProcess>

#include "interface.h"   // PluginInterface + LogosAPI, from the Logos C++ SDK

// Sealed — 0.1.0 "receive-key collection".
//
// Scope of 0.1.0: let a recipient create/open a wallet and produce the RECEIVE-KEY
// (npk + vpk) that a curator shields NFTs to, then export it as a `.keys` file to
// send back. It does NOT yet fetch, display, or unseal NFTs (that is 0.1.1).
//
// Integration: shells out to the `wallet` CLI via QProcess, exactly like
// logos-wallet-basecamp (cliPath stored in QSettings). No FFI in 0.1.0.
class SealedKeysPlugin : public QObject, public PluginInterface
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.logos.SealedKeysModuleInterface" FILE "metadata.json")
    Q_INTERFACES(PluginInterface)

public:
    explicit SealedKeysPlugin(QObject* parent = nullptr);
    ~SealedKeysPlugin() override = default;

    QString name()    const override { return QStringLiteral("sealed_keys"); }
    QString version() const override { return QStringLiteral("0.1.0"); }

    Q_INVOKABLE void initLogos(LogosAPI* api);

    // Status / config — is the wallet CLI available + where.
    Q_INVOKABLE QString getStatus() const;              // JSON: { cliFound, cliPath }
    Q_INVOKABLE QString getConfig() const;              // JSON: { cliPath, cliPathEff }
    Q_INVOKABLE QString setCliPath(const QString& path);

    // Wallet — create a new private account (the recipient's identity) or list existing.
    Q_INVOKABLE QString createPrivateAccount();         // `account new private`  -> id + mnemonic
    Q_INVOKABLE QString listAccounts();                 // `account list`

    // The receive-key the curator shields to. `account new private-accounts-key`
    // returns npk + vpk (the vsk stays in the wallet, never shared).
    Q_INVOKABLE QString generateReceiveKey();           // JSON: { npk, vpk }
    Q_INVOKABLE QString showKeys(const QString& accountId); // JSON: { npk, vpk }

    // Write a `.keys` file (npk line 1, vpk line 2) matching the CLI `--to-keys`
    // convention, for the recipient to send to the curator out-of-band.
    Q_INVOKABLE QString exportReceiveKeyFile(const QString& npk,
                                             const QString& vpk,
                                             const QString& path);

private:
    QString cliPath() const;
    QString runWalletCommand(const QStringList& args, int timeoutMs = 60000) const;

    LogosAPI* m_api = nullptr;
};
