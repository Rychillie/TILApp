//
//  CreateAcronym.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 18/04/25.
//

import Vapor
import Fluent

struct CreateAcronym: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema("acronyms")
            .id()
            .field("short", .string, .required)
            .field("long", .string, .required)
            .field("userID", .uuid, .required, .references("users", "id"))
            .create()
    }
    
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema("acronyms").delete()
    }
}
    
