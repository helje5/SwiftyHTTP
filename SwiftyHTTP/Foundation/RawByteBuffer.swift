//
//  RawByteBuffer.swift
//  TestSwiftyCocoa
//
//  Created by Helge Hess on 6/20/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

public class RawByteBuffer {
  
  public var buffer   : UnsafeMutablePointer<RawByte>
  public var capacity : Int
  public var count    : Int
  let extra = 2
  
  public init(capacity: Int) {
    count         = 0
    self.capacity = capacity
    
    if (self.capacity > 0) {
      buffer  = UnsafeMutablePointer<RawByte>.alloc(self.capacity + extra)
    }
    else {
      buffer = nil
    }
  }
  deinit {
    if capacity > 0 {
      buffer.dealloc(capacity + extra)
    }
  }
  
  public func asByteArray() -> [UInt8] {
    guard count > 0 else { return [] }
    
    // having to assign a value is slow
    var a = [UInt8](count: count, repeatedValue: 0)
    
    memcpy(&a, self.buffer, self.count)
      // Note: In the Darwin pkg there is also:
      //   memcpy(UnsafePointer<Void>(a), buffer, UInt(self.count))
      // func memcpy(_: UnsafePointer<()>, _: ConstUnsafePointer<()>, _: UInt) -> UnsafePointer<()>
    
    return a
  }
  
  public func ensureCapacity(newCapacity: Int) {
    guard newCapacity > capacity else { return }
    
    let newsize = newCapacity + 1024
    let newbuf  = UnsafeMutablePointer<RawByte>.alloc(newsize + extra)
    
    if (count > 0) {
      memcpy(newbuf, buffer, count)
    }
    
    buffer.dealloc(capacity + extra)
    buffer   = newbuf
    capacity = newsize
  }
  
  public func reset() {
    count = 0
  }
  
  public func addBytes(src: UnsafePointer<Void>, length: Int) {
    // debugPrint("add \(length) count: \(count) capacity: \(capacity)")
    guard length > 0 else {
      // This is fine, happens for empty bodies (like in OPTION requests)
      // debugPrint("NO LENGTH?")
      return
    }
    ensureCapacity(count + length)
    
    let dest = buffer + count
    memcpy(UnsafeMutablePointer<Void>(dest), src, length)
    count += length
    // debugPrint("--- \(length) count: \(count) capacity: \(capacity)")
  }
  
  public func add(cs: UnsafePointer<CChar>, length: Int? = nil) {
    if let len = length {
      addBytes(cs, length: len)
    }
    else {
      addBytes(cs, length: Int(strlen(cs)))
    }
  }
  
  public func asString() -> String? {
    guard buffer != nil else { return nil }
    
    let cptr = UnsafeMutablePointer<CChar>(buffer)
    cptr[count] = 0 // null terminate, buffer is always bigger than it claims
    return String.fromCString(cptr)
  }
}
