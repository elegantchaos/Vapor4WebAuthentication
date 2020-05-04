// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Fluent
import Vapor

extension FieldKey {
    static var value: FieldKey { return "value" }
    static var user: FieldKey { return "user_id" }
}

final class Token: Model, Content {
    static let schema = "tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: .value)
    var value: String

    @Parent(key: .user)
    var user: User

    init() { }

    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}

extension Token: ModelSessionAuthenticatable {
}
