// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 01/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Fluent
import Vapor

struct ProfilePage: LeafPage {
    var file: String
    var meta: PageMetadata
    let users: [User]
    let tokens: [Token]
    let sessions: [SessionRecord]
    
    init(user: User?, users: [User], tokens: [Token], sessions: [SessionRecord]) {
        let title: String
        let description: String
        if let user = user {
            title = "Logged in as \(user.name)."
            description = "Profile page for \(user.name)."
        } else {
            title = "Not Logged In"
            description = "Not Logged In"
        }

        self.file = "profile"
        self.meta = .init(title, description: description)
        self.users = users
        self.tokens = tokens
        self.sessions = sessions
    }
}

