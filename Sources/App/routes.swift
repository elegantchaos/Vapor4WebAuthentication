import Fluent
import Vapor

func routes(_ app: Application) throws {
    let controller = UserController()
    app.get("register", use: controller.register)
}
