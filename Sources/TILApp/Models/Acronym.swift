//
//  Acronym.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 18/04/25.
//

import Fluent
import Vapor

final class Acronym: Model, @unchecked Sendable {
    static let schema = "acronyms"
    
    @ID
    var id: UUID?
    
    @Field(key: "short")
    var short: String
    
    @Field(key: "long")
    var long: String
    
    @Parent(key: "userID")
    var user: User
    
    @Siblings(through: AcronymCategoryPivot.self, from: \.$acronym, to: \.$category)
    var categories: [Category]
    
    init() { }
    
    init(id: UUID? = nil, short: String, long: String, userID: User.IDValue) {
        self.id = id
        self.short = short
        self.long = long
        self.$user.id = userID
    }

}
    
extension Acronym: Content {}
