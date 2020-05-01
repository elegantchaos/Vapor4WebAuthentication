// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 01/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor
import Fluent

protocol UserRepository {
    func all() -> EventLoopFuture<[User]>
}

struct DatabaseUserRepository: UserRepository {
    let database: Database
    func all() -> EventLoopFuture<[User]> {
        return User.query(on: database).all()
    }
}

struct UserRepositoryFactory {
    var make: ((Request) -> UserRepository)?
    mutating func use(_ make: @escaping ((Request) -> UserRepository)) {
        self.make = make
    }
}

extension Application {
    private struct UserRepositoryKey: StorageKey {
        typealias Value = UserRepositoryFactory
    }

    var users: UserRepositoryFactory {
        get {
            self.storage[UserRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[UserRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var users: UserRepository {
        self.application.users.make!(self)
    }
}
