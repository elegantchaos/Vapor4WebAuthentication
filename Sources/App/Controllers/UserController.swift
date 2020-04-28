import Fluent
import Vapor

struct UserController: RouteCollection {
    let app: Application
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("login", use: renderLogin)
        
        let sessionEnabled = routes.grouped(
            SessionsMiddleware(session: app.sessions.driver)
        )
        sessionEnabled.post("login", use: performLogin)
        
        routes.get("register", use: renderRegister)
        routes.post("register", use: performRegister)
        
        let sessionProtected = routes.grouped(
            SessionsMiddleware(session: app.sessions.driver),
            UserToken.sessionAuthenticator()
            //            UserToken.guardMiddleware()
        )
        sessionProtected.get("profile", use: renderProfile)
        
    }
    
    func renderRegister(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("register")
    }
    
    func renderProfile(_ req: Request) throws -> EventLoopFuture<View> {
        print("perform profile")
        
        let token = req.auth.get(UserToken.self)
        if let token = token {
            return token.$user.get(on: req.db)
                .flatMap { user -> EventLoopFuture<View> in
                    return self.renderProfilePage(req, for: user)
            }
        } else {
            return self.renderProfilePage(req)
        }
    }
    
    func tokenContent(req: Request) -> EventLoopFuture<String> {
        UserToken.query(on: req.db).all().and(SessionRecord.query(on: req.db).all())
            .map { (tokens, sessions) in
                let tokenString = tokens.map({  token in "<div>\(token.id!): \(token.value)</div>" }).joined(separator: "\n" )
                let sessionString = sessions.map({  session in "<div>\(session.id!): \(session.data)</div>" }).joined(separator: "\n" )
                return "<h2>Tokens</h2>\n\(tokenString)\n\n<h2>Sessions</h2>\n\(sessionString)"
        }
    }
    
    func renderProfilePage(_ req: Request, for user: User? = nil) -> EventLoopFuture<View> {
        struct Meta: Codable {
            var title: String
            var description: String
        }
        
        struct Page: Codable {
            var meta: Meta
            var tokens: [UserToken]
            var sessions: [SessionRecord]
        }
        
        let title: String
        let description: String
        if let user = user {
            title = "Logged in as \(user.name)."
            description = "Profile page for \(user.name)."
        } else {
            title = "Not Logged In"
            description = "Not Logged In"
        }
        
        return UserToken.query(on: req.db).all().and(SessionRecord.query(on: req.db).all())
            .flatMap { (tokens, sessions) in
                let context = Page(meta: .init(title: title, description: description), tokens: tokens, sessions: sessions)
                return req.view.render("profile", context)
        }
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
