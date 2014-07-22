//
//  RawByteBuffer.swift
//  TestSwiftyCocoa
//
//  Created by Helge Hess on 6/20/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

public class RawByteBuffer {
  
  public var buffer   : UnsafePointer<RawByte>
  public var capacity : Int
  public var count    : Int
  let extra = 2
  
  public init(capacity: Int) {
    count         = 0
    self.capacity = capacity
    
    if (self.capacity > 0) {
      buffer  = UnsafePointer<RawByte>.alloc(self.capacity + extra)
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
    if count == 0 {
      return []
    }
    
    // having to assign a value is slow
    var a = [UInt8](count: count, repeatedValue: 0)
    
    a.withUnsafePointerToElements {
      // Note: In the Darwin pkg there is also:
      //   memcpy(UnsafePointer<Void>(a), buffer, UInt(self.count))
      // func memcpy(_: UnsafePointer<()>, _: ConstUnsafePointer<()>, _: UInt) -> UnsafePointer<()>

      memcpy($0, self.buffer,  UInt(self.count))
    }
    
    return a
  }
  
  public func ensureCapacity(newCapacity: Int) {
    if newCapacity > capacity {
      let newsize = newCapacity + 1024
      var newbuf  = UnsafePointer<RawByte>.alloc(newsize + extra)
      
      if (count > 0) {
        memcpy(newbuf, buffer, UInt(count))
      }
      
      buffer.dealloc(capacity + extra)
      buffer   = newbuf
      capacity = newsize
    }
  }
  
  public func reset() {
    count = 0
  }
  
  public func addBytes(src: ConstUnsafePointer<Void>, length: Int) {
    // println("add \(length) count: \(count) capacity: \(capacity)")
    if length < 1 {
      println("NO LENGTH?")
      return
    }
    ensureCapacity(count + length)
    
    let dest = buffer + count
    memcpy(UnsafePointer<Void>(dest), src, UInt(length))
    count += length
    // println("--- \(length) count: \(count) capacity: \(capacity)")
  }
  
  public func add(cs: ConstUnsafePointer<CChar>, length: Int? = nil) {
    if let len = length {
      addBytes(cs, length: len)
    }
    else {
      addBytes(cs, length: Int(strlen(cs)))
    }
  }
  
  public func asString() -> String? {
    if buffer == nil {
      return nil
    }
    
    let cptr = UnsafePointer<CChar>(buffer)
    cptr[count] = 0 // null terminate, buffer is always bigger than it claims
    return String.fromCString(cptr)
  }
}
