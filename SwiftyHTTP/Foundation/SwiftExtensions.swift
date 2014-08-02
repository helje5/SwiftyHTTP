//
//  SwiftExtensions.swift
//  TestSwiftyCocoa
//
//  Created by Helge Heß on 6/18/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

// This allows you to do: str[str.startIndex..idx+4]
public func +<T: ForwardIndex>(idx: T, distance: T.DistanceType) -> T {
  return advance(idx, distance)
}
public func +<T: ForwardIndex>(distance: T.DistanceType, idx: T) -> T {
  return advance(idx, distance)
}

public func -<T: BidirectionalIndex where T.DistanceType : SignedInteger>
  (idx: T, distance: T.DistanceType) -> T
{
  var cursor = idx
  for i in 0..<distance {
    cursor = cursor.predecessor()
  }
  return cursor
}


// Hack to compare values if we don't have access to the members of the struct,
// eg http_errno in v0.0.4
public func isByteEqual<T>(var lhs: T, var rhs: T) -> Bool {
  return memcmp(&lhs, &rhs, UInt(sizeof(T))) == 0
}


// Those are mostly dirty hacks to get what I need :-)
// I would be very interested in better way to do those things, W/O using
// Foundation.

public extension String {
  
  static func fromCString
    (cs: ConstUnsafePointer<CChar>, length: Int!) -> String?
  {
    if length == .None { // no length given, use \0 standard variant
      return String.fromCString(cs)
    }
    
    let buflen = length + 1
    var buf    = UnsafePointer<CChar>.alloc(buflen)
    memcpy(buf, cs, UInt(length))
    buf[length] = 0 // zero terminate
    let s = String.fromCString(buf)
    buf.dealloc(buflen)
    return s
  }
  
  static func fromDataInCStringEncoding(data: [UInt8]) -> String {
    // The main thing here is that the data is zero-terminated
    // hh: lame
    // convert from [UInt8] to [CChar] CString to String
    // FIXME: return Optional
    if data.count == 0 {
      return ""
    }
    
    var cstr = [CChar](count: data.count + 1, repeatedValue: 0)
    cstr.withUnsafePointerToElements { dest in  // cannot just use cstr!
      data.withUnsafePointerToElements { src in
        memcpy(dest, src, UInt(data.count))
      }
    }
    cstr[data.count] = 0 // 0-terminate
    
    // var s = "" // direct return seems to crash things, not sure why
    return cstr.withUnsafePointerToElements {
      return String.fromCString($0)!
    }
  }
  
  func dataInCStringEncoding() -> [UInt8] {
    return self.withCString { (cstr: ConstUnsafePointer<CChar>) in
      let len  = strlen(cstr)
      if len < 1 {
        return [UInt8]()
      }
      var buf = [UInt8](count: Int(len), repeatedValue: 0)
      buf.withUnsafePointerToElements { dest in
        memcpy(dest, cstr, len)
      }
      return buf
    }
  }
}

extension String {
  
  func strstr(other: String) -> String.Index? {
    // FIXME: make this a generic
    var start = startIndex
    
    do {
      var subString = self[start..<endIndex]
      if subString.hasPrefix(other) {
        return start
      }
      start++ // why does this work?
    } while start != endIndex
    
    return nil
  }

}

// Starting with v0.0.4 we cannot just extend CString anymore, this doesn't
// work: extension UnsafePointer<CChar>

/* FIXME: No more CString in v0.0.4
extension CString {
  // Q(hh): this doesn't work?: extension Array<CChar> {}
  
  static func withCString<R>(buffer: [CChar], _ cb: (_: CString) -> R) -> R {
    // FIXME for b3, simple CString(buffer)?
    // the new cast version:
    return buffer.withUnsafePointerToElements {
      var cs: CString = reinterpretCast($0)
      return cb(cs)
    }
    
    /*
    // how to I convert a [CChar] to a CString?!
    // The approach here is stupid :-)
    // FIXME: this does a real String conversion which is not necessary and
    //        breaks if the input is not proper UTF-8
    return buffer.withUnsafePointerToElements {
      let ss = $0 != nil ? String.fromCString($0) : "" // not an optional?
      // assert($0 != nil)
      if $0 == nil {
        println("FATAL: Could not grab unsafe pointer from array? \(buffer)")
      }
      return ss.withCString { (cs: CString) -> R in cb(cs) }
    }
    */
  }
  
}
*/

extension Int32 : LogicValue {
  
  public func getLogicValue() -> Bool {
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
      ? Character(UnicodeScalar(self.unicodeScalarCodePoint + 32))
      : self
  }
  var asciiUpper : Character {
    return self.isASCIILower
      ? Character(UnicodeScalar(self.unicodeScalarCodePoint - 32))
      : self
  }

}

extension String {
  
  var lowercaseString : String {
    // HACK. I think there is no proper way to do this in v0.0.4 w/o resorting
    //       to Cocoa?
    return reduce(self, "", { $0 + $1.asciiLower })
  }

}

extension String {
  
  var isHexDigit : Bool {
    if self == "" { return false }
    
    for c in self {
      if isxdigit(Int32(c.unicodeScalarCodePoint)) == 0 {
        return false
      }
    }
    
    return true
  }
}
