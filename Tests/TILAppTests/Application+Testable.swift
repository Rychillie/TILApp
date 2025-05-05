//
//  Application+Testable.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 21/04/25.
//

import XCTVapor
import TILApp

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
