//
//  HTTPMessage.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

open class HTTPMessage {
  
  class HeaderLine { // a class, so we work with references, not copies?
    let name:   String
    let lcName: String
    var value:  String // rather Any?
    
    init(_ name: String, _ value: String) {
      self.name   = name
      self.lcName = name.lowercased()
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
  
  open subscript(key: String?) -> String? {
    get {
      guard let lKey = key else { return nil }
      
      let lcName = lKey.lowercased()
      for line in header {
        if line.lcName == lcName {
          return line.value
        }
      }
      return nil
    }
    set { // Note: no multivalue-append, which is sometimes useful
      guard let lKey = key else { return }
      
      let lcName = lKey.lowercased()
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
            header.remove(at: cursor)
            return
          }
          cursor += 1
        }
      }
    }
  }
  
  open var headers : Dictionary<String, String> {
    var headers = Dictionary<String, String>()
    for line in header {
      headers[line.name] = line.value
    }
    return headers
  }
  
  
  /* body handling */
  
  open var hasBody : Bool {
    return _byteBodyCache != nil || _stringBodyCache != nil
  }
  
  open var bodyAsByteArray : Array<UInt8>? {
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
  open var bodyAsString : String? {
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
  
  open var closeConnection : Bool {
    if version.major == 0 {
      return true
    }
    else if version.major == 1 && version.minor == 0 {
      return true
    }
    else if let v = self["Connection"] {
      if v.lowercased() == "close" {
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
      s += " body=c#\(b.characters.count)"
    }
    
    s += " H: \(headers)"
    return s
  }
}

extension HTTPMessage: CustomStringConvertible {
  
  public var description: String {
    return "<Message:" + descriptionAttributes() + ">"
  }
  
}

