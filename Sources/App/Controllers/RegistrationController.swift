// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor
import Fluent

struct RegistrationRequest: Content {
    let name: String
    let email: String
    let password: String
    let confirm: String
    
    func hash(with req: Request) -> EventLoopFuture<String> {
        return req.password.async.hash(password)
    }
}

extension RegistrationRequest: Validatable {
    static func decode(from req: Request) throws -> RegistrationRequest {
        try RegistrationRequest.validate(content: req)
        let request = try req.content.decode(RegistrationRequest.self)
        guard request.password == request.confirm else {
            throw AuthenticationError.passwordsDontMatch
        }
        return request
    }
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(4...))
    }
}

extension User {
    convenience init(from register: RegistrationRequest, hash: String) throws {
        self.init(name: register.name, email: register.email, passwordHash: hash)
    }
}

struct RegistrationController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("register", use: renderRegister)
        routes.post("register", use: handleRegister)
    }
    
    func renderRegister(req: Request) throws -> EventLoopFuture<Response> {
        let page = Page("register", meta: .init("Register", description: "Registration Page"))
        return page.render(with: req)
    }
    
    func handleRegister(_ req: Request) throws -> EventLoopFuture<Response> {
        let registration = try RegistrationRequest.decode(from: req)
        
        return registration.hash(with: req)
            .thenCreateUser(using: registration, with: req)
            .thenRedirect(with: req, to: "/login")
    }
    
}


fileprivate extension EventLoopFuture where Value == String {
    func thenCreateUser(using registration: RegistrationRequest, with req: Request) -> EventLoopFuture<Void>  {
        flatMapThrowing { hash in try User(from: registration, hash: hash) }
            .translatingError(to: AuthenticationError.emailAlreadyExists, if: { (error: DatabaseError) in error.isConstraintFailure })
            .flatMap { user in return user.create(on: req.db) }
    }
}
