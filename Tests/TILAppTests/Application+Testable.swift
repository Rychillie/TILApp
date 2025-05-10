//
//  Application+Testable.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 21/04/25.
//

@testable import TILApp
@testable import XCTVapor

extension Application {
    static func testable() async throws -> Application {
        let app = try await Application.make(.testing)
        
        try await configure(app)
        try await app.autoMigrate().get()
        try await app.autoRevert().get()
        try await app.autoMigrate().get()
        
        return app
    }
}

extension XCTApplicationTester {
    public func login(user: User) throws -> Token {
        var request = XCTHTTPRequest(
            method: .POST,
            url: .init(path: "/api/users/login"),
            headers: [:],
            body: ByteBufferAllocator().buffer(capacity: 0)
        )
        request.headers.basicAuthorization = .init(username: user.username, password: "password")
        let response = try performTest(request: request)
        return try response.content.decode(Token.self)
    }
    
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: (XCTHTTPResponse) throws -> () = { _ in },
    ) throws -> any XCTApplicationTester {
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        
        if (loggedInRequest || loggedInUser != nil) {
            let userToLogin: User
            
            if let user = loggedInUser {
                userToLogin = user
            } else {
                userToLogin = User(
                    name: "Admin",
                    username: "admin",
                    password: "password"
                )
            }
            
            let token = try login(user: userToLogin)
            request.headers.bearerAuthorization = .init(token: token.value)
        }
        
        try beforeRequest(&request)
        
        do {
            let response = try performTest(request: request)
            try afterResponse(response)
        } catch {
            XCTFail("\(error)", file: file, line: line)
            throw error
        }
        
        return self
    }
}
