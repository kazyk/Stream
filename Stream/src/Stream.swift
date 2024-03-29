//
//  File.swift
//  Stream
//
//  Created by kazuyuki takahashi on 2019/12/04.
//  Copyright © 2019 kazuyuki takahashi. All rights reserved.
//

import Foundation

enum StreamEvent<Value, Error: Swift.Error> {
    case value(Value)
    case completed
    case failed(Error)
    case disposed
    
    func mapValue<T>(_ transform: (Value) -> T) -> StreamEvent<T, Error> {
        switch self {
        case .value(let val):
            return .value(transform(val))
        case .failed(let err):
            return .failed(err)
        case .completed:
            return .completed
        case .disposed:
            return .disposed
        }
    }
}

protocol Subscriber {
    associatedtype Value
    associatedtype Error: Swift.Error
    func send(_ event: StreamEvent<Value, Error>)
}

struct AnySubscriber<Value, Error: Swift.Error>: Subscriber {
    var onEvent: (StreamEvent<Value, Error>) -> Void
    
    func send(_ event: StreamEvent<Value, Error>) {
        onEvent(event)
    }
}

protocol Disposable {
    func dispose()
}

class DisposableBase: Disposable {
    private(set) var disposed = false
    
    func disposeImpl() {
    }
    
    final func dispose() {
        if !disposed {
            disposeImpl()
        }
        disposed = true
    }
}

final class BlockDisposable: DisposableBase {
    private let block: () -> Void
    
    init(_ block: @escaping () -> Void) {
        self.block = block
    }
    
    override func disposeImpl() {
        block()
    }
}

final class CompositeDisposable: DisposableBase {
    private var disposables: [Disposable] = []
    
    func add(_ disposable: Disposable?) {
        guard let disposable = disposable else {
            return
        }
        if disposed {
            disposable.dispose()
        } else {
            disposables.append(disposable)
        }
    }
    
    override func disposeImpl() {
        for d in disposables {
            d.dispose()
        }
    }
}

final class Subscription<S: Subscriber>: Subscriber, Disposable {
    private var subscriber: S?
    private var disposed = false
    
    init(subscriber: S) {
        self.subscriber = subscriber
    }
    
    func send(_ event: StreamEvent<S.Value, S.Error>) {
        subscriber?.send(event)
        switch event {
        case .completed, .failed, .disposed:
            subscriber = nil
            dispose()
        default:
            break
        }
    }
    
    var streamDisposable: Disposable? {
        didSet {
            if disposed, let dispo = streamDisposable {
                dispo.dispose()
                streamDisposable = nil
            }
        }
    }
    
    func dispose() {
        if !disposed {
            subscriber?.send(.disposed)
            subscriber = nil
            streamDisposable?.dispose()
            streamDisposable = nil
            disposed = true
        }
    }
}


protocol Stream {
    associatedtype Value
    associatedtype Error: Swift.Error
    
    @discardableResult
    func subscribe<S: Subscriber>(_ subscriber: S) -> Disposable? where S.Value == Self.Value, S.Error == Self.Error
}

extension Stream {
    @discardableResult
    func subscribe(_ onEvent: @escaping (StreamEvent<Value, Error>) -> Void) -> Disposable? {
        return self.subscribe(AnySubscriber(onEvent: onEvent))
    }
    
    @discardableResult
    func subscribe(value: ((Value) -> Void)? = nil, failed: ((Error) -> Void)? = nil, completed: (() -> Void)? = nil, disposed: (() -> Void)? = nil) -> Disposable? {
        return self.subscribe(AnySubscriber { event in
            switch event {
            case .value(let val):
                if let value = value {
                    value(val)
                }
            case .failed(let err):
                if let failed = failed {
                    failed(err)
                }
            case .completed:
                if let completed = completed {
                    completed()
                }
            case .disposed:
                if let disposed = disposed {
                    disposed()
                }
            }
        })
    }
}

struct BasicStream<Value, Error: Swift.Error>: Stream {
    typealias OnEvent = (StreamEvent<Value, Error>) -> Void
    var startStream: (@escaping OnEvent) -> Disposable?
    
    @discardableResult
    func subscribe<S>(_ subscriber: S) -> Disposable? where S : Subscriber, Error == S.Error, Value == S.Value {
        let sub = Subscription(subscriber: subscriber)
        sub.streamDisposable = startStream(sub.send)
        return sub
    }
}

struct AnyStream<Value, Error: Swift.Error>: Stream {
    typealias OnEvent = (StreamEvent<Value, Error>) -> Void
    var startStream: (@escaping OnEvent) -> Disposable?
    
    @discardableResult
    func subscribe<S>(_ subscriber: S) -> Disposable? where S : Subscriber, Error == S.Error, Value == S.Value {
        return startStream(subscriber.send)
    }
}

struct Streams {}

extension Streams {
    struct Just<Value>: Stream {
        typealias Error = Never
        
        var value: Value
        
        @discardableResult
        func subscribe<S>(_ subscriber: S) -> Disposable? where S : Subscriber, Error == S.Error, Value == S.Value {
            subscriber.send(.value(value))
            subscriber.send(.completed)
            return nil
        }
    }
}
