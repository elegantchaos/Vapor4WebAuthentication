import Fluent
import FluentPostgresDriver
//import FluentSQLiteDriver
import Vapor
import Leaf

// configures your application
public func configure(_ app: Application) throws {

    if let databaseURL = Environment.get("DATABASE_URL"), var postgresConfig = PostgresConfiguration(url: databaseURL) {
        postgresConfig.tlsConfiguration = .forClient(certificateVerification: .none)
        app.databases.use(.postgres(
            configuration: postgresConfig
        ), as: .psql)
    } else {
        app.databases.use(.postgres(hostname: "localhost", username: "vapor", password: "vapor", database: "cases"), as: .psql)
    }
    app.sessions.use(.fluent)
    
    app.migrations.add(User.Migration())
    app.migrations.add(Token.Migration())
    app.migrations.add(SessionRecord.migration)
    
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))     // serve files from /Public folder

    // Configure Leaf
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = app.environment.isRelease

    // register routes
    try routes(app)
    
    app.users.use { req in DatabaseUserRepository(database: req.db) }
    app.tokens.use { req in DatabaseTokenRepository(database: req.db) }

    if app.environment == .development {
        try app.autoMigrate().wait()
    }

}
