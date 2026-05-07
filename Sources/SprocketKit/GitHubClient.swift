import Foundation

public struct GitHubClientConfig: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.github.com")!
    public static let defaultUserAgent = "Sprocket/0.1"

    public var baseURL: URL
    public var userAgent: String
    public var clientID: String?

    public init(
        baseURL: URL = Self.defaultBaseURL,
        userAgent: String = Self.defaultUserAgent,
        clientID: String? = nil
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.clientID = clientID
    }
}

/// URLSession-based GitHub client.
///
/// The client keeps a small in-memory conditional-request cache so polling can
/// send `If-None-Match` and reuse the previous decoded payload when GitHub
/// replies with `304 Not Modified`.
public actor GitHubClient {
    public var config: GitHubClientConfig
    private let session: URLSession
    private var token: String?
    private var etags: [URL: String] = [:]
    private var responseCache: [URL: Data] = [:]
    private(set) public var rateLimit: RateLimit?

    public init(config: GitHubClientConfig = .init(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func setToken(_ token: String?) {
        guard self.token != token else { return }
        self.token = token
        clearConditionalCache()
    }

    public func setClientID(_ id: String?) {
        config.clientID = id
    }

    public func setBaseURL(_ url: URL) {
        guard config.baseURL != url else { return }
        config.baseURL = url
        clearConditionalCache()
    }

    public func setUserAgent(_ userAgent: String) {
        config.userAgent = userAgent
    }

    // MARK: - Device flow

    public struct DeviceCode: Sendable, Codable {
        public let deviceCode: String
        public let userCode: String
        public let verificationURI: URL
        public let expiresIn: Int
        public let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    public struct AccessTokenResponse: Sendable, Codable {
        public let accessToken: String?
        public let tokenType: String?
        public let scope: String?
        public let refreshToken: String?
        public let expiresIn: Int?
        public let error: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case scope
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case error
        }
    }

    public func requestDeviceCode(scope: String = "repo workflow read:org user") async throws -> DeviceCode {
        guard let clientID = config.clientID else { throw AuthError.other("Missing Client ID") }
        var req = URLRequest(url: oauthURL(path: "/login/device/code"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = "client_id=\(clientID)&scope=\(scope.replacingOccurrences(of: " ", with: "%20"))".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        let dec = JSONDecoder()
        return try dec.decode(DeviceCode.self, from: data)
    }

    public func pollAccessToken(deviceCode: String) async throws -> AccessTokenResponse {
        guard let clientID = config.clientID else { throw AuthError.other("Missing Client ID") }
        var req = URLRequest(url: oauthURL(path: "/login/oauth/access_token"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        let body = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        let resp = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
        if let err = resp.error {
            switch err {
            case "authorization_pending": throw AuthError.authorizationPending
            case "slow_down":              throw AuthError.slowDown
            case "expired_token":          throw AuthError.expiredToken
            case "access_denied":          throw AuthError.accessDenied
            case "unsupported_grant_type": throw AuthError.unsupportedGrantType
            case "incorrect_client_credentials": throw AuthError.incorrectClientCredentials
            default: throw AuthError.other(err)
            }
        }
        return resp
    }

    // MARK: - User / repos / runs (skeleton)

    public func currentUser() async throws -> GitHubUser {
        let req = makeRequest(path: "/user")
        let data = try await fetch(req)
        struct U: Decodable { let login: String; let name: String?; let id: Int; let avatar_url: URL? }
        let u = try JSONDecoder().decode(U.self, from: data)
        return GitHubUser(login: u.login, name: u.name, avatarHue: u.id % 360, avatarURL: u.avatar_url)
    }

    /// `/user/repos?sort=pushed&per_page=N`. Returns repos that have pushed activity recently.
    public func listRepos(perPage: Int = 20) async throws -> [Repository] {
        let req = makeRequest(path: "/user/repos?sort=pushed&per_page=\(perPage)&affiliation=owner,collaborator,organization_member")
        let data = try await fetch(req)
        struct R: Decodable {
            let id: Int64
            let full_name: String
            let archived: Bool
            let fork: Bool
            let owner: Owner
            struct Owner: Decodable { let login: String }
        }
        let arr = try JSONDecoder().decode([R].self, from: data)
        return arr.map {
            Repository(id: $0.id, fullName: $0.full_name, org: $0.owner.login,
                       isArchived: $0.archived, isFork: $0.fork,
                       watching: true, muted: false)
        }
    }

    /// `/repos/{owner}/{repo}/actions/runs?per_page=N`. Decodes recent workflow runs.
    public func listRuns(repo: Repository, perPage: Int = 5) async throws -> [WorkflowRun] {
        let req = makeRequest(path: "/repos/\(repo.fullName)/actions/runs?per_page=\(perPage)")
        let data = try await fetch(req)
        struct Envelope: Decodable { let workflow_runs: [Raw] }
        struct Raw: Decodable {
            let id: Int64
            let name: String?
            let display_title: String?
            let head_branch: String?
            let event: String?
            let status: String?
            let conclusion: String?
            let run_number: Int?
            let run_started_at: Date?
            let updated_at: Date?
            let html_url: URL
            let actor: Actor?
            struct Actor: Decodable { let login: String; let id: Int; let avatar_url: URL? }
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let env = try dec.decode(Envelope.self, from: data)
        return env.workflow_runs.map { r in
            let started = r.run_started_at ?? r.updated_at ?? Date()
            let updated = r.updated_at ?? started
            return WorkflowRun(
                id: r.id,
                repo: repo.fullName,
                workflowName: r.name ?? "Workflow",
                displayTitle: r.display_title ?? "",
                branch: r.head_branch ?? "",
                event: r.event ?? "",
                status: RunStatus(rawValue: r.status ?? "") ?? .completed,
                conclusion: r.conclusion.flatMap { RunConclusion(rawValue: $0) },
                runNumber: r.run_number ?? 0,
                actor: r.actor?.login ?? "",
                actorHue: (r.actor?.id ?? 0) % 360,
                actorAvatarURL: r.actor?.avatar_url,
                startedAt: started,
                updatedAt: updated,
                durationSeconds: max(0, Int(updated.timeIntervalSince(started))),
                htmlURL: r.html_url
            )
        }
    }

    // MARK: - Run actions

    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun`. Re-queues every job in the run.
    public func rerunRun(repo: String, runID: Int64) async throws {
        try await postAction(path: "/repos/\(repo)/actions/runs/\(runID)/rerun")
    }

    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun-failed-jobs`. Re-queues only the failed jobs.
    public func rerunFailedJobs(repo: String, runID: Int64) async throws {
        try await postAction(path: "/repos/\(repo)/actions/runs/\(runID)/rerun-failed-jobs")
    }

    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel`. Cancels an in-progress run.
    public func cancelRun(repo: String, runID: Int64) async throws {
        try await postAction(path: "/repos/\(repo)/actions/runs/\(runID)/cancel")
    }

    private func postAction(path: String) async throws {
        var req = makeRequest(path: path)
        req.httpMethod = "POST"
        // Conditional GET cache doesn't apply to mutations.
        req.setValue(nil, forHTTPHeaderField: "If-None-Match")
        let (data, resp) = try await session.data(for: req)
        absorbRateLimit(resp)
        try check(resp, data: data)
    }

    // MARK: - Jobs

    /// `/repos/{owner}/{repo}/actions/runs/{run_id}/jobs`. Decodes per-job status for a run.
    public func listJobs(repo: String, runID: Int64) async throws -> [WorkflowJob] {
        let req = makeRequest(path: "/repos/\(repo)/actions/runs/\(runID)/jobs")
        let data = try await fetch(req)
        struct Envelope: Decodable { let jobs: [Raw] }
        struct Raw: Decodable {
            let id: Int64
            let run_id: Int64
            let name: String
            let status: String?
            let conclusion: String?
            let started_at: Date?
            let completed_at: Date?
            let html_url: URL?
            let steps: [RawStep]?
        }
        struct RawStep: Decodable {
            let name: String
            let status: String?
            let conclusion: String?
            let number: Int?
            let started_at: Date?
            let completed_at: Date?
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let env = try dec.decode(Envelope.self, from: data)
        let now = Date()
        return env.jobs.map { j in
            let started = j.started_at ?? now
            // For in-progress jobs, measure against `now` so callers don't see
            // a frozen "0s" duration; completed jobs use their `completed_at`.
            let completed = j.completed_at ?? now
            let steps: [WorkflowStep] = (j.steps ?? []).map { s in
                WorkflowStep(
                    number: s.number ?? 0,
                    name: s.name,
                    status: RunStatus(rawValue: s.status ?? "") ?? .completed,
                    conclusion: s.conclusion.flatMap { RunConclusion(rawValue: $0) },
                    startedAt: s.started_at,
                    completedAt: s.completed_at
                )
            }
            return WorkflowJob(
                id: j.id,
                runID: j.run_id,
                name: j.name,
                status: RunStatus(rawValue: j.status ?? "") ?? .completed,
                conclusion: j.conclusion.flatMap { RunConclusion(rawValue: $0) },
                startedAt: started,
                completedAt: j.completed_at,
                durationSeconds: max(0, Int(completed.timeIntervalSince(started))),
                htmlURL: j.html_url,
                steps: steps
            )
        }
    }

    public func fetchActionsUsage(for owner: String, isOrg: Bool) async throws -> ActionsUsage? {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let summaryPath = isOrg
            ? "/orgs/\(encodedOwner)/settings/billing/usage/summary?product=actions"
            : "/users/\(encodedOwner)/settings/billing/usage/summary?product=actions"
        let req = makeRequest(path: summaryPath)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if http.statusCode == 403 || http.statusCode == 404 {
            absorbRateLimit(resp)
            return nil
        }
        if http.statusCode == 410 {
            return try await fetchLegacyActionsUsage(for: encodedOwner, isOrg: isOrg)
        }
        try check(resp, data: data)
        absorbRateLimit(resp)
        return try decodeActionsUsageSummary(data, isOrg: isOrg)
    }

    private func fetchLegacyActionsUsage(for encodedOwner: String, isOrg: Bool) async throws -> ActionsUsage? {
        let path = isOrg
            ? "/orgs/\(encodedOwner)/settings/billing/actions"
            : "/users/\(encodedOwner)/settings/billing/actions"
        let req = makeRequest(path: path)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if http.statusCode == 403 || http.statusCode == 404 || http.statusCode == 410 {
            absorbRateLimit(resp)
            return nil
        }
        try check(resp, data: data)
        absorbRateLimit(resp)
        return try JSONDecoder().decode(ActionsUsage.self, from: data)
    }

    private func decodeActionsUsageSummary(_ data: Data, isOrg: Bool) throws -> ActionsUsage {
        struct Summary: Decodable {
            let usageItems: [Item]

            struct Item: Decodable {
                let product: String?
                let sku: String?
                let unitType: String?
                let grossQuantity: Double?
                let netQuantity: Double?
                let quantity: Double?
            }
        }

        let summary = try JSONDecoder().decode(Summary.self, from: data)
        var total = 0.0
        var paid = 0.0
        var breakdown: [String: Double] = [:]

        for item in summary.usageItems where item.unitType?.lowercased() == "minutes" {
            let used = item.grossQuantity ?? item.quantity ?? 0
            let paidUsed = item.netQuantity ?? 0
            // GitHub charges included-minute quota in Linux-equivalent units:
            // macOS minutes count 10x and Windows minutes count 2x against the
            // included allowance. Sum the weighted total so the displayed
            // usage matches what GitHub bills against the quota.
            let multiplier = actionsRunnerMultiplier(for: item.sku)
            total += used * multiplier
            paid += paidUsed * multiplier
            // The breakdown is shown to the user as "raw minutes per runner",
            // so keep it un-weighted.
            breakdown[actionsRunnerKey(for: item.sku), default: 0] += used
        }

        return ActionsUsage(
            totalMinutesUsed: Int(total.rounded(.up)),
            includedMinutes: isOrg ? 3_000 : 2_000,
            paidMinutesUsed: Int(paid.rounded(.up)),
            breakdown: breakdown.mapValues { Int($0.rounded(.up)) }
        )
    }

    private func actionsRunnerKey(for sku: String?) -> String {
        let normalized = (sku ?? "").lowercased()
        if normalized.contains("macos") || normalized.contains("mac") { return "MACOS" }
        if normalized.contains("windows") { return "WINDOWS" }
        return "UBUNTU"
    }

    /// GitHub Actions billing multipliers against included-minute quota.
    /// See https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions#minute-multipliers
    private func actionsRunnerMultiplier(for sku: String?) -> Double {
        switch actionsRunnerKey(for: sku) {
        case "MACOS": return 10
        case "WINDOWS": return 2
        default: return 1
        }
    }

    private func makeRequest(path: String) -> URLRequest {
        var req = URLRequest(url: URL(string: config.baseURL.absoluteString + path)!)
        // GitHub returns `Cache-Control: private, max-age=60` on Actions endpoints,
        // so the default URLSession cache silently serves stale data and polling
        // never sees new runs. Force a network round-trip every time; our own
        // ETag cache still lets unchanged responses come back cheaply as 304s.
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let etag = etags[req.url!] { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return req
    }

    private func fetch(_ req: URLRequest) async throws -> Data {
        guard let url = req.url else { throw AuthError.invalidResponse }
        let (data, resp) = try await session.data(for: req)
        absorbRateLimit(resp)

        guard let http = resp as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if http.statusCode == 304 {
            guard let cached = responseCache[url] else {
                throw AuthError.other("HTTP 304 without cached response")
            }
            return cached
        }

        try check(resp, data: data)
        absorbETag(resp, data: data)
        return data
    }

    private func absorbETag(_ resp: URLResponse, data: Data) {
        guard let http = resp as? HTTPURLResponse,
              let url = http.url,
              let etag = http.value(forHTTPHeaderField: "ETag") else { return }
        etags[url] = etag
        responseCache[url] = data
    }

    private func clearConditionalCache() {
        etags.removeAll()
        responseCache.removeAll()
    }

    private func oauthURL(path: String) -> URL {
        let api = config.baseURL
        if api.host == "api.github.com" {
            return URL(string: "https://github.com\(path)")!
        }
        var components = URLComponents(url: api, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = nil
        return components.url!
    }

    private func check(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.other("HTTP \(http.statusCode): \(body.prefix(200))")
        }
    }

    private func absorbRateLimit(_ resp: URLResponse) {
        guard let http = resp as? HTTPURLResponse else { return }
        // GitHub serves headers lowercase over HTTP/2 — `allHeaderFields[...]`
        // is case-sensitive in Swift and silently misses, so we use
        // `value(forHTTPHeaderField:)` which is case-insensitive.
        guard let remainingStr = http.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
              let remaining = Int(remainingStr) else { return }
        let limit = http.value(forHTTPHeaderField: "X-RateLimit-Limit").flatMap(Int.init) ?? 5_000
        let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init)
            .map { Date(timeIntervalSince1970: $0) } ?? Date()
        rateLimit = RateLimit(limit: limit, remaining: remaining, resetAt: reset)
    }
}
