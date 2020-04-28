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
                    self.tokenContent(req: req).flatMap { contentString -> EventLoopFuture<View> in
                        return self.renderProfile(req, name: user.name, content: contentString)
                    }
            }
        } else {
            return self.tokenContent(req: req).flatMap { contentString -> EventLoopFuture<View> in
                return self.renderProfile(req, name: nil, content: contentString)
            }
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
    
    func renderProfile(_ req: Request, name: String?, content: String) -> EventLoopFuture<View> {
        struct Meta: Codable {
            var title: String
            var description: String
        }

        struct PageBody: Codable {
            var content: String
        }

        struct Page: Codable {
             var meta: Meta
             var body: PageBody
         }

        let title: String
        let description: String
        if let name = name {
           title = "Logged in as \(name)."
            description = "Profile page for \(name)."
        } else {
            title = "Not Logged In"
            description = "Not Logged In"
        }

        let context = Page(meta: .init(title: title, description: description), body: .init(content: content))
        return req.view.render("page", context)
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
