//
//  Token.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 05/05/25.
//

import Vapor
import Fluent

final class Token: Model, Content, @unchecked Sendable {
    static let schema = "tokens"
    
    @ID
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "userID")
    var user: User
    
    init() {}
    
    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}

extension Token {
    static func generate(for user: User) throws -> Token {
        let random = [UInt8].random(count: 16).base64
        return try Token(value: random, userID: user.requireID())
    }
}

extension Token: ModelTokenAuthenticatable {
    static let valueKey: KeyPath<Token, Field<String>> = \.$value
    static let userKey: KeyPath<Token, Parent<User>> = \.$user
    
    typealias User = TILApp.User
    
    var isValid: Bool {
        true
    }
}
