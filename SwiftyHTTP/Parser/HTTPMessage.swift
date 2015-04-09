//
//  HTTPMessage.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public class HTTPMessage {
  
  class HeaderLine { // a class, so we work with references, not copies?
    let name:   String
    let lcName: String
    var value:  String // rather Any?
    
    init(_ name: String, _ value: String) {
      self.name   = name
      self.lcName = name.lowercaseString
      self.value  = value
    }
  }
  
  let version : ( major: Int, minor: Int )
  var header  = [HeaderLine]() // not a dict, we need to do cis lookups
  
  public init(version: ( Int, Int ), headers: Dictionary<String, String>) {
    self.version = version

    for (key, value) in headers {
      header.append(HeaderLine(key, value))
    }
  }
  
  public subscript(key: String?) -> String? {
    get {
      if key != nil {
        let lcName = key!.lowercaseString
        for line in header {
          if line.lcName == lcName {
            return line.value
          }
        }
      }
      return nil
    }
    set { // Note: no multivalue-append, which is sometimes useful
      if key == nil { return }
      
      let lcName = key!.lowercaseString
      if let v = newValue {
        for line in header {
          if line.lcName == lcName {
            line.value = v
            return
          }
        }
        header.append(HeaderLine(key!, v))
      }
      else {
        var cursor = header.startIndex
        while cursor != header.endIndex {
          if header[cursor].lcName == lcName {
            header.removeAtIndex(cursor)
            return
          }
          cursor++
        }
      }
    }
  }
  
  public var headers : Dictionary<String, String> {
    var headers = Dictionary<String, String>()
    for line in header {
      headers[line.name] = line.value
    }
    return headers
  }
  
  
  /* body handling */
  
  public var hasBody : Bool {
    return _byteBodyCache != nil || _stringBodyCache != nil
  }
  
  public var bodyAsByteArray : Array<UInt8>? {
    get {
      if _byteBodyCache != nil {
        return _byteBodyCache
      }
      else if let s = _stringBodyCache {
        // real encoding requires use of Foundation
        _byteBodyCache = s.dataInCStringEncoding()
        return _byteBodyCache
      }
      else {
        return nil
      }
    }
    set {
      _byteBodyCache   = newValue
      _stringBodyCache = nil
    }
  }
  public var bodyAsString : String? {
    get {
      if _stringBodyCache != nil {
        return _stringBodyCache
      }
      else if let buf = _byteBodyCache {
        // real encoding requires use of Foundation
        _stringBodyCache = String.fromDataInCStringEncoding(buf)
        return _stringBodyCache
      }
      else {
        return nil
      }
    }
    set {
      _stringBodyCache = newValue
      _byteBodyCache   = nil
    }
  }

  var _byteBodyCache   : Array<UInt8>?
  var _stringBodyCache : String?
  
  
  /* persistent connections */
  
  public var closeConnection : Bool {
    if version.major == 0 {
      return true
    }
    else if version.major == 1 && version.minor == 0 {
      return true
    }
    else if let v = self["Connection"] {
      if v.lowercaseString == "close" {
        return true
      }
    }
    else if self["Content-Length"] == nil {
      return true
    }
    return false
  }
  
  
  /* description */
  
  // must live in the main-class as 'declarations in extensions cannot be
  // overridden yet'
  func descriptionAttributes() -> String {
    var s = ""
    s += " HTTP/\(version.major).\(version.minor)"
    
    if let b = _byteBodyCache {
      s += " body=#\(b.count)"
    }
    else if let b = _stringBodyCache {
      s += " body=c#\(count(b))"
    }
    
    s += " H: \(headers)"
    return s
  }
}

extension HTTPMessage: Printable {
  
  public var description: String {
    return "<Message:" + descriptionAttributes() + ">"
  }
  
}

