import Foundation
import Testing
@testable import SprocketKit

@Suite("Actions usage")
struct ActionsUsageTests {
    @Test("decodes GitHub billing response")
    func decodesBillingResponse() throws {
        let json = """
        {
          "total_minutes_used": 305,
          "total_paid_minutes_used": 0,
          "included_minutes": 3000,
          "minutes_used_breakdown": {
            "UBUNTU": 205,
            "MACOS": 10,
            "WINDOWS": 90
          }
        }
        """

        let usage = try JSONDecoder().decode(ActionsUsage.self, from: Data(json.utf8))

        #expect(usage.totalMinutesUsed == 305)
        #expect(usage.paidMinutesUsed == 0)
        #expect(usage.includedMinutes == 3_000)
        #expect(usage.breakdown["UBUNTU"] == 205)
        #expect(usage.breakdown["MACOS"] == 10)
        #expect(usage.breakdown["WINDOWS"] == 90)
    }

    @Test("calculates budget fraction and over-budget state")
    func budgetCalculations() {
        let under = ActionsUsage(totalMinutesUsed: 305, includedMinutes: 3_000, paidMinutesUsed: 0, breakdown: [:])
        #expect(abs(under.fraction - (305.0 / 3_000.0)) < 0.0001)
        #expect(!under.isOverBudget)

        let over = ActionsUsage(totalMinutesUsed: 3_250, includedMinutes: 3_000, paidMinutesUsed: 250, breakdown: [:])
        #expect(over.fraction > 1)
        #expect(over.isOverBudget)

        let unlimited = ActionsUsage(totalMinutesUsed: 100, includedMinutes: 0, paidMinutesUsed: 100, breakdown: [:])
        #expect(unlimited.fraction == 0)
    }

    @Test("billing access denial returns nil")
    func billingAccessDeniedReturnsNil() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/users/mattnz/settings/billing/actions")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: [
                    "X-RateLimit-Remaining": "4999",
                    "X-RateLimit-Limit": "5000",
                    "X-RateLimit-Reset": "1770000000",
                ]
            )!
            return (Data(#"{"message":"Resource not accessible by personal access token"}"#.utf8), response)
        }

        let client = GitHubClient(
            config: GitHubClientConfig(baseURL: URL(string: "https://api.example.test")!),
            session: session
        )

        let usage = try await client.fetchActionsUsage(for: "mattnz", isOrg: false)
        #expect(usage == nil)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
