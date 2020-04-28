import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("login", use: renderLogin)
        routes.get("register", use: renderRegister)
        routes.get("profile", use: renderProfile)
        
        routes.post("register", use: performRegister)
        routes.post("login", use: performLogin)
    }
    
    func renderRegister(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("register")
    }
    
    func renderProfile(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("profile")
    }
    
    func renderLogin(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("login")
    }
    
    func performLogin(_ req: Request) throws -> EventLoopFuture<Response> {
        print("perform login")
        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
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
