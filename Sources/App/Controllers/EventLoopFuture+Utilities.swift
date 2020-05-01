// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/04/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Vapor


public extension EventLoopFuture {
    func then<NewValue>(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Value) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        flatMap(file: file, line: line, callback)
    }

    func thenRedirect(with request: Request, to: String) -> EventLoopFuture<Response> {
        map { _ in request.redirect(to: to) }
    }

    func translatingError<ErrorType>(to error: Error, if condition: @escaping (ErrorType) -> Bool) -> EventLoopFuture<Value> {
        flatMapErrorThrowing {
            if let dbError = $0 as? ErrorType, condition(dbError) {
                throw error
            }
            throw $0
        }
    }
}



// Ok, I was experimenting with operators, I admit it. Move along please. Nothing to see here...

infix operator ==> : LogicalConjunctionPrecedence
infix operator --> : LogicalConjunctionPrecedence
infix operator -!-> : LogicalConjunctionPrecedence

public extension EventLoopFuture {
    static func --> <NewValue>(left: EventLoopFuture<Value>, right: @escaping (Value) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        left.flatMap(right)
    }

    static func ==> <NewValue>(left: EventLoopFuture<Value>, right: @escaping (Value) -> (NewValue)) -> EventLoopFuture<NewValue> {
        left.map(right)
    }
}

extension EventLoopFuture where Value: Vapor.OptionalType {
    static func -!-> (left: EventLoopFuture<Value>, right: @escaping () -> Error) -> EventLoopFuture<Value.WrappedType> {
        left.unwrap(or: right())
    }
}
