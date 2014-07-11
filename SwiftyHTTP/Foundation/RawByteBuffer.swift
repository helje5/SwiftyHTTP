//
//  RawByteBuffer.swift
//  TestSwiftyCocoa
//
//  Created by Helge Hess on 6/20/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

class RawByteBuffer {
  
  var buffer   : UnsafePointer<RawByte>
  var capacity : Int
  var count    : Int
  let extra    = 2
  
  init(capacity: Int) {
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
  
  func asByteArray() -> [UInt8] {
    if count == 0 {
      return []
    }
    
    // having to assign a value is slow
    var a = [UInt8](count: count, repeatedValue: 0)
    
    a.withUnsafePointerToElements {
      // Note: In the Darwin pkg there is also:
      //   memcpy(UnsafePointer<Void>(a), buffer, UInt(self.count))
      // func memcpy(_: UnsafePointer<()>, _: ConstUnsafePointer<()>, _: UInt) -> UnsafePointer<()>

      memcpy(UnsafePointer<Void>($0),
             UnsafePointer<Void>(self.buffer),
             UInt(self.count))
    }
    
    return a
  }
  
  func ensureCapacity(newCapacity: Int) {
    if newCapacity > capacity {
      let newsize = newCapacity + 1024
      var newbuf  = UnsafePointer<RawByte>.alloc(newsize + extra)
      
      if (count > 0) {
        memcpy(UnsafePointer<Void>(newbuf),
               UnsafePointer<Void>(buffer),
               UInt(count))
      }
      
      buffer.dealloc(capacity + extra)
      buffer   = newbuf
      capacity = newsize
    }
  }
  
  func reset() {
    count = 0
  }
  
  func add(src: UnsafePointer<Void>, length: Int) {
    // println("add \(length) count: \(count) capacity: \(capacity)")
    if length < 1 {
      println("NO LENGTH?")
      return
    }
    ensureCapacity(count + length)
    
    let dest = buffer + count
    memcpy(UnsafePointer<Void>(dest),
           UnsafePointer<Void>(src),
           UInt(length))
    count += length
    // println("--- \(length) count: \(count) capacity: \(capacity)")
  }
  
  func add(cs: CString, length: UInt? = nil) {
    if length < 1 {
      return
    }
    let csbuf : [CChar] = cs.persist()!
    csbuf.withUnsafePointerToElements { ( p ) -> Void in
      var len : Int
      if let l = length {
        len = Int(l)
      }
      else {
        len = csbuf.count // w/ or w/o 0?
      }
      self.add(UnsafePointer<Void>(p), length: len)
    }
  }
  
  func asString() -> String? {
    if buffer == nil {
      return nil
    }
    
    let cptr = UnsafePointer<CChar>(buffer)
    cptr[count] = 0 // null terminate, buffer is always bigger than it claims
    return String.fromCString(CString(cptr))
  }
}
