
struct LoginPage: LeafPage {
    var file: String
    var meta: PageMetadata
    let request: LoginRequest?
    
    init(request: LoginRequest? = nil, error: Error? = nil) {
        self.file = "login"
        self.meta = .init("Login", description: "Login", error: error?.localizedDescription)
        self.request = request
    }
}
