//
//  StreamTests.swift
//  StreamTests
//
//  Created by kazuyuki takahashi on 2019/12/04.
//  Copyright © 2019 kazuyuki takahashi. All rights reserved.
//

import XCTest
@testable import Stream

class StreamTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testJust() {
        let exp = expectation(description: "")
        let sub = AnySubscriber<Int, Never> { e in
            switch e {
            case .value(let val):
                XCTAssertEqual(val, 100)
            case .completed:
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        
        Streams.Just(value: 100).subscribe(sub)
        wait(for: [exp], timeout: 0.1)
    }

    func testSequential() {
        var i = 0
        
        let exp = expectation(description: "")
        let sub = AnySubscriber<Int, Never> { e in
            switch e {
            case .value(let val):
                i += 100
                XCTAssertEqual(val, i)
            case .completed:
                XCTAssertEqual(i, 300)
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        
        BasicStream<Int, Never> { send in
            send(.value(100))
            send(.value(200))
            send(.value(300))
            send(.completed)
            return nil
        }.subscribe(sub)
        wait(for: [exp], timeout: 0.1)
    }
    
    func testAsync() {
        var i = 0
        let exp = expectation(description: "")
        let sub = AnySubscriber<Int, Never> { e in
            switch e {
            case .value(let val):
                i += 100
                XCTAssertEqual(val, i)
            case .completed:
                XCTAssertEqual(i, 300)
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        
        BasicStream<Int, Never> { send in
            var n = 0
            let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                n += 100
                send(.value(n))
                if n == 300 {
                    send(.completed)
                    timer.invalidate()
                }
            }
            return BlockDisposable {
                timer.invalidate()
            }
        }.subscribe(sub)
        wait(for: [exp], timeout: 0.5)
    }
    
    func testAsyncDispose() {
        let exp = expectation(description: "")
        let sub = AnySubscriber<Int, Never> { e in
            switch e {
            case .value(let val):
                XCTAssertEqual(val, 0)
            case .completed, .failed:
                XCTFail()
            case .disposed:
                exp.fulfill()
            }
        }
        
        BasicStream<Int, Never> { send in
            var n = 0
            send(.value(n))
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                n += 100
                send(.value(n))
                if n == 300 {
                    send(.completed)
                    timer.invalidate()
                }
            }
            return BlockDisposable {
                timer.invalidate()
            }
            }.subscribe(sub)?.dispose()
        wait(for: [exp], timeout: 1.0)
    }
    
    func testCollect() {
        let exp = expectation(description: "")
        let sub = AnySubscriber<[Int], Never> { e in
            switch e {
            case .value(let val):
                XCTAssertEqual(val, [100, 200, 300])
            case .completed:
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        
        BasicStream<Int, Never> { send in
            send(.value(100))
            send(.value(200))
            send(.value(300))
            send(.completed)
            return nil
        }.collect().subscribe(sub)
        wait(for: [exp], timeout: 0.1)
    }
    
    func testMap() {
        let exp = expectation(description: "")
        let sub = AnySubscriber<[Int], Never> { e in
            switch e {
            case .value(let val):
                XCTAssertEqual(val, [101, 201, 301])
            case .completed:
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        
        BasicStream<Int, Never> { send in
            send(.value(100))
            send(.value(200))
            send(.value(300))
            send(.completed)
            return nil
        }.map({ n in n + 1 }).collect().subscribe(sub)
        wait(for: [exp], timeout: 0.1)
    }
    

}