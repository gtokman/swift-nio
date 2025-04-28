//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#elseif os(Windows)
import ucrt
#elseif canImport(Bionic)
@preconcurrency import Bionic
#else
#error("The Heap module was unable to identify your C library.")
#endif


internal struct Heap<Element: Comparable> {
    
    internal private(set) var storage: [Element]

    
    internal init() {
        self.storage = []
    }

    
    internal func comparator(_ lhs: Element, _ rhs: Element) -> Bool {
        // This heap is always a min-heap.
        lhs < rhs
    }

    // named `PARENT` in CLRS
    
    internal func parentIndex(_ i: Int) -> Int {
        (i - 1) / 2
    }

    // named `LEFT` in CLRS
    
    internal func leftIndex(_ i: Int) -> Int {
        2 * i + 1
    }

    // named `RIGHT` in CLRS
    
    internal func rightIndex(_ i: Int) -> Int {
        2 * i + 2
    }

    // named `MAX-HEAPIFY` in CLRS
    
    mutating func _heapify(_ index: Int) {
        let left = self.leftIndex(index)
        let right = self.rightIndex(index)

        var root: Int
        if left <= (self.storage.count - 1) && self.comparator(storage[left], storage[index]) {
            root = left
        } else {
            root = index
        }

        if right <= (self.storage.count - 1) && self.comparator(storage[right], storage[root]) {
            root = right
        }

        if root != index {
            self.storage.swapAt(index, root)
            self._heapify(root)
        }
    }

    // named `HEAP-INCREASE-KEY` in CRLS
    
    mutating func _heapRootify(index: Int, key: Element) {
        var index = index
        if self.comparator(storage[index], key) {
            fatalError("New key must be closer to the root than current key")
        }

        self.storage[index] = key
        while index > 0 && self.comparator(self.storage[index], self.storage[self.parentIndex(index)]) {
            self.storage.swapAt(index, self.parentIndex(index))
            index = self.parentIndex(index)
        }
    }

    
    internal mutating func append(_ value: Element) {
        var i = self.storage.count
        self.storage.append(value)
        while i > 0 && self.comparator(self.storage[i], self.storage[self.parentIndex(i)]) {
            self.storage.swapAt(i, self.parentIndex(i))
            i = self.parentIndex(i)
        }
    }

    @discardableResult
    
    internal mutating func removeRoot() -> Element? {
        self._remove(index: 0)
    }

    @discardableResult
    
    internal mutating func remove(value: Element) -> Bool {
        if let idx = self.storage.firstIndex(of: value) {
            self._remove(index: idx)
            return true
        } else {
            return false
        }
    }

    @discardableResult
    
    internal mutating func removeFirst(where shouldBeRemoved: (Element) throws -> Bool) rethrows -> Element? {
        guard self.storage.count > 0 else {
            return nil
        }

        guard let index = try self.storage.firstIndex(where: shouldBeRemoved) else {
            return nil
        }

        return self._remove(index: index)
    }

    @discardableResult
    
    mutating func _remove(index: Int) -> Element? {
        guard self.storage.count > 0 else {
            return nil
        }
        let element = self.storage[index]
        if self.storage.count == 1 || self.storage[index] == self.storage[self.storage.count - 1] {
            self.storage.removeLast()
        } else if !self.comparator(self.storage[index], self.storage[self.storage.count - 1]) {
            self._heapRootify(index: index, key: self.storage[self.storage.count - 1])
            self.storage.removeLast()
        } else {
            self.storage[index] = self.storage[self.storage.count - 1]
            self.storage.removeLast()
            self._heapify(index)
        }
        return element
    }
}

extension Heap: CustomDebugStringConvertible {
    
    var debugDescription: String {
        guard self.storage.count > 0 else {
            return "<empty heap>"
        }
        let descriptions = self.storage.map { String(describing: $0) }
        let maxLen: Int = descriptions.map { $0.count }.max()!  // storage checked non-empty above
        let paddedDescs = descriptions.map { (desc: String) -> String in
            var desc = desc
            while desc.count < maxLen {
                if desc.count % 2 == 0 {
                    desc = " \(desc)"
                } else {
                    desc = "\(desc) "
                }
            }
            return desc
        }

        var all = "\n"
        let spacing = String(repeating: " ", count: maxLen)
        func subtreeWidths(rootIndex: Int) -> (Int, Int) {
            let lcIdx = self.leftIndex(rootIndex)
            let rcIdx = self.rightIndex(rootIndex)
            var leftSpace = 0
            var rightSpace = 0
            if lcIdx < self.storage.count {
                let sws = subtreeWidths(rootIndex: lcIdx)
                leftSpace += sws.0 + sws.1 + maxLen
            }
            if rcIdx < self.storage.count {
                let sws = subtreeWidths(rootIndex: rcIdx)
                rightSpace += sws.0 + sws.1 + maxLen
            }
            return (leftSpace, rightSpace)
        }
        for (index, desc) in paddedDescs.enumerated() {
            let (leftWidth, rightWidth) = subtreeWidths(rootIndex: index)
            all += String(repeating: " ", count: leftWidth)
            all += desc
            all += String(repeating: " ", count: rightWidth)

            func height(index: Int) -> Int {
                Int(log2(Double(index + 1)))
            }
            let myHeight = height(index: index)
            let nextHeight = height(index: index + 1)
            if myHeight != nextHeight {
                all += "\n"
            } else {
                all += spacing
            }
        }
        all += "\n"
        return all
    }
}


struct HeapIterator<Element: Comparable>: IteratorProtocol {
    
    var _heap: Heap<Element>

    
    init(heap: Heap<Element>) {
        self._heap = heap
    }

    
    mutating func next() -> Element? {
        self._heap.removeRoot()
    }
}

extension Heap: Sequence {
    
    var startIndex: Int {
        self.storage.startIndex
    }

    
    var endIndex: Int {
        self.storage.endIndex
    }

    
    var underestimatedCount: Int {
        self.storage.count
    }

    
    func makeIterator() -> HeapIterator<Element> {
        HeapIterator(heap: self)
    }

    
    subscript(position: Int) -> Element {
        self.storage[position]
    }

    
    func index(after i: Int) -> Int {
        i + 1
    }

    
    var count: Int {
        self.storage.count
    }
}

extension Heap: Sendable where Element: Sendable {}
extension HeapIterator: Sendable where Element: Sendable {}
