#include "SealedKeysPlugin.h"

#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

// QSettings key for the wallet CLI path (mirrors logos-wallet-basecamp).
static constexpr const char* kCliPathKey = "sealed-keys/cliPath";

SealedKeysPlugin::SealedKeysPlugin(QObject* parent) : QObject(parent) {}

void SealedKeysPlugin::initLogos(LogosAPI* api) { m_api = api; }

// ── CLI path resolution ────────────────────────────────────────────────────
QString SealedKeysPlugin::cliPath() const
{
    QSettings s;
    QString stored = s.value(kCliPathKey).toString();
    if (!stored.isEmpty() && QFileInfo::exists(stored)) return stored;
    // Fall back to `wallet` on PATH.
    QString onPath = QStandardPaths::findExecutable(QStringLiteral("wallet"));
    return onPath.isEmpty() ? QStringLiteral("wallet") : onPath;
}

// ── QProcess runner (merged stdout+stderr) ─────────────────────────────────
QString SealedKeysPlugin::runWalletCommand(const QStringList& args, int timeoutMs) const
{
    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(cliPath(), args);
    if (!proc.waitForStarted(5000))
        return QStringLiteral("ERROR: wallet CLI not found (set the path in settings)");
    if (!proc.waitForFinished(timeoutMs))
        return QStringLiteral("ERROR: wallet command timed out");
    return QString::fromUtf8(proc.readAll()).trimmed();
}

// ── Status / config ─────────────────────────────────────────────────────────
QString SealedKeysPlugin::getStatus() const
{
    const QString bin = cliPath();
    QProcess check;
    check.start(bin, {QStringLiteral("--version")});
    const bool found = check.waitForStarted(3000) && check.waitForFinished(3000);
    QJsonObject o;
    o[QStringLiteral("cliFound")] = found;
    o[QStringLiteral("cliPath")]  = bin;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString SealedKeysPlugin::getConfig() const
{
    QSettings s;
    QJsonObject o;
    o[QStringLiteral("cliPath")]    = s.value(kCliPathKey).toString();
    o[QStringLiteral("cliPathEff")] = cliPath();
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString SealedKeysPlugin::setCliPath(const QString& path)
{
    QSettings s;
    s.setValue(kCliPathKey, path);
    return getConfig();
}

// ── Wallet / accounts ────────────────────────────────────────────────────────
QString SealedKeysPlugin::createPrivateAccount()
{
    // Creates a private account (the recipient's identity). Output includes the
    // account id and, on a fresh wallet, a mnemonic to back up.
    return runWalletCommand({QStringLiteral("account"),
                             QStringLiteral("new"),
                             QStringLiteral("private")});
}

QString SealedKeysPlugin::listAccounts()
{
    return runWalletCommand({QStringLiteral("account"), QStringLiteral("list")});
}

// ── Receive-key (npk + vpk) ──────────────────────────────────────────────────
// Parses the CLI output of `account new private-accounts-key` / `show-keys`,
// which prints npk on one line and vpk on the next (see the token-transfer tutorial).
static QJsonObject parseNpkVpk(const QString& out)
{
    QJsonObject o;
    for (const QString& line : out.split('\n')) {
        const QString t = line.trimmed();
        // npk = 64 hex chars (32 bytes); vpk = 2368 hex chars (1184 bytes).
        if (t.size() == 64 && !o.contains(QStringLiteral("npk")))
            o[QStringLiteral("npk")] = t;
        else if (t.size() >= 2000 && !o.contains(QStringLiteral("vpk")))
            o[QStringLiteral("vpk")] = t;
    }
    o[QStringLiteral("raw")] = out;
    return o;
}

QString SealedKeysPlugin::generateReceiveKey()
{
    const QString out = runWalletCommand({QStringLiteral("account"),
                                          QStringLiteral("new"),
                                          QStringLiteral("private-accounts-key")});
    return QString::fromUtf8(QJsonDocument(parseNpkVpk(out)).toJson(QJsonDocument::Compact));
}

QString SealedKeysPlugin::showKeys(const QString& accountId)
{
    const QString out = runWalletCommand({QStringLiteral("account"),
                                          QStringLiteral("show-keys"),
                                          QStringLiteral("--account-id"), accountId});
    return QString::fromUtf8(QJsonDocument(parseNpkVpk(out)).toJson(QJsonDocument::Compact));
}

// ── Export the shareable .keys file (npk line 1, vpk line 2) ─────────────────
QString SealedKeysPlugin::exportReceiveKeyFile(const QString& npk,
                                               const QString& vpk,
                                               const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return QStringLiteral("ERROR: cannot write ") + path;
    f.write((npk + "\n" + vpk + "\n").toUtf8());
    f.close();
    QJsonObject o;
    o[QStringLiteral("ok")]   = true;
    o[QStringLiteral("path")] = path;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}
