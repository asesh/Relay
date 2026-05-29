import Foundation

// MARK: - Proxy Manager

public final class ProxyManager {

    public static let shared = ProxyManager()
    private init() {}

    public enum ProxyConfiguration {
        case system
        case custom(host: String, port: Int, username: String?, password: String?)
        case socks5(host: String, port: Int, username: String?, password: String?)
        case none
    }

    public var noProxyHosts: [String] = []

    /// Apply proxy configuration to a URLSessionConfiguration
    public func configure(_ config: URLSessionConfiguration, with proxy: ProxyConfiguration) {
        switch proxy {
        case .system:
            // URLSession uses system proxy by default; no change needed
            break

        case .custom(let host, let port, let user, let pass):
            var proxyDict: [String: Any] = [:]
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = port
            proxyDict[kCFNetworkProxiesHTTPSEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPSProxy as String] = host
            proxyDict[kCFNetworkProxiesHTTPSPort as String] = port
            if let user = user { proxyDict["HTTPProxyUsername"] = user }
            if let pass = pass { proxyDict["HTTPProxyPassword"] = pass }
            config.connectionProxyDictionary = proxyDict

        case .socks5(let host, let port, let user, let pass):
            var proxyDict: [String: Any] = [:]
            proxyDict[kCFNetworkProxiesSOCKSEnable as String] = true
            proxyDict[kCFNetworkProxiesSOCKSProxy as String] = host
            proxyDict[kCFNetworkProxiesSOCKSPort as String] = port
            if let user = user { proxyDict["SOCKSProxyUsername"] = user }
            if let pass = pass { proxyDict["SOCKSProxyPassword"] = pass }
            config.connectionProxyDictionary = proxyDict

        case .none:
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: false,
                kCFNetworkProxiesHTTPSEnable as String: false,
                kCFNetworkProxiesSOCKSEnable as String: false
            ]
        }
    }

    /// Whether a given host should bypass the proxy
    public func shouldBypass(host: String) -> Bool {
        noProxyHosts.contains { pattern in
            if pattern == host { return true }
            if pattern.hasPrefix("*") {
                let suffix = String(pattern.dropFirst())
                return host.hasSuffix(suffix)
            }
            return false
        }
    }

    #if os(macOS)
    /// Read system proxy settings from SystemConfiguration
    public func systemProxySettings() -> [String: Any] {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return settings
    }
    #endif
}

// MARK: - Cookie Manager

public final class CookieManager {

    public static let shared = CookieManager()
    private let storage = HTTPCookieStorage.shared
    private init() {}

    /// All cookies for a given domain
    public func cookies(for url: URL) -> [HTTPCookie] {
        storage.cookies(for: url) ?? []
    }

    /// All cookies in jar
    public var allCookies: [HTTPCookie] {
        storage.cookies ?? []
    }

    /// Cookies grouped by domain
    public var cookiesByDomain: [String: [HTTPCookie]] {
        Dictionary(grouping: allCookies) { $0.domain }
    }

    /// Add or update a cookie
    public func setCookie(_ cookie: HTTPCookie) {
        storage.setCookie(cookie)
    }

    /// Delete a cookie
    public func deleteCookie(_ cookie: HTTPCookie) {
        storage.deleteCookie(cookie)
    }

    /// Clear all cookies for a domain
    public func clearCookies(for domain: String) {
        allCookies.filter { $0.domain == domain }.forEach { storage.deleteCookie($0) }
    }

    /// Clear all cookies
    public func clearAll() {
        allCookies.forEach { storage.deleteCookie($0) }
    }

    /// Sync cookies from a URLResponse into the shared jar
    public func sync(from response: HTTPURLResponse, requestURL: URL) {
        guard let headerFields = response.allHeaderFields as? [String: String] else { return }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: requestURL)
        cookies.forEach { storage.setCookie($0) }
    }

    /// Build Cookie header value for a request
    public func cookieHeader(for url: URL) -> String? {
        let cookies = storage.cookies(for: url) ?? []
        guard !cookies.isEmpty else { return nil }
        return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}
