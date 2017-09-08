//
//  HTTPConnectionPool.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 7/1/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Dispatch

open class HTTPConnectionPool {
  
  let lockQueue   = DispatchQueue.main
  var openSockets =
        Dictionary<FileDescriptor, HTTPConnection>(minimumCapacity: 8)
  
  func registerConnection(_ con: HTTPConnection) {
    // now we need to keep the socket around!!
    lockQueue.async {
      if con.socket.isValid {
        self.openSockets[con.socket.fd] = con
      
        con.onRequest  { [unowned self] in self.handleRequest ($0, $1)   }
           .onResponse { [unowned self] in self.handleResponse($0, $1)   }
           .onClose    { [unowned self] in self.unregisterConnection($0) }
      }
    }
  }
  
  func unregisterConnection(_ fd: FileDescriptor) {
    lockQueue.async {
      let rc = self.openSockets.removeValue(forKey: fd)
      if rc != nil {
        self.log("closed socket \(fd).")
        self.log("-----")
      }
    }
  }
  
  
  /* overrides for subclasses */
  
  func handleRequest(_ request: HTTPRequest, _ con: HTTPConnection) {
    log("Subclass should handle request: \(request)")
  }
  func handleResponse(_ response: HTTPResponse, _ con: HTTPConnection) {
    log("Subclass should handle response: \(response)")
  }

  
  /* logging */

  var logger : (( String ) -> Void)? = nil
  
  open func log(_ s: String) {
    if let cb = logger {
      cb(s)
    }
    else {
      print(s)
    }
  }
  open func log() {
     // if I do (_ s: String = "") the compiler crashes
    log("")
  }

  @discardableResult
  open func onLog(_ cb: @escaping (String) -> Void) -> Self {
    logger = cb
    return self
  }
}
