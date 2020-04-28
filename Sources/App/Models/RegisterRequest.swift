// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor

struct RegisterRequest: Content {
    let email: String
    let password: String
}

extension RegisterRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
//        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension User {
    convenience init(from register: RegisterRequest, hash: String) throws {
        self.init(name: "Blah", email: register.email, passwordHash: hash)
    }
}
