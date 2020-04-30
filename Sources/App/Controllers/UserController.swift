import Fluent
import Vapor

struct UserController: RouteCollection {
    let app: Application
    
    func boot(routes: RoutesBuilder) throws {
        
        let sessionEnabled = routes.grouped(
            SessionsMiddleware(session: app.sessions.driver)
        )

        let sessionProtected = routes.grouped(
            SessionsMiddleware(session: app.sessions.driver),
            UserToken.sessionAuthenticator()
            //            UserToken.guardMiddleware()
        )

        routes.get("login", use: renderLogin)
        sessionEnabled.post("login", use: handleLogin)
        
        routes.get("register", use: renderRegister)
        routes.post("register", use: handleRegister)
        
        sessionProtected.get("", use: renderProfile)
        sessionProtected.get("logout", use: performLogout)
        
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
            var users: [User]
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
        
        return UserToken.query(on: req.db).all()
            .and(SessionRecord.query(on: req.db).all())
            .and(User.query(on: req.db).all())
            .flatMap { (tokensAndSessions, users) in
                let (tokens, sessions) = tokensAndSessions
                let context = Page(meta: .init(title: title, description: description), users: users, tokens: tokens, sessions: sessions)
                return req.view.render("profile", context)
        }
    }
    
    func renderLogin(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("login")
    }
    
    fileprivate func removeTokens(user: User, req: Request) -> EventLoopFuture<User> {
        do {
            return try UserToken.query(on: req.db)
                .filter(\.$user.$id == user.requireID())
                .delete()
                .transform(to: user)
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    fileprivate func generateToken(user: User, req: Request) -> EventLoopFuture<Void> {
        do {
            let token = try user.generateToken()
            return token.create(on: req.db)
                .map { req.session.authenticate(token) }
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    func handleLogin(_ req: Request) throws -> EventLoopFuture<Response> {
        try LoginRequest.validate(req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        return try loginRequest.findUser(request: req)
            .then { user in loginRequest.verify(request: req, matches: user) }
            .then { user in self.removeTokens(user: user, req: req) }
            .then { user in self.generateToken(user: user, req: req) }
            .thenRedirect(request: req) { "/" }
    }
    
    func handleRegister(_ req: Request) throws -> EventLoopFuture<Response> {
        print("perform register")
        
        try RegisterRequest.validate(req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirm else {
            throw AuthenticationError.passwordsDontMatch
        }

        return req.password
            .async
            .hash(registerRequest.password)
            .flatMapThrowing { try User(from: registerRequest, hash: $0) }
                .flatMapErrorThrowing {
                    if let dbError = $0 as? DatabaseError, dbError.isConstraintFailure {
                        throw AuthenticationError.emailAlreadyExists
                    }
                    throw $0
            }
            .flatMap { user in user.save(on: req.db) }
            .map { req.redirect(to: "/login") }
    }
    
    func performLogout(_ req: Request) throws -> Response {
        req.auth.logout(User.self)
        req.session.destroy()
        return req.redirect(to: "/login")
    }
}

extension LoginRequest {
    func findUser(request: Request) throws -> EventLoopFuture<User> {
        let query = User.query(on: request.db).filter(\.$email == email).first()
        return query.unwrap(or: AuthenticationError.invalidEmailOrPassword)
    }
    
    func verify(request: Request, matches user: User) -> EventLoopFuture<User> {
        let verifier = request.password.async.verify(password, created: user.passwordHash)
        return verifier
            .guard({ $0 == true }, else: AuthenticationError.invalidEmailOrPassword)
            .transform(to: user)
    }
}

infix operator ==> : LogicalConjunctionPrecedence
infix operator --> : LogicalConjunctionPrecedence
infix operator -!-> : LogicalConjunctionPrecedence

public extension EventLoopFuture {
    func then<NewValue>(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Value) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        flatMap(file: file, line: line, callback)
    }

    func thenRedirect(request: Request, to: () -> String) -> EventLoopFuture<Response> {
        map { _ in request.redirect(to: to()) }
    }
    
    static func --> <NewValue>(left: EventLoopFuture<Value>, right: @escaping (Value) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        left.flatMap(right)
    }

    static func ==> <NewValue>(left: EventLoopFuture<Value>, right: @escaping (Value) -> (NewValue)) -> EventLoopFuture<NewValue> {
        left.map(right)
    }
}

extension EventLoopFuture where Value: Vapor.OptionalType {
    static func -!-> (left: EventLoopFuture<Value>, right: @escaping () -> Error) -> EventLoopFuture<Value.WrappedType> {
        left.unwrap(or: right())
    }
}
