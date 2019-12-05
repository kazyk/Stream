//
//  Operators.swift
//  Stream
//
//  Created by kazuyuki takahashi on 2019/12/04.
//  Copyright © 2019 kazuyuki takahashi. All rights reserved.
//

import Foundation

extension Streams {
    struct Map<Source: Stream, Value>: Stream {
        typealias Error = Source.Error
        
        var source: Source
        var transform: (Source.Value) -> Value
        
        @discardableResult
        func subscribe<S>(_ subscriber: S) -> Disposable? where S : Subscriber, Error == S.Error, Value == S.Value {
            return source.subscribe(AnySubscriber { event in
                subscriber.send(event.mapValue(self.transform))
            })
        }
    }
}

extension Stream {
    func map<T>(_ transform: @escaping (Value) -> T) -> Streams.Map<Self, T> {
        return Streams.Map(source: self, transform: transform)
    }
}


extension Streams {
    struct Collect<Source: Stream>: Stream {
        typealias Value = [Source.Value]
        typealias Error = Source.Error
        
        var source: Source
        
        @discardableResult
        func subscribe<S>(_ subscriber: S) -> Disposable? where S : Subscriber, Error == S.Error, Value == S.Value {
            
            var values: Value = []
            
            return source.subscribe(AnySubscriber { event in
                switch event {
                case .value(let val):
                    values.append(val)
                case .failed(let err):
                    subscriber.send(.failed(err))
                case .completed:
                    subscriber.send(.value(values))
                    subscriber.send(.completed)
                case .disposed:
                    subscriber.send(.disposed)
                }
            })
        }
    }
}

extension Stream {
    func collect() -> Streams.Collect<Self> {
        return Streams.Collect(source: self)
    }
}
