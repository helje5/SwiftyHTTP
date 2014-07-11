//
//  ARIHttpServer.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/5/14.
//  Copyright (c) 2014 Helge Hess. All rights reserved.
//

class HTTPServer : HTTPConnectionPool {
  
  var port         : Int?           = nil
  var socket       : PassiveSocketIPv4!
  
  var handler      : ((HTTPRequest, HTTPResponse, HTTPConnection)->Void)? = nil
  var handlerQueue : dispatch_queue_t? = nil
  
  init() {
    // If there is an init(), you don't have to provide default values for
    // all ivars?
    super.init()
  }
  
  func onRequest(cb:(HTTPRequest, HTTPResponse, HTTPConnection)->Void) -> Self {
    handler = cb
    return self
  }
  func useQueue(queue: dispatch_queue_t) -> Self {
    handlerQueue = queue
    return self
  }

  override func handleRequest(request: HTTPRequest, _ con: HTTPConnection) {
    log("Got request: \(request)")
    log()
    
    if let handler = handler {
      let q = handlerQueue ? handlerQueue! : dispatch_get_main_queue()
      
      dispatch_async(q) {
        let response = HTTPResponse(status: .OK, headers: [
          "Content-Type": "text/html"
        ])
        
        handler(request, response, con)
        
        if response.closeConnection || request.closeConnection {
          con.close()
        }
      }
    }
    else {
      let response = HTTPResponse(status: .InternalServerError, headers: [
        "Content-Type": "text/html"
      ])
      response.bodyAsString = "No handler configured in HTTP server!\r\n"
      con.sendResponse(response)
      con.close()
    }
  }
  
  func listen(port: Int) -> HTTPServer {
    // using Self or Self? seems to crash the compiler
    
    socket = PassiveSocket(address: sockaddr_in(port: port))
    if !socket.isValid {
      log("could not create socket ...")
      assert(socket.isValid)
      return self
    }
    socket.reuseAddress = true
    
    log("Listen socket \(socket) reuse=\(socket.reuseAddress)")
    
    let queue = dispatch_get_global_queue(0, 0)
    
    
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
  
  func stop() {
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
