import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("login", use: renderLogin)
        routes.get("register", use: renderRegister)
        routes.get("profile", use: renderProfile)
        
        routes.post("register", use: register)
        routes.post("login", use: login)
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
    
    func login(_ req: Request) throws -> EventLoopFuture<Response> {
        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
    }
    
    func register(_ req: Request) throws -> EventLoopFuture<Response> {
        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
    }
}
