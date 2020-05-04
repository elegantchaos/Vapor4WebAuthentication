import Fluent
import Vapor

struct UserController: RouteCollection {
    let sessionProtected: RoutesBuilder
    
    func boot(routes: RoutesBuilder) throws {
        sessionProtected.get("", use: renderProfile)
        sessionProtected.get("logout", use: performLogout)
    }

    func renderProfile(_ req: Request) throws -> EventLoopFuture<Response> {
        let token = req.auth.get(Token.self)
        if let token = token {
            return token.$user.get(on: req.db)
                .flatMap { user in self.renderProfilePage(req, for: user) }
        } else {
            return self.renderProfilePage(req)
        }
    }
    
    func renderProfilePage(_ req: Request, for user: User? = nil) -> EventLoopFuture<Response> {
        return req.tokens.all()
            .and(SessionRecord.query(on: req.db).all())
            .and(req.users.all())
            .flatMap { (tokensAndSessions, users) in
                let (tokens, sessions) = tokensAndSessions
                let page = ProfilePage(user: user, users: users, tokens: tokens, sessions: sessions)
                return page.render(with: req)
        }
    }
    
      func performLogout(_ req: Request) throws -> Response {
        req.auth.logout(User.self)
        req.session.destroy()
        return req.redirect(to: "/login")
    }
}
