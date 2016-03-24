//
//  ARIHTTPConnection.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/5/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Darwin

public class HTTPConnection {
  
  public let socket : ActiveSocketIPv4
  
  let debugOn = false
  let parser  : HTTPParser
  
  public init(_ socket: ActiveSocketIPv4) {
    self.socket = socket
    
    parser = HTTPParser()
    
    
    /* next: configuration, all ivars are setup */
    
    // init sequence issue, connection can't be passed as an unowned?
    requestQueue.connection  = self
    responseQueue.connection = self
    
    
    parser.onRequest  {
      [unowned self] rq in
      self.requestQueue.emit (rq)
      if rq.closeConnection {
        self.close()
      }
    }
    parser.onResponse {
      [unowned self] res in
      self.responseQueue.emit(res)
      if res.closeConnection {
        self.close()
      }
    }
    
    self.socket.isNonBlocking = true
    self.socket.onRead {
      [unowned self] in self.handleIncomingData($0, expectedLength: $1)
    }

    // look for data already in the queue.
    // FIXME: This is failing sometimes with 0 bytes. While it's OK to return
    //        0 bytes, it should fail with an EWOULDBLOCK
    self.handleIncomingData(self.socket, expectedLength: 1)
    
    if debugOn { debugPrint("HC: did init \(self)") }
  }
    
  
  /* callbacks */
  
  public func onRequest(cb: ((HTTPRequest, HTTPConnection) -> Void)?) -> Self {
    requestQueue.on = cb
    return self
  }
  public func onResponse(cb: ((HTTPResponse, HTTPConnection) -> Void)?) -> Self {
    responseQueue.on = cb
    return self
  }
  
  // FIXME: how to fix init order (cannot pass in 'self')
  var requestQueue  = HTTPEventQueue<HTTPRequest>()
  var responseQueue = HTTPEventQueue<HTTPResponse>()
  
  /* don't want to queue such
  func onHeaders(cb: ((HTTPMessage, HTTPConnection) -> Bool)?) -> Self {
    parser.onHeaders(cb ? { cb!($0, self) } : nil)
    return self
  }
  func onBodyData(cb: ((HTTPMessage, HTTPConnection, CString, UInt) -> Bool)?)
    -> Self
  {
    parser.onBodyData(cb ? { cb!($0, self, $1, $2) } : nil)
    return self
  }
  */
  
  public func onClose(cb: ((FileDescriptor) -> Void)?) -> Self {
    // FIXME: what if the socket was closed already? Need to check for isValid?
    socket.onClose(cb)
    return self
  }
  
  public var isValid : Bool { return self.socket.isValid }
  
  
  /* close the connection */
  
  func close(reason: String?) -> Self {
    if debugOn { debugPrint("HC: closing \(self)") }
    socket.close() // this is calling master.unregister ...
    socket.onRead(nil)
    parser.resetEventHandlers()
    return self
  }
  public func close() {
    // cannot assign default-arg to reason, makes it a kw arg
    close(nil)
  }
  
  
  
  /* handle incoming data */
  
  func handleIncomingData<T>(socket: ActiveSocket<T>, expectedLength: Int) {
    // For some reason this is called on a closed socket (in the SwiftyClient).
    // Not quite sure why, presumably the read-closure is hanging in some queue
    // on a different thread.
    // Technically it shouldn't happen as we reset the read closure in the
    // socket close()? Go figure! ;-)
    repeat {
      let (count, block, errno) = socket.read()
      if debugOn { debugPrint("HC: read \(count) \(errno)") }
      
      if count < 0 && errno == EWOULDBLOCK {
        break
      }
    
      if count < 0 {
        close("Some socket error \(count): \(errno) ...")
        return
      }
      
      /* feed HTTP parser */
      let rc = parser.write(block, count)
      if rc != .OK {
        close("Got parser error: \(rc)")
        return
      }
      
      // if parser.bodyIsFinal { // I don't really know what this is :-)

      if count == 0 {
        close("EOF")
        return
      }
    } while true
  }
}


extension HTTPConnection { /* send HTTP messages */
  
  func fixupHeaders(m: HTTPMessage) {
    if let bodyBuffer = m.bodyAsByteArray {
      m["Content-Length"] = String(bodyBuffer.count)
    }
  }
  
  func sendHeaders(m: HTTPMessage) -> Self {
    // this sends things as UTF-8 which is only right in the very lastest
    // HTTP revision (before HTTP headers have been Latin1)
    var s = ""
    for (key, value) in m.headers {
      s += "\(key): \(value)\r\n"
    }
    s += "\r\n"
    socket.write(s)
    // debugPrint("Headers:\r\n \(s)")
    return self
  }
  
  func sendBody(r: HTTPMessage) {
    let bodyBuffer = r.bodyAsByteArray
    if let bb = bodyBuffer {
      socket.asyncWrite(bb);
    }
  }
  
  public func sendRequest(rq: HTTPRequest, cb: (()->Void)? = nil) -> Self {
    // FIXME: it's inefficient to do that many writes
    fixupHeaders(rq)
    
    let requestLine = "\(rq.method.method) \(rq.url) " +
                      "HTTP/\(rq.version.major).\(rq.version.minor)\r\n"
    
    if debugOn { debugPrint("HC: sending request \(rq) \(self)") }
    
    socket.write(requestLine)
    sendHeaders(rq)
    sendBody(rq)
    if let lcb = cb {
      lcb()
    }
    
    if debugOn { debugPrint("HC: did enqueue request \(rq) \(self)") }
    return self
  }
  
  public func sendResponse(res: HTTPResponse, cb: (()->Void)? = nil) -> Self {
    // FIXME: it's inefficient to do that many writes
    fixupHeaders(res)
    
    let statusLine = "HTTP/\(res.version.major).\(res.version.minor)" +
                     " \(res.status.status) \(res.status.statusText)\r\n"
    
    if debugOn { debugPrint("HC: sending response \(res) \(self)") }
    socket.write(statusLine)
    
    sendHeaders(res)
    sendBody(res)
    if let lcb = cb {
      lcb()
    }
    
    if debugOn { debugPrint("HC: did enqueue response \(res) \(self)") }
    return self
  }
  
}


extension HTTPConnection : CustomStringConvertible {
  
  public var description : String {
    return "<HTTPConnection \(socket)>"
  }
}
