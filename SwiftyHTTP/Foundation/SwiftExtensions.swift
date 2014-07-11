//
//  SwiftExtensions.swift
//  TestSwiftyCocoa
//
//  Created by Helge Heß on 6/18/14.
//  Copyright (c) 2014 Helge Hess. All rights reserved.
//

// This allows you to do: str[str.startIndex..idx+4]
func +<T: ForwardIndex>(idx: T, distance: T.DistanceType) -> T {
  return advance(idx, distance)
}
func +<T: ForwardIndex>(distance: T.DistanceType, idx: T) -> T {
  return advance(idx, distance)
}

func -<T: BidirectionalIndex where T.DistanceType : SignedInteger>
  (idx: T, distance: T.DistanceType) -> T
{
  var cursor = idx
  for i in 0..<distance {
    cursor = cursor.predecessor()
  }
  return cursor
}


// Those are mostly dirty hacks to get what I need :-)
// I would be very interested in better way to do those things, W/O using
// Foundation.

extension String {
  
  static func fromCString(cs: CString, length: Int?) -> String? {
    if length == nil { // no length given, use \0 standard variant
      return String.fromCString(cs)
    }
    
    // hh: this is really lame, there must be a better way :-)
    if let buf = cs.persist() {
      return buf.withUnsafePointerToElements {
        (p: UnsafePointer<CChar>) in
        let old = p[length!]
        p[length!] = 0
        let s = String.fromCString(CString(p))
        p[length!] = old
        return s
      }
    }
    return nil
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
        memcpy(UnsafePointer<Void>(dest),
               UnsafePointer<Void>(src),
               UInt(data.count))
      }
    }
    cstr[data.count] = 0 // 0-terminate
    
    // var s = "" // direct return seems to crash things, not sure why
    return cstr.withUnsafePointerToElements {
      return String.fromCString(CString($0))!
    }
  }
  
  func dataInCStringEncoding() -> [UInt8] {
    return self.withCString { (p: CString) in
      let cstr = p.persist()
      let len  = UInt(cstr!.count) - 1
      if len < 1 {
        return [UInt8]()
      }
      var buf = [UInt8](count: Int(len), repeatedValue: 0)
      buf.withUnsafePointerToElements { dest in
        cstr!.withUnsafePointerToElements { src in
          memcpy(UnsafePointer<Void>(dest),
                 UnsafePointer<Void>(src),
                 len)
        }
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

extension Int32 : LogicValue {
  
  func getLogicValue() -> Bool {
    return self != 0
  }
  
}
