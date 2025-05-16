//
//  User.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 19/04/25.
//

import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "username")
    var username: String
    
    @Field(key: "password")
    var password: String
    
    @Children(for: \.$user)
    var acronyms: [Acronym]
    
    init() { }
    
    init(id: UUID? = nil, name: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.username = username
        self.password = password
    }
    
    final class Public: Content, @unchecked Sendable {
        var id: UUID?
        var name: String
        var username: String
        
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension EventLoopFuture where Value: User {
    func convertToPublic() -> EventLoopFuture<User.Public> {
        return self.map { user in
            return user.convertToPublic()
        }
    }
}

extension Collection where Element: User {
    func convertToPublic() -> [User.Public] {
        return self.map { $0.convertToPublic() }
    }
}

extension EventLoopFuture where Value == Array<User> {
    func convertToPublic() -> EventLoopFuture<[User.Public]> {
        return self.map { $0.convertToPublic() }
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey: KeyPath<User, Field<String>> = \.$username
    static let passwordHashKey: KeyPath<User, Field<String>> = \.$password
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

extension User: ModelSessionAuthenticatable {}

extension User: ModelCredentialsAuthenticatable {}
