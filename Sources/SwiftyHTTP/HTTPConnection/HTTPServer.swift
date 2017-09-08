//
//  ARIHttpServer.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/5/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Dispatch

open class HTTPServer : HTTPConnectionPool {
  
  open var port         : Int?           = nil
  open var socket       : PassiveSocketIPv4!
  
  var handler      : ((HTTPRequest, HTTPResponse, HTTPConnection)->Void)? = nil
  var handlerQueue : DispatchQueue? = nil
  
  open func onRequest
    (_ cb:@escaping (HTTPRequest, HTTPResponse, HTTPConnection)->Void) -> Self
  {
    handler = cb
    return self
  }
  open func useQueue(_ queue: DispatchQueue) -> Self {
    handlerQueue = queue
    return self
  }

  override func handleRequest(_ request: HTTPRequest, _ con: HTTPConnection) {
    log("Got request: \(request)")
    log()
    
    if let handler = handler {
      let q = handlerQueue ?? DispatchQueue.main
      
      q.async {
        let response = HTTPResponse(status: .ok, headers: [
          "Content-Type": "text/html"
        ])
        
        handler(request, response, con)
        
        if response.closeConnection || request.closeConnection {
          con.close()
        }
      }
    }
    else {
      let response = HTTPResponse(status: .internalServerError, headers: [
        "Content-Type": "text/html"
      ])
      response.bodyAsString = "No handler configured in HTTP server!\r\n"
      con.sendResponse(response)
      con.close()
    }
  }
  
  open func listen(_ port: Int) -> HTTPServer {
    // using Self or Self? seems to crash the compiler
    
    socket = PassiveSocket(address: sockaddr_in(port: port))
    guard socket.isValid else {
      log("could not create socket ...")
      assert(socket.isValid)
      return self
    }
    socket.reuseAddress = true
    
    log("Listen socket \(socket) reuse=\(socket.reuseAddress)")
    
    let queue = DispatchQueue.global(priority: 0)
    
    
    socket.listen(queue, backlog: 5) {
      [unowned self] in
      let con = HTTPConnection($0)
      
      self.log()
      self.log("-----")
      self.log("got new connection: \(con)")
      self.log()
      
      // Note: we need to keep the socket around!!
      self.registerConnection(con)
    }
    
    log("Started running listen socket \(socket)")
    
    return self
  }
  
  open func stop() {
    if let s = socket {
      s.close()
      socket = nil
    }
    
    let socketsToClose = openSockets // make a copy
    for (_, sock) in socketsToClose {
      sock.close()
    }
  }
}
