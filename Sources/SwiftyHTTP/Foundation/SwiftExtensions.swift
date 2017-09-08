//
//  SwiftExtensions.swift
//  TestSwiftyCocoa
//
//  Created by Helge Heß on 6/18/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

// Hack to compare values if we don't have access to the members of the struct,
// eg http_errno in v0.0.4
public func isByteEqual<T>(_ lhs: T, rhs: T) -> Bool {
  var vLhs = lhs, vRhs = rhs // sigh, needs var below
  return memcmp(&vLhs, &vRhs, MemoryLayout<T>.size) == 0
}


// Those are mostly dirty hacks to get what I need :-)
// I would be very interested in better way to do those things, W/O using
// Foundation.

public extension String {
  
  static func fromCString(_ cs: UnsafePointer<CChar>, length: Int!) -> String? {
    guard length != .none else { // no length given, use \0 standard variant
      return String(cString: cs)
    }
    
    let buflen = length + 1
    let buf    = UnsafeMutablePointer<CChar>.allocate(capacity: buflen)
    memcpy(buf, cs, length)
    buf[length] = 0 // zero terminate
    let s = String(cString: buf)
    buf.deallocate(capacity: buflen)
    return s
  }
  
  static func fromDataInCStringEncoding(_ data: [UInt8]) -> String {
    // The main thing here is that the data is zero-terminated
    // hh: lame
    // convert from [UInt8] to [CChar] CString to String
    // FIXME: return Optional
    guard data.count > 0 else {
      return ""
    }
    
    var cstr = [CChar](repeating: 0, count: data.count + 1)
    memcpy(&cstr, data, data.count)
    cstr[data.count] = 0 // 0-terminate
    
    return String(cString: cstr)
  }
  
  func dataInCStringEncoding() -> [UInt8] {
    return self.withCString { (cstr: UnsafePointer<CChar>) in
      let len  = Int(strlen(cstr))
      if len < 1 {
        return [UInt8]()
      }
      var buf = [UInt8](repeating: 0, count: len)
      memcpy(&buf, cstr, len)
      return buf
    }
  }
}

extension String {
  
  func strstr(_ other: String) -> String.Index? {
    // FIXME: make this a generic
    var start = startIndex
    
    repeat {
      let subString = self[start..<endIndex]
      if subString.hasPrefix(other) {
        return start
      }
      start = self.index(after: start)
    } while start != endIndex
    
    return nil
  }

}

extension Int32  {
  
  public var boolValue : Bool {
    return self != 0
  }
  
}


/* v0.0.4 has no lowercaseString anymore. Need to hack around this. I think
 * there is no proper Unicode up/low in 0.0.4 w/o resorting to Cocoa?
 */
extension Character {
  
  var unicodeScalarCodePoint : UInt32 {
    let characterString = String(self)
    let scalars = characterString.unicodeScalars
    
    return scalars[scalars.startIndex].value
  }
  
  var isASCIILower : Bool {
    let cp = self.unicodeScalarCodePoint
    return cp >= 97 && cp <= 122
  }
  var isASCIIUpper : Bool {
    let cp = self.unicodeScalarCodePoint
    return cp >= 65 && cp <= 90
  }
  
  var asciiLower : Character {
    return self.isASCIIUpper
      ? Character(UnicodeScalar(self.unicodeScalarCodePoint + 32)!)
      : self
  }
  var asciiUpper : Character {
    return self.isASCIILower
      ? Character(UnicodeScalar(self.unicodeScalarCodePoint - 32)!)
      : self
  }

}

extension String {
  
  var isHexDigit : Bool {
    if self == "" { return false }
    
    for c in self.characters {
      if isxdigit(Int32(c.unicodeScalarCodePoint)) == 0 {
        return false
      }
    }
    
    return true
  }
}
