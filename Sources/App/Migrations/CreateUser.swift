// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Fluent
import Vapor

extension User {
    struct Migration: Fluent.Migration {
        var name: String { "CreateUser" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(User.schema)
                .id()
                .field(.name, .string, .required)
                .field(.email, .string, .required)
                .field(.passwordHash, .string, .required)
                .unique(on: .name)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(User.schema).delete()
        }
    }
}
