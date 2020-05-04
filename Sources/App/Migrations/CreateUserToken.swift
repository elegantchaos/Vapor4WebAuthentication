// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Fluent

extension Token {
    struct Migration: Fluent.Migration {
        var name: String { "CreateToken" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(Token.schema)
                .id()
                .field(.value, .string, .required)
                .field(.user, .uuid, .required, .references("users", "id"))
                .unique(on: .value)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(Token.schema).delete()
        }
    }
}
