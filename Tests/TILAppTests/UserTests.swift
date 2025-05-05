//
//  UserTests.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 21/04/25.
//

@testable import TILApp
import XCTVapor

final class UserTests: XCTestCase {
    let usersName = "Alice"
    let usersUsername = "alicea"
    let usersURI = "/api/users/"
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.testable()
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testUsersCanBeRetrievedFromAPI() async throws {
        let user = try await User.create(
            name: usersName,
            username: usersUsername,
            on: app.db
        )
        _ = try await User.create(on: app.db)
        
        try await app.test(.GET, usersURI) { response in
            XCTAssertEqual(response.status, .ok)
            let users = try await response.content.decode([User].self)
            
            XCTAssertEqual(users.count, 2)
            XCTAssertEqual(users[0].name, usersName)
            XCTAssertEqual(users[0].username, usersUsername)
            XCTAssertEqual(users[0].id, user.id)
        }
    }
    
    func testUserCanBeSavedWithAPI() async throws {
        let user = User(name: usersName, username: usersUsername)
        
        try await app.test(.POST, usersURI, beforeRequest: { req in
            try await req.content.encode(user)
        }, afterResponse: { response in
            let receivedUser = try await response.content.decode(User.self)
            
            XCTAssertEqual(receivedUser.name, usersName)
            XCTAssertEqual(receivedUser.username, usersUsername)
            XCTAssertNotNil(receivedUser.id)
            
            try await app.test(.GET, usersURI, afterResponse: { secondResponse in
                let users = try await secondResponse.content.decode([User].self)
                
                XCTAssertEqual(users.count, 1)
                XCTAssertEqual(users[0].name, usersName)
                XCTAssertEqual(users[0].username, usersUsername)
                XCTAssertEqual(users[0].id, receivedUser.id)
            })
        })
    }
    
    func testGettingASingleUserFromTheAPI() async throws {
        let user = try await User.create(
            name: usersName,
            username: usersUsername,
            on: app.db
        )
        
        try await app.test(.GET, "\(usersURI)\(user.id!)", afterResponse: { response in
            let receivedUser = try await response.content.decode(User.self)
            
            XCTAssertEqual(receivedUser.name, usersName)
            XCTAssertEqual(receivedUser.username, usersUsername)
            XCTAssertEqual(receivedUser.id, user.id)
        })
    }
    
    func testGettingAUsersAcronymsFromTheAPI() async throws {
        let user = try await User.create(on: app.db)
        
        let acronymShort = "OMG"
        let acronymLong = "Oh My God"
        
        let acronym1 = try await Acronym.create(
            short: acronymShort,
            long: acronymLong,
            user: user,
            on: app.db
        )
        
        _ = try await Acronym.create(
            short: "LOL",
            long: "Laughing Out Loud",
            user: user,
            on: app.db
        )
        
        try await app.test(.GET, "\(usersURI)\(user.id!)/acronyms", afterResponse: { response in
            let acronyms = try await response.content.decode([Acronym].self)
            
            XCTAssertEqual(acronyms.count, 2)
            XCTAssertEqual(acronyms[0].id, acronym1.id)
            XCTAssertEqual(acronyms[0].short, acronymShort)
            XCTAssertEqual(acronyms[0].long, acronymLong)
        })
    }
}
