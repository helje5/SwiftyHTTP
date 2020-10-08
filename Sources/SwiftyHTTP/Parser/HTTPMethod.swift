//
//  HTTPMethod.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014-2020 Always Right Institute. All rights reserved.
//

public enum HTTPMethod : Equatable {
  // Either inherit from Int (and have raw values) OR have cases with arguments
  
  case get, head, put, delete, post, options
  
  case propfind, proppatch, mkcol
  
  case report((String?, String?)) // tuple: ns, tag (FIXME: why optional?)
  
  case mkcalendar
  
  case batch // ;-)
  
  case connect, trace
  case copy, move
  case lock, unlock
  case search
  
  case mkactivity, checkout, merge
  case msearch, notify, subscribe, unsubscribe
  
  case patch, purge
  
  case `extension`(String)


  public init(string: String) {
    switch string {
      case "GET":         self = .get
      case "HEAD":        self = .head
      case "PUT":         self = .put
      case "DELETE":      self = .delete
      case "POST":        self = .post
      case "OPTIONS":     self = .options
      
      case "PROPFIND":    self = .propfind
      case "PROPPATCH":   self = .proppatch
      case "MKCOL":       self = .mkcol
      
      case "REPORT":      self = .report( ( nil, nil ) )
      
      case "MKCALENDAR":  self = .mkcalendar
      
      case "BATCH":       self = .batch
      
      case "CONNECT":     self = .connect
      case "TRACE":       self = .trace
      
      case "COPY":        self = .copy
      case "MOVE":        self = .move
      case "LOCK":        self = .lock
      case "UNLOCK":      self = .unlock
      
      case "SEARCH":      self = .search
      
      case "MKACTIVITY":  self = .mkactivity
      case "CHECKOUT":    self = .checkout
      case "MERGE":       self = .merge
      
      case "M-SEARCH":    self = .msearch
      case "NOTIFY":      self = .notify
      case "SUBSCRIBE":   self = .subscribe
      case "UNSUBSCRIBE": self = .unsubscribe
      
      case "PATCH":       self = .patch
      case "PURGE":       self = .purge
      
      default:            self = .extension(string)
    }
  }
  
}

public extension HTTPMethod {

  var method: String {
    switch self {
      case .get:        return "GET"
      case .head:       return "HEAD"
      case .put:        return "PUT"
      case .delete:     return "DELETE"
      case .post:       return "POST"
      case .options:    return "OPTIONS"
        
      case .propfind:   return "PROPFIND"
      case .proppatch:  return "PROPPATCH"
      case .mkcol:      return "MKCOL"
        
      case .report:     return "REPORT"
        
      case .mkcalendar: return "MKCALENDAR"
        
      case .batch:      return "BATCH"

      case .connect:    return "CONNECT"
      case .trace:      return "TRACE"
      
      case .copy:       return "COPY"
      case .move:       return "MOVE"
      case .lock:       return "LOCK"
      case .unlock:     return "UNLOCK"
      
      case .search:     return "SEARCH"
      
      case .mkactivity: return "MKACTIVITY"
      case .checkout:   return "CHECKOUT"
      case .merge:      return "MERGE"
      
      case .msearch:    return "M-SEARCH"
      case .notify:     return "NOTIFY"
      case .subscribe:  return "SUBSCRIBE"
      case .unsubscribe:return "UNSUBSCRIBE"

      case .patch:      return "PATCH"
      case .purge:      return "PURGE"
      
      case .extension(let v):
        return v
    }
  }
  
  var isSafe: Bool? { // can't say for extension methods
    switch self {
      case .get, .head, .options:
        return true
      case .propfind, .report:
        return true
      case .batch:
        return true
      case .extension:
        return nil // don't know
      default:
        return false
    }
  }
  
  var isIdempotent: Bool? { // can't say for extension methods
    switch self {
      case .get, .head, .put, .delete, .options:
        return true
      case .propfind, .report, .proppatch:
        return true
      case .mkcol, .mkcalendar:
        return true
      case .batch:
        return true
      case .extension:
        return nil // don't know
      default:
        return false
    }
  }
}

extension HTTPMethod : CustomStringConvertible {
  
  public var description: String {
    switch self {
      case .report( ( let ns, let tag) ):
        switch ( ns, tag ) {
          case ( .none,         .none): return "REPORT[-]"
          case ( .some(let ns), .none): return "REPORT[{\(ns)}]"
          case ( .none,         .some(let tag)): return "REPORT[\(tag)]"
          case ( .some(let ns), .some(let tag)): return "REPORT[{\(ns)}\(tag)]"
        }
      
      default:
        return method
    }
  }
}

extension HTTPMethod: ExpressibleByStringLiteral {
  // this allows you to do: let addr : in_addr = "192.168.0.1"
  
  public init(stringLiteral value: StringLiteralType) {
    self.init(string: value)
  }
  
  public init(extendedGraphemeClusterLiteral v: ExtendedGraphemeClusterType) {
    self.init(string: v)
  }
  
  public init(unicodeScalarLiteral v: String) {
    // FIXME: doesn't work with UnicodeScalarLiteralType?
    self.init(string: v)
  }
}

public func ==(lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
  // TBD: This is a bit lame, but is there a way to do this w/o spelling out all
  //      values in a big switch?
  return lhs.description == rhs.description
}
