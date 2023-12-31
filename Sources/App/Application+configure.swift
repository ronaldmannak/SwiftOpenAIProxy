import AsyncHTTPClient
import Hummingbird
import Foundation

public protocol AppArguments {
    var location: String { get }
    var target: String { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_ args: AppArguments) async throws {
        
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        (self.encoder as! JSONEncoder).dateEncodingStrategy = .iso8601
        
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
        
        // Add logging middleware
        self.logger.logLevel = .info
        self.middleware.add(HBLogRequestsMiddleware(.info))
        
        // Add App attestation middleware
        let attestationController = AttestationController()
        attestationController.addRoutes(to: self.router.group("attestation"))
        self.middleware.add(AttestationMiddleware(attestationController: attestationController))        
        
        // Add non forwarding routing
        self.router.get("hello") { request in
            return "Hello"
        }
        
        // OpenAI API key middleware
        self.middleware.add(OpenAIKeyMiddleware())
        
        // Add Proxy middleware
        self.middleware.add(
            HBProxyServerMiddleware(
                httpClient: httpClient,
                proxy: .init(location: args.location, target: args.target)
            )
        )
    }
}

extension HBApplication {
    var httpClient: HTTPClient {
        get { self.extensions.get(\.httpClient) }
        set { self.extensions.set(\.httpClient, value: newValue) { httpClient in
            try httpClient.syncShutdown()
        }}
    }
}
