import Fluent
import Vapor

func routes(_ app: Application) throws {
     let sessionEnabled = app.grouped(
         SessionsMiddleware(session: app.sessions.driver)
     )

     let sessionProtected = app.grouped(
         SessionsMiddleware(session: app.sessions.driver),
         Token.sessionAuthenticator()
         //            UserToken.guardMiddleware()
     )
    
    try app.register(collection: LoginController(sessionEnabled: sessionEnabled))
    try app.register(collection: UserController(sessionProtected: sessionProtected))
    try app.register(collection: RegistrationController())
}
