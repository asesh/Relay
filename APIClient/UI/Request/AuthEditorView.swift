import SwiftUI

// MARK: - Auth Editor View

public struct AuthEditorView: View {
    @Binding var authConfig: AuthConfig

    public init(authConfig: Binding<AuthConfig>) {
        self._authConfig = authConfig
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Type picker
            HStack {
                Text("Auth Type")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $authConfig.type) {
                    ForEach(AuthType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            // Auth-specific form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    authForm
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var authForm: some View {
        switch authConfig.type {
        case .none:
            Text("No auth will be sent with this request.")
                .foregroundStyle(.secondary)
        case .inherit:
            Text("Auth will be inherited from the parent collection or folder.")
                .foregroundStyle(.secondary)
        case .apiKey:
            APIKeyForm(config: Binding(
                get: { authConfig.apiKeyConfig ?? APIKeyConfig() },
                set: { authConfig.apiKeyConfig = $0 }
            ))
        case .bearer:
            BearerForm(config: Binding(
                get: { authConfig.bearerConfig ?? BearerConfig() },
                set: { authConfig.bearerConfig = $0 }
            ))
        case .basic:
            BasicAuthForm(config: Binding(
                get: { authConfig.basicConfig ?? BasicAuthConfig() },
                set: { authConfig.basicConfig = $0 }
            ))
        case .digest:
            DigestAuthForm(config: Binding(
                get: { authConfig.digestConfig ?? DigestAuthConfig() },
                set: { authConfig.digestConfig = $0 }
            ))
        case .oauth1:
            OAuth1Form(config: Binding(
                get: { authConfig.oauth1Config ?? OAuth1Config() },
                set: { authConfig.oauth1Config = $0 }
            ))
        case .oauth2:
            OAuth2Form(config: Binding(
                get: { authConfig.oauth2Config ?? OAuth2Config() },
                set: { authConfig.oauth2Config = $0 }
            ))
        case .awsV4:
            AWSV4Form(config: Binding(
                get: { authConfig.awsV4Config ?? AWSV4Config() },
                set: { authConfig.awsV4Config = $0 }
            ))
        case .ntlm:
            NTLMForm(config: Binding(
                get: { authConfig.ntlmConfig ?? NTLMConfig() },
                set: { authConfig.ntlmConfig = $0 }
            ))
        case .hawk:
            HawkForm(config: Binding(
                get: { authConfig.hawkConfig ?? HawkConfig() },
                set: { authConfig.hawkConfig = $0 }
            ))
        case .jwt:
            JWTForm(config: Binding(
                get: { authConfig.jwtConfig ?? JWTConfig() },
                set: { authConfig.jwtConfig = $0 }
            ))
        }
    }
}

// MARK: - Form Components

private struct AuthFieldRow<Content: View>: View {
    let label: String
    let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label; self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}

// MARK: - API Key Form

private struct APIKeyForm: View {
    @Binding var config: APIKeyConfig

    var body: some View {
        AuthFieldRow("Key Name") {
            TextField("e.g. X-API-Key", text: $config.key)
                .textFieldStyle(.roundedBorder)
        }
        AuthFieldRow("Value") {
            SecureField("API Key value", text: $config.value)
                .textFieldStyle(.roundedBorder)
        }
        AuthFieldRow("Add To") {
            Picker("", selection: $config.addTo) {
                Text("Header").tag(APIKeyConfig.APIKeyLocation.header)
                Text("Query Param").tag(APIKeyConfig.APIKeyLocation.queryParam)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Bearer Token Form

private struct BearerForm: View {
    @Binding var config: BearerConfig

    var body: some View {
        AuthFieldRow("Token") {
            SecureField("Bearer token", text: $config.token)
                .textFieldStyle(.roundedBorder)
        }
        AuthFieldRow("Prefix") {
            TextField("Bearer", text: $config.prefix)
                .textFieldStyle(.roundedBorder)
        }
        if !config.token.isEmpty {
            Text("Header: Authorization: \(config.prefix) ...")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Basic Auth Form

private struct BasicAuthForm: View {
    @Binding var config: BasicAuthConfig
    @State private var showPassword = false

    var body: some View {
        AuthFieldRow("Username") {
            TextField("Username", text: $config.username)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
        AuthFieldRow("Password") {
            HStack {
                if showPassword || config.showPassword {
                    TextField("Password", text: $config.password)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Password", text: $config.password)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        if !config.username.isEmpty {
            Text("Encoded: Basic \(config.encoded.prefix(20))...")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Digest Auth Form

private struct DigestAuthForm: View {
    @Binding var config: DigestAuthConfig

    var body: some View {
        AuthFieldRow("Username") { TextField("Username", text: $config.username).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Password") { SecureField("Password", text: $config.password).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Realm") { TextField("Realm", text: $config.realm).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Nonce") { TextField("Nonce", text: $config.nonce).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Algorithm") { TextField("MD5", text: $config.algorithm).textFieldStyle(.roundedBorder) }
    }
}

// MARK: - OAuth 1.0 Form

private struct OAuth1Form: View {
    @Binding var config: OAuth1Config

    var body: some View {
        AuthFieldRow("Consumer Key") { TextField("Consumer Key", text: $config.consumerKey).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Consumer Secret") { SecureField("Consumer Secret", text: $config.consumerSecret).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Access Token") { TextField("Token", text: $config.token).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Token Secret") { SecureField("Token Secret", text: $config.tokenSecret).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Signature Method") {
            Picker("", selection: $config.signatureMethod) {
                ForEach(OAuth1Config.SignatureMethod.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }.pickerStyle(.segmented)
        }
    }
}

// MARK: - OAuth 2.0 Form

private struct OAuth2Form: View {
    @Binding var config: OAuth2Config
    @State private var showToken = false

    var body: some View {
        AuthFieldRow("Grant Type") {
            Picker("", selection: $config.grantType) {
                ForEach(OAuth2Config.GrantType.allCases, id: \.self) { g in
                    Text(g.rawValue).tag(g)
                }
            }.pickerStyle(.menu)
        }
        AuthFieldRow("Client ID") { TextField("Client ID", text: $config.clientID).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Client Secret") { SecureField("Client Secret", text: $config.clientSecret).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Authorization URL") { TextField("https://...", text: $config.authorizationURL).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Token URL") { TextField("https://...", text: $config.accessTokenURL).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Scope") { TextField("read write", text: $config.scope).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Redirect URI") { TextField("https://...", text: $config.redirectURI).textFieldStyle(.roundedBorder) }
        Toggle("Use PKCE", isOn: $config.usePKCE)
        Toggle("Auto-refresh on 401", isOn: $config.autoRefresh)

        if let token = config.storedToken {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Access token stored").font(.callout.weight(.medium))
                    Spacer()
                    if let expiry = token.expiresAt {
                        Text(token.isExpired ? "Expired" : "Expires in \(Int(expiry.timeIntervalSinceNow / 60))m")
                            .font(.caption)
                            .foregroundStyle(token.isExpired ? .red : .secondary)
                    }
                }
                Button("Revoke Token", role: .destructive) {
                    config.storedToken = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        } else {
            Button("Get New Access Token") {
                // Trigger OAuth flow
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - AWS V4 Form

private struct AWSV4Form: View {
    @Binding var config: AWSV4Config

    var body: some View {
        AuthFieldRow("Access Key") { TextField("AWS Access Key", text: $config.accessKey).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Secret Key") { SecureField("AWS Secret Key", text: $config.secretKey).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Session Token (optional)") { TextField("Session Token", text: $config.sessionToken).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Region") { TextField("us-east-1", text: $config.region).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Service") { TextField("execute-api", text: $config.serviceName).textFieldStyle(.roundedBorder) }
    }
}

// MARK: - NTLM Form

private struct NTLMForm: View {
    @Binding var config: NTLMConfig

    var body: some View {
        AuthFieldRow("Username") { TextField("Username", text: $config.username).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Password") { SecureField("Password", text: $config.password).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Domain") { TextField("DOMAIN", text: $config.domain).textFieldStyle(.roundedBorder) }
    }
}

// MARK: - Hawk Form

private struct HawkForm: View {
    @Binding var config: HawkConfig

    var body: some View {
        AuthFieldRow("Hawk Auth ID") { TextField("Auth ID", text: $config.authID).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Hawk Auth Key") { SecureField("Auth Key", text: $config.authKey).textFieldStyle(.roundedBorder) }
        AuthFieldRow("Algorithm") {
            Picker("", selection: $config.algorithm) {
                ForEach(HawkConfig.HawkAlgorithm.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }.pickerStyle(.segmented)
        }
    }
}

// MARK: - JWT Bearer Form

private struct JWTForm: View {
    @Binding var config: JWTConfig
    @State private var jwtPreview = ""

    var body: some View {
        AuthFieldRow("Algorithm") {
            Picker("", selection: $config.algorithm) {
                ForEach(JWTConfig.JWTAlgorithm.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }.pickerStyle(.segmented)
        }
        AuthFieldRow("Secret") { SecureField("JWT Secret", text: $config.secret).textFieldStyle(.roundedBorder) }
        Toggle("Secret is Base64 Encoded", isOn: $config.isBase64Encoded)
        AuthFieldRow("Payload (JSON)") {
            CodeEditorView(text: $config.payload, language: .json, fontSize: 12)
                .frame(height: 120)
                .cornerRadius(6)
        }
        AuthFieldRow("Add To") {
            Picker("", selection: $config.addTo) {
                Text("Header").tag(JWTConfig.JWTLocation.header)
                Text("Query Param").tag(JWTConfig.JWTLocation.queryParam)
            }.pickerStyle(.segmented)
        }
    }
}
