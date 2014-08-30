//
//  HTTPMethod.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public enum HTTPMethod : Equatable {
  // Either inherit from Int (and have raw values) OR have cases with arguments
  
  case GET, HEAD, PUT, DELETE, POST, OPTIONS
  
  case PROPFIND, PROPPATCH, MKCOL
  
  case REPORT((String?, String?)) // tuple: ns, tag
  
  case MKCALENDAR
  
  case BATCH // ;-)
  
  case CONNECT, TRACE
  case COPY, MOVE
  case LOCK, UNLOCK
  case SEARCH
  
  case MKACTIVITY, CHECKOUT, MERGE
  case MSEARCH, NOTIFY, SUBSCRIBE, UNSUBSCRIBE
  
  case PATCH, PURGE
  
  case Extension(String)


  public init(string: String) {
    switch string {
      case "GET":         self = .GET
      case "HEAD":        self = .HEAD
      case "PUT":         self = .PUT
      case "DELETE":      self = .DELETE
      case "POST":        self = .POST
      case "OPTIONS":     self = .OPTIONS
      
      case "PROPFIND":    self = .PROPFIND
      case "PROPPATCH":   self = .PROPPATCH
      case "MKCOL":       self = .MKCOL
      
      case "REPORT":      self = .REPORT( ( nil, nil ) )
      
      case "MKCALENDAR":  self = .MKCALENDAR
      
      case "BATCH":       self = .BATCH
      
      case "CONNECT":     self = .CONNECT
      case "TRACE":       self = .TRACE
      
      case "COPY":        self = .COPY
      case "MOVE":        self = .MOVE
      case "LOCK":        self = .LOCK
      case "UNLOCK":      self = .UNLOCK
      
      case "SEARCH":      self = .SEARCH
      
      case "MKACTIVITY":  self = .MKACTIVITY
      case "CHECKOUT":    self = .CHECKOUT
      case "MERGE":       self = .MERGE
      
      case "M-SEARCH":    self = .MSEARCH
      case "NOTIFY":      self = .NOTIFY
      case "SUBSCRIBE":   self = .SUBSCRIBE
      case "UNSUBSCRIBE": self = .UNSUBSCRIBE
      
      case "PATCH":       self = .PATCH
      case "PURGE":       self = .PURGE
      
      default:            self = .Extension(string)
    }
  }
  
}

public extension HTTPMethod {

  public var method: String {
    switch self {
      case .GET:        return "GET"
      case .HEAD:       return "HEAD"
      case .PUT:        return "PUT"
      case .DELETE:     return "DELETE"
      case .POST:       return "POST"
      case .OPTIONS:    return "OPTIONS"
        
      case .PROPFIND:   return "PROPFIND"
      case .PROPPATCH:  return "PROPPATCH"
      case .MKCOL:      return "MKCOL"
        
      case .REPORT:     return "REPORT"
        
      case .MKCALENDAR: return "MKCALENDAR"
        
      case .BATCH:      return "BATCH"

      case .CONNECT:    return "CONNECT"
      case .TRACE:      return "TRACE"
      
      case .COPY:       return "COPY"
      case .MOVE:       return "MOVE"
      case .LOCK:       return "LOCK"
      case .UNLOCK:     return "UNLOCK"
      
      case .SEARCH:     return "SEARCH"
      
      case .MKACTIVITY: return "MKACTIVITY"
      case .CHECKOUT:   return "CHECKOUT"
      case .MERGE:      return "MERGE"
      
      case .MSEARCH:    return "M-SEARCH"
      case .NOTIFY:     return "NOTIFY"
      case .SUBSCRIBE:  return "SUBSCRIBE"
      case .UNSUBSCRIBE:return "UNSUBSCRIBE"

      case .PATCH:      return "PATCH"
      case .PURGE:      return "PURGE"
      
      case .Extension(let v):
        return v
    }
  }
  
  public var isSafe: Bool? { // can't say for extension methods
    switch self {
      case .GET, .HEAD, .OPTIONS:
        return true
      case .PROPFIND, .REPORT:
        return true
      case .BATCH:
        return true
      case .Extension:
        return nil // don't know
      default:
        return false
    }
  }
  
  public var isIdempotent: Bool? { // can't say for extension methods
    switch self {
      case .GET, .HEAD, .PUT, .DELETE, .OPTIONS:
        return true
      case .PROPFIND, .REPORT, .PROPPATCH:
        return true
      case .MKCOL, .MKCALENDAR:
        return true
      case .BATCH:
        return true
      case .Extension:
        return nil // don't know
      default:
        return false
    }
  }
}

extension HTTPMethod : Printable {
  
  public var description: String {
    switch self {
      case .REPORT(let ns, let tag):
        return "REPORT[{\(ns)}\(tag)]"
      
      default:
        return method
    }
  }
}

extension HTTPMethod: StringLiteralConvertible {
  // this allows you to do: let addr : in_addr = "192.168.0.1"
  
  public static func convertFromStringLiteral
    (value: StringLiteralType) -> HTTPMethod
  {
    return HTTPMethod(string: value)
  }
  
  public static func convertFromExtendedGraphemeClusterLiteral
    (value: ExtendedGraphemeClusterType) -> HTTPMethod
  {
    return HTTPMethod(string: value)
  }
}

public func ==(lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
  // TBD: This is a bit lame, but is there a way to do this w/o spelling out all
  //      values in a big switch?
  return lhs.description == rhs.description
}
