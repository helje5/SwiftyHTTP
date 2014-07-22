//
//  HTTPConnectionPool.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 7/1/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Dispatch

public class HTTPConnectionPool {
  
  let lockQueue   = dispatch_get_main_queue()
  var openSockets = Dictionary<Int32, HTTPConnection>(minimumCapacity: 8)
  
  func registerConnection(con: HTTPConnection) {
    // now we need to keep the socket around!!
    dispatch_async(lockQueue) {
      if con.socket.isValid {
        self.openSockets[con.socket.fd!] = con
      
        con.onRequest  { [unowned self] in self.handleRequest ($0, $1)   }
           .onResponse { [unowned self] in self.handleResponse($0, $1)   }
           .onClose    { [unowned self] in self.unregisterConnection($0) }
      }
    }
  }
  
  func unregisterConnection(fd: Int32) {
    dispatch_async(lockQueue) {
      let rc = self.openSockets.removeValueForKey(fd)
      if !rc {
        self.log("closed socket \(fd).")
        self.log("-----")
      }
    }
  }
  
  
  /* overrides for subclasses */
  
  func handleRequest(request: HTTPRequest, _ con: HTTPConnection) {
    log("Subclass should handle request: \(request)")
  }
  func handleResponse(response: HTTPResponse, _ con: HTTPConnection) {
    log("Subclass should handle response: \(response)")
  }

  
  /* logging */

  var logger : (( String ) -> Void)? = nil
  
  func log(s: String) {
    if let cb = logger {
      cb(s)
    }
    else {
      println(s)
    }
  }
  func log() {
     // if I do (_ s: String = "") the compiler crashes
    log("")
  }

  public func onLog(cb: (String) -> Void) -> Self {
    logger = cb
    return self
  }
}
