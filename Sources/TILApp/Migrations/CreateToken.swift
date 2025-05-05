//
//  CreateToken.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 05/05/25.
//

import Fluent

struct CreateToken: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema("tokens")
            .id()
            .field("value", .string, .required)
            .field(
                "userID",
                .uuid,
                .required,
                .references("users", "id", onDelete: .cascade)
            )
            .create()
    }
    
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema("tokens").delete()
    }
}
