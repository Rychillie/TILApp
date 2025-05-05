//
//  Models+Testable.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 21/04/25.
//

@testable import TILApp
import Fluent

extension User {
    static func create(
        name: String = "Luke",
        username: String = "lukes",
        on database: Database
    ) async throws -> User {
        let user = User(name: name, username: username)
        try await user.create(on: database)
        return user
    }
}


extension Acronym {
    static func create(
        short: String = "TIL",
        long: String = "Today I Learned",
        user: User? = nil,
        on database: Database
    ) async throws -> Acronym {
        var acronymsUser = user
        
        if acronymsUser == nil {
            acronymsUser = try await User.create(on: database)
        }
        
        let acronym = Acronym(
            short: short,
            long: long,
            userID: acronymsUser!.id!
        )
        
        try acronym.save(on: database).wait()
        return acronym
    }
}

extension TILApp.Category {
    static func create(
        name: String = "Random",
        on database: Database
    ) async throws -> TILApp.Category {
        let category = Category(name: name)
        try await category.create(on: database)
        return category
    }
}
