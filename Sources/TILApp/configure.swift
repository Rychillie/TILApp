import NIOSSL
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import FluentMySQLDriver
import FluentMongoDriver
import Vapor
import Leaf

// configures your application
public func configure(_ app: Application) async throws {
    app.middleware.use(
        FileMiddleware(publicDirectory: app.directory.publicDirectory)
    )
    
    let databaseName: String
    let databasePort: Int
    
    if (app.environment == .testing) {
        databaseName = "vapor-test"
        databasePort = 5433
    } else {
        databaseName = "vapor_database"
        databasePort = 5432
    }

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: databasePort,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? databaseName,
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateAcronym())
    app.migrations.add(CreateCategory())
    app.migrations.add(CreateAcronymCategoryPivot())
    app.migrations.add(CreateToken())
    app.migrations.add(CreateAdminUser())
    
    app.logger.logLevel = .debug
    
    app.views.use(.leaf)
    
    try await app.autoMigrate()

    // register routes
    try routes(app)
}
