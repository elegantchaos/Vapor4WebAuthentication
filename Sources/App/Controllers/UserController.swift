import Fluent
import Vapor

struct UserController: RouteCollection {
    let app: Application
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("login", use: renderLogin)
        
        let sessionEnabled = routes.grouped(
            app.sessions.middleware)
        sessionEnabled.post("login", use: performLogin)

        routes.get("register", use: renderRegister)
        routes.post("register", use: performRegister)
        
        let sessionProtected = routes.grouped(
            app.sessions.middleware,
            UserToken.sessionAuthenticator(),
//            UserSessionAuthenticator(),
            UserToken.guardMiddleware()
        )
        sessionProtected.get("profile", use: renderProfile)

    }
    
    func renderRegister(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("register")
    }
    
    func renderProfile(_ req: Request) throws -> EventLoopFuture<View> {

        struct Index: Codable {
            var title: String
            var description: String
        }

        struct Page: Codable {
            var content: String
        }

        struct Context: Codable {
             var index: Index
             var page: Page
         }

        print("perform profile")

        let token = try req.auth.require(UserToken.self)
        let context = Context(index: .init(title: "My page", description: "This is my Page"),
                              page: .init(content: "Welcome to my page \(token.$user)!"))
        
        return req.view.render("profile", context)
    }
    
    func renderLogin(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("login")
    }
    
    func performLogin(_ req: Request) throws -> EventLoopFuture<Response> {
        print("perform login")

        try LoginRequest.validate(req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        return User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first()
            .unwrap(or: AuthenticationError.invalidEmailOrPassword)
            .flatMap { user -> EventLoopFuture<User> in
                return req.password
                    .async
                    .verify(loginRequest.password, created: user.passwordHash)
                    .guard({ $0 == true }, else: AuthenticationError.invalidEmailOrPassword)
                    .transform(to: user)
            }
            .flatMap { user -> EventLoopFuture<UserToken> in
                do {
                    let token = try user.generateToken()
                    return token.create(on: req.db).transform(to: token)
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
            .map { token -> Response in
                req.session.authenticate(token)
                return req.redirect(to: "/profile")
            }
    }
    
    func performRegister(_ req: Request) throws -> EventLoopFuture<Response> {
        print("perform register")
        
        try RegisterRequest.validate(req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        return req.password
            .async
            .hash(registerRequest.password)
            .flatMapThrowing { try User(from: registerRequest, hash: $0) }
            .flatMap { user in user.save(on: req.db) }
            .map { req.redirect(to: "/login") }
    }
}
