// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 01/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor

protocol LeafPage: Codable {
    var file: String { get }
    var meta: PageMetadata { get }
}

extension LeafPage {
    func render(with req: Request) -> EventLoopFuture<Response> {
        return req.view.render(file, self).encodeResponse(for: req)
    }
}

struct Page: LeafPage {
    let file: String
    let meta: PageMetadata
    
    init(_ file: String, meta: PageMetadata) {
        self.file = file
        self.meta = meta
    }
    
}
