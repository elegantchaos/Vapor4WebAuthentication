// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 01/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor
import Fluent

protocol TokenRepository {
    func all() -> EventLoopFuture<[UserToken]>
    func forUser(_ user: User) throws -> QueryBuilder<UserToken>
}

struct DatabaseTokenRepository: TokenRepository {
    let database: Database
    func all() -> EventLoopFuture<[UserToken]> {
        return UserToken.query(on: database).all()
    }
    
    func forUser(_ user: User) throws -> QueryBuilder<UserToken> {
        try UserToken.query(on: database).filter(\.$user.$id == user.requireID())
    }
}

struct TokenRepositoryFactory {
    var make: ((Request) -> TokenRepository)?
    mutating func use(_ make: @escaping ((Request) -> TokenRepository)) {
        self.make = make
    }
}

extension Application {
    private struct TokenRepositoryKey: StorageKey {
        typealias Value = TokenRepositoryFactory
    }

    var tokens: TokenRepositoryFactory {
        get {
            self.storage[TokenRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[TokenRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var tokens: TokenRepository {
        self.application.tokens.make!(self)
    }
}
