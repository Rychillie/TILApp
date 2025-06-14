//
//  WebsiteController.swift
//  TILApp
//
//  Created by Rychillie Umpierre de Oliveira on 01/05/25.
//

import Fluent
import Leaf
import Vapor

struct WebsiteController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let authSessionsRoutes = routes.grouped(User.sessionAuthenticator())
        authSessionsRoutes.get("login", use: loginHandler)
        let credentialsAuthRoutes = authSessionsRoutes.grouped(User.credentialsAuthenticator())
        credentialsAuthRoutes.post("login", use: loginPostHandler)
        authSessionsRoutes.post("logout", use: logoutHandler)
        authSessionsRoutes.get("register", use: registerHandler)
        authSessionsRoutes.post("register", use: registerPostHandler)
        authSessionsRoutes.get(use: indexHandler)
        authSessionsRoutes.get("acronym", ":acronymID", use: acronymHandler)
        authSessionsRoutes.get("user", ":userID", use: userHandler)
        authSessionsRoutes.get("users", use: allUsersHandler)
        authSessionsRoutes.get("categories", use: allCategoriesHandler)
        authSessionsRoutes.get("category", ":categoryID", use: categoryHandler)
        
        let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.get("acronym", "create", use: createAcronymHandler)
        protectedRoutes.post("acronym", "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronym", ":acronymID", "edit", use: editAcronymHandler)
        protectedRoutes.post("acronym", ":acronymID", "edit", use: editAcronymPostHandler)
        protectedRoutes.post("acronym", ":acronymID", "delete", use: deleteAcronymHandler)
    }
    
    func indexHandler(_ req: Request) -> EventLoopFuture<View> {
        Acronym.query(on: req.db).all().flatMap { acronyms in
            let userLoggedIn = req.auth.has(User.self)
            let showCookieMessage = req.cookies["cookies-accepted"] == nil
            let context = IndexContext(
                title: "Home page",
                acronyms: acronyms,
                userLoggedIn: userLoggedIn,
                showCookieMessage: showCookieMessage
            )
            
            return req.view.render("index", context)
        }
    }
    
    func acronymHandler(_ req: Request) -> EventLoopFuture<View> {
        Acronym.find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { acronym in
                acronym.$user.get(on: req.db).flatMap { user in
                    let userFuture = acronym.$user.get(on: req.db)
                    let categoriesFuture = acronym.$categories.query(on: req.db).all()
                    return userFuture.and(categoriesFuture).flatMap { user, categories in
                        let context = AcronymContext(
                            title: acronym.short,
                            acronym: acronym,
                            user: user,
                            categories: categories
                        )
                        return req.view.render("acronym", context)
                    }
                }
            }
    }
    
    func userHandler(_ req: Request) -> EventLoopFuture<View> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                user.$acronyms.get(on: req.db).flatMap { acronyms in
                    let context = UserContext(
                        title: user.name,
                        user: user,
                        acronyms: acronyms
                    )
                    return req.view.render("user", context)
                }
            }
    }
    
    func allUsersHandler(_ req: Request) -> EventLoopFuture<View> {
        User.query(on: req.db).all().flatMap { users in
            let context = AllUsersContext(
                title: "All Users",
                users: users
            )
            return req.view.render("allUsers", context)
        }
    }
    
    func allCategoriesHandler(_ req: Request) -> EventLoopFuture<View> {
        Category.query(on: req.db).all().flatMap { categories in
            let context = AllCategoriesContext(categories: categories)
            return req.view.render("allCategories", context)
        }
    }
    
    func categoryHandler(_ req: Request) -> EventLoopFuture<View> {
        Category.find(req.parameters.get("categoryID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { category in
                category.$acronyms.get(on: req.db).flatMap { acronyms in
                    let context = CategoryContext(
                        title: category.name,
                        category: category,
                        acronyms: acronyms
                    )
                    return req.view.render("category", context)
                }
            }
    }
    
    func createAcronymHandler(_ req: Request) -> EventLoopFuture<View> {
        User.query(on: req.db).all().flatMap { users in
            let token = [UInt8].random(count: 16).base64
            let context = CreateAcronymContext(csrfToken: token)
            req.session.data["CSRF_TOKEN"] = token
            return req.view.render("createAcronym", context)
        }
    }
    
    func createAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let data = try req.content.decode(CreateAcronymFormData.self)
        let user = try req.auth.require(User.self)
        let expectedToken = req.session.data["CSRF_TOKEN"]
        req.session.data["CSRF_TOKEN"] = nil
        
        guard let csrfToken = data.csrfToken,
              expectedToken == csrfToken else {
            throw Abort(.badRequest)
        }
        
        let acronym = try Acronym(
            short: data.short,
            long: data.long,
            userID: user.requireID(),
        )
        
        return acronym.save(on: req.db).flatMap {
            guard let id = acronym.id else {
                return req.eventLoop.future(error: Abort(.internalServerError))
            }
            
            var categorySaves: [EventLoopFuture<Void>] = []
            
            for category in data.categories ?? [] {
                categorySaves.append(
                    Category.addCategory(
                        category,
                        to: acronym,
                        on: req
                    )
                )
            }
            
            let redirect = req.redirect(to: "/acronym/\(id)")
            
            return categorySaves.flatten(on: req.eventLoop)
                .transform(to: redirect)
        }
    }
    
    func editAcronymHandler(_ req: Request) -> EventLoopFuture<View> {
        return Acronym.find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.$categories.get(on: req.db).flatMap { categories in
                    let context = EditAcronymContext(
                        acronym: acronym,
                        categories: categories
                    )
                    return req.view.render("createAcronym", context)
                }
            }
    }
    
    func editAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let updateData = try req.content.decode(CreateAcronymFormData.self)
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        return Acronym.find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.short = updateData.short
                acronym.long = updateData.long
                acronym.$user.id = userID
                
                guard let id = acronym.id else {
                    return req.eventLoop.future(error: Abort(.internalServerError))
                }
                
                return acronym.save(on: req.db).flatMap {
                    acronym.$categories.get(on: req.db)
                }.flatMap { existingCategories in
                    let existingStringArray = existingCategories.map {
                        $0.name
                    }
                    
                    let existingSet = Set<String>(existingStringArray)
                    let newSet = Set<String>(updateData.categories ?? [])
                    
                    let categoriesToAdd = newSet.subtracting(existingSet)
                    let categoriesToRemove = existingSet.subtracting(newSet)
                    
                    var categoryResults: [EventLoopFuture<Void>] = []
                    
                    for newCategory in categoriesToAdd {
                        categoryResults.append(
                            Category.addCategory(
                                newCategory,
                                to: acronym,
                                on: req
                            )
                        )
                    }
                    
                    for categoryNameToRemove in categoriesToRemove {
                        let categoryToRemove = existingCategories.first {
                            $0.name == categoryNameToRemove
                        }
                        
                        if let category = categoryToRemove {
                            categoryResults.append(
                                acronym.$categories.detach(category, on: req.db)
                            )
                        }
                    }
                    
                    let redirect = req.redirect(to: "/acronym/\(id)")
                    return categoryResults.flatten(on: req.eventLoop)
                        .transform(to: redirect)
                }
            }
    }
    
    func deleteAcronymHandler(_ req: Request) -> EventLoopFuture<Response> {
        Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.delete(on: req.db)
                    .transform(to: req.redirect(to: "/"))
            }
    }
    
    func loginHandler(_ req: Request) -> EventLoopFuture<View> {
        let context: LoginContext
        
        if let error = req.query[Bool.self, at: "error"], error {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        
        return req.view.render("login", context)
    }
    
    func loginPostHandler(_ req: Request) -> EventLoopFuture<Response> {
        if req.auth.has(User.self) {
            return req.eventLoop.future(req.redirect(to: "/"))
        } else {
            let context = LoginContext(loginError: true)
            return req.view.render("login", context).encodeResponse(for: req)
        }
    }
    
    func logoutHandler(_ req: Request) -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/")
    }
    
    func registerHandler(_ req: Request) -> EventLoopFuture<View> {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return req.view.render("register", context)
    }
    
    func registerPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        do {
            try RegisterData.validate(content: req)
        } catch let error as ValidationsError {
            let message = error.description.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? "Unknown error"
            let redirect = req.redirect(to: "/register?message=\(message)")
            return req.eventLoop.future(redirect)
        }
        let data = try req.content.decode(RegisterData.self)
        let password = try Bcrypt.hash(data.password)
        
        let user = User(name: data.name, username: data.username, password: password)
        
        return user.save(on: req.db).map {
            req.auth.login(user)
            return req.redirect(to: "/")
        }
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: [Category]
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: [Category]
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: [Acronym]
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
    let editing = true
    let categories: [Category]
}

struct CreateAcronymFormData: Content {
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
}

extension RegisterData: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: .ascii)
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("zipCode", as: String.self, is: .zipCode, required: false)
    }
}

extension ValidatorResults {
    struct ZipCode {
        let isValidZipCode: Bool
    }
}

extension ValidatorResults.ZipCode: ValidatorResult {
    var isFailure: Bool {
        !isValidZipCode
    }
    
    var successDescription: String? {
        "is a valid zip code"
    }
    
    var failureDescription: String? {
        "is not a valid zip code"
    }
}

extension Validator where T == String {
    private static var zipCodeRegex: String {
        "^\\d{5}(?:[-\\s]\\d{4})?$"
    }
    
    public static var zipCode: Validator<T> {
        Validator { input -> any ValidatorResult in
            guard let range = input.range(
                of: zipCodeRegex,
                options: [.regularExpression]
            ), range.lowerBound == input.startIndex && range.upperBound == input.endIndex else {
                return ValidatorResults.ZipCode(isValidZipCode: false)
            }
            return ValidatorResults.ZipCode(isValidZipCode: true)
        }
    }
}
