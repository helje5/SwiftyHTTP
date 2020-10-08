//
//  RawByteBuffer.swift
//  TestSwiftyCocoa
//
//  Created by Helge Hess on 6/20/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

open class RawByteBuffer {
  
  open var buffer   : UnsafeMutablePointer<UInt8>?
  open var capacity : Int
  open var count    : Int
  let extra = 2
  
  public init(capacity: Int) {
    count         = 0
    self.capacity = capacity
    
    if (self.capacity > 0) {
      buffer  = UnsafeMutablePointer<UInt8>.allocate(capacity: self.capacity + extra)
    }
    else {
      buffer = nil
    }
  }
  deinit {
    if capacity > 0 {
      buffer?.deallocate()
    }
  }
  
  open func asByteArray() -> [UInt8] {
    guard count > 0 else { return [] }
    
    // having to assign a value is slow
    var a = [UInt8](repeating: 0, count: count)
    
    memcpy(&a, self.buffer, self.count)
      // Note: In the Darwin pkg there is also:
      //   memcpy(UnsafePointer<Void>(a), buffer, UInt(self.count))
      // func memcpy(_: UnsafePointer<()>, _: ConstUnsafePointer<()>, _: UInt) -> UnsafePointer<()>
    
    return a
  }
  
  open func ensureCapacity(_ newCapacity: Int) {
    guard newCapacity > capacity else { return }
    
    let newsize = newCapacity + 1024
    let newbuf  = UnsafeMutablePointer<UInt8>.allocate(capacity: newsize + extra)
    
    if (count > 0) {
      memcpy(newbuf, buffer, count)
    }
    
    buffer?.deallocate()
    buffer   = newbuf
    capacity = newsize
  }
  
  open func reset() {
    count = 0
  }
  
  open func addBytes(_ src: UnsafeRawPointer, length: Int) {
    // debugPrint("add \(length) count: \(count) capacity: \(capacity)")
    guard length > 0 else {
      // This is fine, happens for empty bodies (like in OPTION requests)
      // debugPrint("NO LENGTH?")
      return
    }
    ensureCapacity(count + length)
    
    let dest = buffer! + count
    memcpy(UnsafeMutableRawPointer(dest), src, length)
    count += length
    // debugPrint("--- \(length) count: \(count) capacity: \(capacity)")
  }
  
  open func add(_ cs: UnsafePointer<CChar>, length: Int? = nil) {
    if let len = length {
      addBytes(cs, length: len)
    }
    else {
      addBytes(cs, length: Int(strlen(cs)))
    }
  }
  
  open func asString() -> String? {
    guard let buffer = buffer else { return nil }
    
    buffer[count] = 0 // null terminate, buffer is always bigger than it claims
    return String(cString: buffer)
  }
}
