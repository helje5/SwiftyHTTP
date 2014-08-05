//
//  Connect.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/26/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

/**
 * NodeJS style Connect, well, bitz of it ;-)
 *
 * http://stephensugden.com/middleware_guide/
 *
 * Note: no error handling
 */
public class Connect : HTTPServer {
  
  var middlewarez = [MiddlewareEntry]()
  
  override public init() {
    super.init()
    self.onRequest { [unowned self] in
      self.doRequest($0, response: $1, connection: $2)
    }
  }
  
  public func use(cb: Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(middleware: cb))
    return self
  }
  public func use(prefix: String, _ cb: Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(urlPrefix: prefix, middleware: cb))
    return self
  }
  
  // FIXME: complete me
  
  func doRequest(request: HTTPRequest, response: HTTPResponse,
                 connection: HTTPConnection) -> Void
  {
    let matchingMiddleware = middlewarez.filter { $0.matchesRequest(request) }
    var i = 0 // capture position
    
    let endNext : Next = { args in let noop = args }
    var next    : Next = { args in let noop = args }
    next = {
      args in
      let middleware = matchingMiddleware[i].middleware
      i = i + 1
      middleware(request, response, connection,
                 (i == matchingMiddleware.count) ? endNext : next)
    }
    
    next()
  }

}

struct MiddlewareEntry {
  
  let urlPrefix  : String?
  let middleware : Middleware
  
  init(middleware: Middleware) {
    self.middleware = middleware
    self.urlPrefix  = nil
  }
  
  init(urlPrefix: String, middleware: Middleware) {
    self.urlPrefix  = urlPrefix
    self.middleware = middleware
  }
  
  func matchesRequest(request: HTTPRequest) -> Bool {
    if let prefix = urlPrefix {
      if !request.path.hasPrefix(prefix) {
        return false
      }
    }
    
    return true
  }
  
}

public typealias Next       = (String...) -> Void
public typealias Middleware =
                   (HTTPRequest, HTTPResponse, HTTPConnection, Next) -> Void
