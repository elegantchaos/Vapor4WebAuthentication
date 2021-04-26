// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Fluent
import Vapor

struct LoginRequest: Content {
    let email: String
    let password: String
    
    func findUser(with request: Request) throws -> EventLoopFuture<User> {
        let query = User.query(on: request.db).filter(\.$email == email).first()
        return query.unwrap(or: AuthenticationError.invalidEmailOrPassword)
    }
    
    func verifyUser(_ user: User, request: Request) -> EventLoopFuture<User> {
        let verifier = request.password.async.verify(password, created: user.passwordHash)
        return verifier
            .guard({ $0 == true }, else: AuthenticationError.invalidEmailOrPassword)
            .transform(to: user)
    }
}

extension LoginRequest: Validatable {
    static func decode(from req: Request) throws -> LoginRequest {
        try LoginRequest.validate(content: req)
        return try req.content.decode(LoginRequest.self)
    }
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct LoginController: RouteCollection {
    let sessionEnabled: RoutesBuilder

    func boot(routes: RoutesBuilder) throws {
        
        routes.get("login", use: renderLogin)
        sessionEnabled.post("login", use: handleLogin)
    }
    
    func renderLogin(_ req: Request) throws -> EventLoopFuture<Response> {
        let page = LoginPage()
        return page.render(with: req)
    }
    
    func handleLogin(_ req: Request) throws -> EventLoopFuture<Response> {
        let login = try LoginRequest.decode(from: req)
        do {
            return try login.findUser(with: req)
                .thenVerifyLogin(login, with: req)
                .thenRemoveTokens(with: req)
                .thenGenerateToken(with: req)
                .thenRedirect(with: req, to: "/")
                .flatMapError { error in
                    let page = LoginPage(request: login, error: error)
                    return page.render(with: req)
                }
        } catch {
            let page = Page("login", meta: .init("Login", description: "Login Page", error: String(describing: error)))
            return page.render(with: req)
        }
    }
}

fileprivate extension EventLoopFuture where Value: User {
    func thenVerifyLogin(_ login: LoginRequest, with req: Request) -> EventLoopFuture<User> {
        flatMap { user in login.verifyUser(user, request: req) }
    }
    
    func thenRemoveTokens(with req: Request) -> EventLoopFuture<User> {
        flatMap { user in
            do {
                return try req.tokens.forUser(user)
                    .delete()
                    .transform(to: user)
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    func thenGenerateToken(with req: Request) -> EventLoopFuture<Void> {
        flatMap { user in
            do {
                let token = try user.generateToken()
                return token
                    .create(on: req.db)
                    .map { req.session.authenticate(token) }
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
}

