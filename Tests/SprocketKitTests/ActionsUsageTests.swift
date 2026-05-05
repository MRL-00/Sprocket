import Foundation
import Testing
@testable import SprocketKit

@Suite("Actions usage", .serialized)
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

    @Test("aggregates multiple billing accounts")
    func aggregatesMultipleAccounts() throws {
        let personal = ActionsUsage(
            totalMinutesUsed: 7,
            includedMinutes: 2_000,
            paidMinutesUsed: 0,
            breakdown: ["UBUNTU": 7]
        )
        let org = ActionsUsage(
            totalMinutesUsed: 412,
            includedMinutes: 3_000,
            paidMinutesUsed: 12,
            breakdown: ["UBUNTU": 200, "MACOS": 212]
        )

        let aggregate = try #require(ActionsUsage.aggregate([personal, org]))
        #expect(aggregate.totalMinutesUsed == 419)
        #expect(aggregate.includedMinutes == 5_000)
        #expect(aggregate.paidMinutesUsed == 12)
        #expect(aggregate.breakdown["UBUNTU"] == 207)
        #expect(aggregate.breakdown["MACOS"] == 212)
        #expect(ActionsUsage.aggregate([]) == nil)
    }

    @Test("billing access denial returns nil")
    func billingAccessDeniedReturnsNil() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/users/mattnz/settings/billing/usage/summary")
            #expect(request.url?.query == "product=actions")
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

    @Test("decodes current billing usage summary endpoint")
    func decodesBillingUsageSummaryEndpoint() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/users/mattnz/settings/billing/usage/summary")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "X-RateLimit-Remaining": "4999",
                    "X-RateLimit-Limit": "5000",
                    "X-RateLimit-Reset": "1770000000",
                ]
            )!
            let body = """
            {
              "timePeriod": { "year": 2026, "month": 5 },
              "user": "mattnz",
              "product": "Actions",
              "usageItems": [
                {
                  "product": "Actions",
                  "sku": "actions_linux",
                  "grossQuantity": 7.0,
                  "discountQuantity": 7.0,
                  "netQuantity": 0.0,
                  "grossAmount": 0.042,
                  "discountAmount": 0.042,
                  "netAmount": 0.0,
                  "pricePerUnit": 0.006,
                  "unitType": "minutes"
                },
                {
                  "product": "Actions",
                  "sku": "actions_macos",
                  "grossQuantity": 2.2,
                  "netQuantity": 1.2,
                  "unitType": "minutes"
                }
              ]
            }
            """
            return (Data(body.utf8), response)
        }

        let client = GitHubClient(
            config: GitHubClientConfig(baseURL: URL(string: "https://api.example.test")!),
            session: session
        )

        let usage = try #require(try await client.fetchActionsUsage(for: "mattnz", isOrg: false))
        #expect(usage.totalMinutesUsed == 10)
        #expect(usage.includedMinutes == 2_000)
        #expect(usage.paidMinutesUsed == 2)
        #expect(usage.breakdown["UBUNTU"] == 7)
        #expect(usage.breakdown["MACOS"] == 3)
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
