#include "sealed_keys_impl.h"

#include <array>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <regex>
#include <sstream>
#include <sys/stat.h>

namespace {
// Shell-quote a single argument for /bin/sh (wrap in single quotes, escape any ').
std::string shq(const std::string& s) {
    std::string out = "'";
    for (char c : s) {
        if (c == '\'') out += "'\\''";
        else out += c;
    }
    out += "'";
    return out;
}

bool isExecutable(const std::string& p) {
    if (p.empty()) return false;
    struct stat st{};
    return ::stat(p.c_str(), &st) == 0 && (st.st_mode & S_IXUSR) && S_ISREG(st.st_mode);
}
} // namespace

SealedKeysImpl::SealedKeysImpl() = default;

std::string SealedKeysImpl::resolveCli() {
    if (isExecutable(m_cliPath)) return m_cliPath;
    // Explicit override (survives AppImage PATH resets).
    if (const char* bin = std::getenv("LEE_WALLET_BIN")) {
        if (isExecutable(bin)) return bin;
    }
    // Search PATH for a `wallet` binary.
    if (const char* path = std::getenv("PATH")) {
        std::string p(path);
        size_t start = 0;
        while (start <= p.size()) {
            size_t end = p.find(':', start);
            std::string dir = p.substr(start, end == std::string::npos ? std::string::npos : end - start);
            if (!dir.empty()) {
                std::string cand = dir + "/wallet";
                if (isExecutable(cand)) return cand;
            }
            if (end == std::string::npos) break;
            start = end + 1;
        }
    }
    return {};
}

SealedKeysImpl::CliResult SealedKeysImpl::runCli(const std::string& args) {
    std::string cli = resolveCli();
    if (cli.empty()) return {127, "wallet CLI not found"};

    std::string cmd;
    if (!m_walletHome.empty())
        cmd += "LEE_WALLET_HOME_DIR=" + shq(m_walletHome) + " ";
    cmd += shq(cli) + " " + args + " 2>&1";

    std::array<char, 4096> buf{};
    std::string out;
    FILE* pipe = ::popen(cmd.c_str(), "r");
    if (!pipe) return {127, "failed to launch wallet CLI"};
    while (::fgets(buf.data(), static_cast<int>(buf.size()), pipe))
        out += buf.data();
    int status = ::pclose(pipe);
    int code = (status == -1) ? 127 : ((status >> 8) & 0xff);
    return {code, out};
}

std::string SealedKeysImpl::scrapeKey(const std::string& out, const std::string& label) {
    // Match e.g. "With npk <hex>", "vsk_d <hex>" — label followed by a hex token.
    std::regex re(label + R"([:=\s]+([0-9a-zA-Z]+))", std::regex::icase);
    std::smatch m;
    if (std::regex_search(out, m, re)) return m[1].str();
    return {};
}

// `account show-keys --account-id <id>` prints two UNLABELED hex lines: npk (64), then vpk (2368).
static bool isHexLine(const std::string& l) {
    if (l.size() < 64) return false;
    for (char c : l) if (!std::isxdigit(static_cast<unsigned char>(c))) return false;
    return true;
}
static void scrapeHexLines(const std::string& out, std::string& npk, std::string& vpk) {
    std::istringstream ss(out);
    std::string l;
    while (std::getline(ss, l)) {
        while (!l.empty() && (l.back() == '\r' || l.back() == ' ')) l.pop_back();
        if (!isHexLine(l)) continue;                 // manual — no std::regex on long lines
        if (l.size() == 64 && npk.empty()) npk = l;
        else if (l.size() > 64 && vpk.empty()) vpk = l;
    }
}

static void dbg(const std::string& msg) {
    if (std::ofstream f("/extra/tmp/sealed-keys-debug.log", std::ios::app); f) f << msg << "\n";
}

StdLogosResult SealedKeysImpl::getStatus() {
    std::string cli = resolveCli();
    const char* env_bin = std::getenv("LEE_WALLET_BIN");
    const char* env_path = std::getenv("PATH");
    dbg(std::string("getStatus: LEE_WALLET_BIN=") + (env_bin ? env_bin : "(null)") +
        " execTest=" + (env_bin && isExecutable(env_bin) ? "yes" : "no") +
        " m_cliPath=[" + m_cliPath + "] resolved=[" + cli + "]" +
        " PATH=" + (env_path ? std::string(env_path).substr(0, 80) : "(null)"));
    return {true, nlohmann::json{{"cliFound", !cli.empty()}, {"cliPath", cli}}};
}

StdLogosResult SealedKeysImpl::setCliPath(const std::string& path) {
    m_cliPath = path;
    std::string cli = resolveCli();
    return {true, nlohmann::json{{"cliFound", !cli.empty()}, {"cliPath", cli}}};
}

StdLogosResult SealedKeysImpl::setWalletHome(const std::string& path) {
    m_walletHome = path;
    return {true, nlohmann::json{{"ok", true}, {"walletHome", m_walletHome}}};
}

StdLogosResult SealedKeysImpl::createPrivateAccount() {
    CliResult r = runCli("account new private");
    if (r.code != 0) return {false, {}, r.out.empty() ? "account new private failed" : r.out};
    return {true, nlohmann::json{{"raw", r.out}}};
}

StdLogosResult SealedKeysImpl::generateReceiveKey() {
    CliResult r = runCli("account new private-accounts-key");
    if (r.code != 0) return {false, {}, r.out.empty() ? "generate receive-key failed" : r.out};
    std::string npk = scrapeKey(r.out, "npk");
    std::string vpk = scrapeKey(r.out, "vpk");
    return {true, nlohmann::json{{"npk", npk}, {"vpk", vpk}, {"raw", r.out}}};
}

StdLogosResult SealedKeysImpl::showKeys(const std::string& accountId) {
    CliResult r = runCli("account show-keys --account-id " + shq(accountId));
    if (r.code != 0) return {false, {}, r.out.empty() ? "show-keys failed" : r.out};
    std::string npk, vpk;
    scrapeHexLines(r.out, npk, vpk);   // show-keys prints two unlabeled hex lines
    return {true, nlohmann::json{{"npk", npk}, {"vpk", vpk}, {"raw", r.out}}};
}

StdLogosResult SealedKeysImpl::exportReceiveKeyFile(const std::string& npk,
                                                    const std::string& vpk,
                                                    const std::string& path) {
    if (npk.empty() || vpk.empty())
        return {false, {}, "npk and vpk are required"};
    std::ofstream f(path, std::ios::trunc);
    if (!f) return {false, {}, "cannot open " + path + " for writing"};
    f << npk << "\n" << vpk << "\n";
    f.close();
    if (!f) return {false, {}, "write to " + path + " failed"};
    return {true, nlohmann::json{{"ok", true}, {"path", path}}};
}

// ── 0.1.1: gallery + unseal ─────────────────────────────────────────────────────

StdLogosResult SealedKeysImpl::syncPrivate() {
    CliResult r = runCli("account sync-private");
    if (r.code != 0) return {false, {}, r.out.empty() ? "sync-private failed" : r.out};
    return {true, nlohmann::json{{"ok", true}, {"raw", r.out}}};
}

StdLogosResult SealedKeysImpl::listSealed() {
    // 0.1.2: on-chain auto-discovery. `sealed-records` walks the wallet, resolves each NFT
    // holding through definition -> metadata -> uri, and prints the sealed:v1: records as JSON.
    CliResult r = runCli("sealed-records");
    if (r.code != 0) return {false, {}, r.out.empty() ? "sealed-records failed" : r.out};

    // Extract the JSON array by first '[' .. last ']' (plain string ops — NEVER std::regex here:
    // the output is ~KBs and std::regex `.*` recurses per char and stack-overflows -> SIGSEGV).
    std::string arrLine;
    {
        size_t lb = r.out.find('[');
        size_t rb = r.out.rfind(']');
        if (lb != std::string::npos && rb != std::string::npos && rb > lb)
            arrLine = r.out.substr(lb, rb - lb + 1);
    }
    if (arrLine.empty())
        return {true, nlohmann::json{{"records", nlohmann::json::array()}, {"raw", r.out}}};

    nlohmann::json all = nlohmann::json::parse(arrLine, nullptr, false);
    if (all.is_discarded() || !all.is_array())
        return {true, nlohmann::json{{"records", nlohmann::json::array()}, {"raw", arrLine}}};
    // Keep the privately-owned records — the ones this wallet's viewing key can unseal.
    nlohmann::json records = nlohmann::json::array();
    for (auto& r : all) {
        std::string acc = r.value("account", "");
        if (acc.rfind("Private/", 0) == 0) records.push_back(r);
    }
    return {true, nlohmann::json{{"records", records}}};
}

StdLogosResult SealedKeysImpl::unseal(const std::string& accountId,
                                      const std::string& metadataUri,
                                      const std::string& definitionId) {
    if (metadataUri.empty() || definitionId.empty())
        return {false, {}, "metadataUri and definitionId are required"};

    // Fetch the wallet's own viewing secret (d, z) — it stays inside this module.
    CliResult keys = runCli("account show-keys --account-id " + shq(accountId) + " --viewing-secret");
    if (keys.code != 0)
        return {false, {}, keys.out.empty() ? "show-keys --viewing-secret failed" : keys.out};
    std::string d = scrapeKey(keys.out, "vsk_d");
    std::string z = scrapeKey(keys.out, "vsk_z");
    if (d.empty() || z.empty())
        return {false, {}, "could not read viewing secret (vsk_d/vsk_z) from show-keys"};

    // Decrypt the on-chain payload with the wallet CLI (read-only, no node needed).
    CliResult u = runCli("unseal --metadata-uri " + shq(metadataUri) +
                         " --definition-id " + shq(definitionId) +
                         " --vsk-d " + shq(d) + " --vsk-z " + shq(z));
    if (u.code != 0)
        return {false, {}, u.out.empty() ? "unseal failed" : u.out};

    // The command prints the sealed JSON ({"title":…,"url":…,…}); extract by first '{'..last '}'
    // via plain string ops (NOT std::regex — it stack-overflows on long lines -> SIGSEGV).
    std::string payloadLine;
    {
        size_t lb = u.out.find('{');
        size_t rb = u.out.rfind('}');
        if (lb != std::string::npos && rb != std::string::npos && rb > lb)
            payloadLine = u.out.substr(lb, rb - lb + 1);
    }
    if (payloadLine.empty())
        return {true, nlohmann::json{{"raw", u.out}}};  // hand raw text to the UI

    nlohmann::json parsed = nlohmann::json::parse(payloadLine, nullptr, false);
    if (parsed.is_discarded())
        return {true, nlohmann::json{{"raw", payloadLine}}};
    parsed["ok"] = true;
    return {true, parsed};
}
