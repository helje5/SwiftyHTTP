//
//  URL.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 7/4/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

// Very simple URL class. Do not use ;-)
// RFC 3986
// https://joe:user@apple.com:443/path/elements#red?a=10&b=20
public struct URL {
  
  // all escaped values
  public var scheme   : String?
  public var host     : String?
  public var port     : Int?
  public var path     : String?
  public var query    : String?
  public var fragment : String?
  public var userInfo : String?
  
  public init() {
  }
  public init(_ string: String) {
    self = parse_url(string)
  }
  public init(baseURL: URL, path: String) {
    // FIXME: very basic implementation, should be more clever
    self = baseURL
    if path.hasPrefix("/") {
      self.path = path
    }
    else if let basePath = self.path {
      self.path = basePath + (basePath.hasSuffix("/") ? "" : "/" ) + path
    }
    else {
      self.path = "/" + path
    }
  }
  
  public var isEmpty : Bool {
    if let s = scheme   { return false }
    if let s = userInfo { return false }
    if let s = host     { return false }
    // intentionally no port check, only in combination with host
    if let s = path     { return false }
    if let s = fragment { return false }
    if let s = query    { return false }
    return true
  }
  
  public var urlWithoutAuthority : URL { // nice name ;-)
    var url = URL()
    url.path     = self.path
    url.query    = self.query
    url.fragment = self.fragment
    return url
  }
  
  public var hostAndPort : String? {
    if let h = host {
      if let p = port {
        return "\(h):\(p)"
      }
      return h
    }
    return nil
  }
  
  public var portOrDefault : Int? { // what's a nice name for this?
    if let p = port {
      return p
    }
    if let s = scheme {
      return URL.portForScheme(s)
    }
    return nil
  }
  
  public var pathWithQueryAndFragment : String {
    if path == nil && query == nil && fragment == nil {
      return "/"
    }
    var s = path != nil ? path! : "/"
    if let q = query    { s += "?" + q }
    if let f = fragment { s += "#" + f }
    return s
  }
  
  mutating func clearEmptyStrings() {
    if scheme   != nil && scheme!   == "" { scheme   = nil }
    if host     != nil && host!     == "" { host     = nil }
    if path     != nil && path!     == "" { path     = nil }
    if query    != nil && query!    == "" { query    = nil }
    if fragment != nil && fragment! == "" { fragment = nil }
    if userInfo != nil && userInfo! == "" { userInfo = nil }
  }
}


public extension URL { // String representation
  
  public func toString() -> String? {
    var us = ""
    
    var scheme = self.scheme
    if scheme == nil && port != nil {
      scheme = URL.schemeForPort(port!)
    }
    
    if let v = scheme {
      if host == nil {
        return nil
      }
      
      us = "\(v)://"
      if let v = userInfo {
        us += v + "@"
      }
      
      us += host!
      
      if let v = port {
        us += ":\(port)"
      }
    }
    
    if let v = path {
      if v.hasPrefix("/") {
        us += v
      }
      else {
        if us != "" { us += "/" }
        us += v
      }
    }
    else if fragment != nil || query != nil {
      // fill in path if required for other values
      if us != "" {
        us += "/"
      }
    }
    
    if let v = fragment {
      us += "#" + v
    }
    
    if let v = query {
      us += "?" + v
    }
    
    return us
  }
  
}


public extension String {
  
  public var withoutPercentEscapes : String { return percentUnescape(self) }
  
}


public extension URL {
  
  var pathComponents : [String]? {
    if let escapedPC = escapedPathComponents {
      return escapedPC.map { return $0.withoutPercentEscapes }
    }
    else {
      return nil
    }
  }
  
  var escapedPathComponents : [String]? {
    if path == .None { return nil }
    let uPath = path!
    if uPath == ""   { return nil }
    
    let isAbsolute = uPath.hasPrefix("/")
    let pathComps  = split(uPath, allowEmptySlices: true) { $0 == "/" }
    
    /* Note: we cannot just return a leading slash for absolute pathes as we
     *       wouldn't be able to distinguish between an absolute path and a
     *       relative path starting with an escaped slash.
     *   So: Absolute pathes instead start with an empty string.
     */
    var gotAbsolute = isAbsolute ? false : true
    return filter(pathComps) {
      if $0 != "" || !gotAbsolute {
        if !gotAbsolute { gotAbsolute = true }
        return true
      }
      else {
        return false
      }
    }
  }

}

public extension URL { // /etc/services
  
  public static func schemeForPort(port: Int) -> String? {
    // read /etc/services? but this doesn't have a proper 1337?
    switch port {
      case    7: return "echo"
      case   21: return "ftp"
      case   23: return "telnet"
      case   25: return "smtp"
      case   70: return "gopher"
      case   79: return "finger"
      case   80: return "http"
      case  443: return "https"
      case 1337: return "leet"
      default:   return nil
    }
  }
  
  public static func portForScheme(scheme: String) -> Int? {
    // read /etc/services? but this doesn't have a proper 1337?
    switch scheme {
      case "echo":   return 7;
      case "ftp":    return 21;
      case "telnet": return 23;
      case "smtp":   return 25;
      case "gopher": return 70;
      case "finger": return 79;
      case "http":   return 80;
      case "https":  return 443;
      case "leet":   return 1337;
      default:       return nil
    }
  }
  
}

extension URL : Printable {
  
  public var description : String {
    if let s = toString() {
      return s
    }
    else {
      return "" // hm
    }
  }
  
}

extension URL : StringLiteralConvertible {
  
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
  
  public init(extendedGraphemeClusterLiteral v: ExtendedGraphemeClusterType) {
    self.init(v)
  }
  
  public init(unicodeScalarLiteral value: String) {
    // FIXME: doesn't work with UnicodeScalarLiteralType?
    self.init(value)
  }
}

extension String {
  
  public func toURL() -> URL {
    return parse_url(self)
  }
  
}

func parse_url(us: String) -> URL {
  // yes, yes, I know. Pleaze send me a proper version ;-)
  var url = URL()
  var s   = us
  var ps  = "" // path part
  
  if let idx = s.strstr("://") {
    url.scheme = s[s.startIndex..<idx]
    s = s[idx + 3..<s.endIndex]
    
    // cut off path
    if let idx = Swift.find(s, "/") {
      ps = s[idx..<s.endIndex] // path part
      s  = s[s.startIndex..<idx]
    }
    
    // s: joe:pwd@host:port
    if let idx = Swift.find(s, "@") {
      url.userInfo = s[s.startIndex..<idx]
      s = s[idx + 1..<s.endIndex]
    }
    
    // s: host:port
    if let idx = Swift.find(s, ":") {
      url.host = s[s.startIndex..<idx]
      let portS = s[idx + 1..<s.endIndex]
      let portO = portS.toInt()
      println("ports \(portS) is \(portO)")
      if let port = portO {
        url.port = port
      }
    }
    else {
      url.host = s
    }
  }
  else {
    // no scheme, means no host, port, userInfo
    ps = s
  }
  
  if ps != "" {
    if let idx = Swift.find(ps, "?") {
      url.query = ps[idx + 1..<ps.endIndex]
      ps = ps[ps.startIndex..<idx]
    }
    
    if let idx = Swift.find(ps, "#") {
      url.fragment = ps[idx + 1..<ps.endIndex]
      ps = ps[ps.startIndex..<idx]
    }
    
    url.path = ps
  }
  
  url.clearEmptyStrings()
  return url
}


func percentUnescape(src: String) -> String {
  // Lame implementation. Likely really slow.
  if src == "" { return "" }
  
  var dest = ""
  
  var cursor = src.startIndex
  let endIdx = src.endIndex
  
  while cursor != endIdx {
    if src[cursor] == "%" { // %40 = @
      let v0idx = cursor.successor()
      if v0idx == endIdx {
        dest += src[cursor..<endIdx]
        break
      }
      
      let v1idx = v0idx.successor()
      if v1idx == endIdx {
        dest += src[cursor..<endIdx]
        break
      }
      
      let hex = src[v0idx...v1idx]
      
      if !hex.isHexDigit {
        println("Invalid percent escapes: \(src)")
        dest += src[cursor...v1idx]
      }
      else {
        let code = hex.withCString {
          ( cs : UnsafePointer<CChar> ) -> Int in
          return strtol(cs, nil, 16)
        }
        dest.append(UnicodeScalar(code))
      }
      cursor = v1idx.successor()
    }
    else {
      dest.append(src[cursor])
      cursor =  cursor.successor()
    }
  }
  return dest
}
