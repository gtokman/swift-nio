//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A helper protocol that can be mixed in to a NIO ``EventLoop`` to provide an
/// automatic conformance to `SerialExecutor`.
///
/// Implementers of `EventLoop` should consider conforming to this protocol as
/// well on Swift 5.9 and later.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol NIOSerialEventLoopExecutor: EventLoop, SerialExecutor {}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension NIOSerialEventLoopExecutor {
    
    public func enqueue(_ job: consuming ExecutorJob) {
        // By default we are just going to use execute to run the job
        // this is quite heavy since it allocates the closure for
        // every single job.
        let unownedJob = UnownedJob(job)
        self.execute {
            unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: self)
    }

    
    public var executor: any SerialExecutor {
        self
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    
    public func isSameExclusiveExecutionContext(other: Self) -> Bool {
        other === self
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *)
    
    public func checkIsolated() {
        self.preconditionInEventLoop()
    }
}

/// A type that wraps a NIO ``EventLoop`` into a `SerialExecutor`
/// for use with Swift concurrency.
///
/// This type is not recommended for use because it risks problems with unowned
/// executors. Adopters are recommended to conform their own event loop
/// types to `SerialExecutor`.
final class NIODefaultSerialEventLoopExecutor {
    
    let loop: EventLoop

    
    init(_ loop: EventLoop) {
        self.loop = loop
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension NIODefaultSerialEventLoopExecutor: SerialExecutor {
    
    public func enqueue(_ job: consuming ExecutorJob) {
        self.loop.enqueue(job)
    }

    
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: self)

    }

    
    public func isSameExclusiveExecutionContext(other: NIODefaultSerialEventLoopExecutor) -> Bool {
        self.loop === other.loop
    }
}
