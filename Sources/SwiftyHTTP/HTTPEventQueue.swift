//
//  HTTPEventQueue.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 7/5/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

/**
 * HTTPEventQueue
 *
 * Usage:
 *   func onRequest(cb: ((HTTPRequest, HTTPConnection) -> Void)?) -> Self {
 *     requestQueue.on = cb
 *     return self
 *   }
 *
 * This object queues up all 'events' until a callback is registered. E.g. in
 * the sample all HTTP requests until an onRequest handler is set. This way
 * a connection can start up w/o being wired up fully.
 */
class HTTPEventQueue<T> {
  
  // unowned would be better, but this gives an init sequence issue?
  weak var connection : HTTPConnection!
  
  var queue = [T]()
  
  init() {
    connection = nil
  }
  
  var on : ((T, HTTPConnection) -> Void)? {
    didSet {
      if let cb = on {
        // locking
        let queueCopy = queue
        queue.removeAll(keepingCapacity: true)
      
        for o in queueCopy {
          cb(o, connection)
        }
      }
    }
  }

  func emit(_ o: T) {
    // locking
    if let cb = on {
      cb(o, connection)
    }
    else {
      queue.append(o)
    }
  }
}
