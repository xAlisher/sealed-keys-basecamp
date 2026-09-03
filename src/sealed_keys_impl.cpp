#include "sealed_keys_impl.h"

#include <array>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <regex>
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
    // Match e.g. "npk: <hex>", "npk = <hex>", "vpk <hex>" — hex or base58 token.
    std::regex re(label + R"([:=\s]+([0-9a-zA-Z]+))", std::regex::icase);
    std::smatch m;
    if (std::regex_search(out, m, re)) return m[1].str();
    return {};
}

StdLogosResult SealedKeysImpl::getStatus() {
    std::string cli = resolveCli();
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
    CliResult r = runCli("account show-keys " + shq(accountId));
    if (r.code != 0) return {false, {}, r.out.empty() ? "show-keys failed" : r.out};
    std::string npk = scrapeKey(r.out, "npk");
    std::string vpk = scrapeKey(r.out, "vpk");
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
