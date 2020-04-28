import Fluent
import FluentSQLiteDriver
import Vapor
import Leaf

// configures your application
public func configure(_ app: Application) throws {
    // serve files from /Public folder
     app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(User.Migration())

    // Configure Leaf
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = app.environment.isRelease

    // register routes
    try routes(app)
    
    if app.environment == .development {
        try app.autoMigrate().wait()
    }

}
