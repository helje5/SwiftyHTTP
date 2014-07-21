//
//  HTTPEventQueue.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 7/5/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//


// class crashes compiler
struct HTTPEventQueue<T> {
  
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
        queue.removeAll(keepCapacity: true)
      
        for o in queueCopy {
          cb(o, connection)
        }
      }
    }
  }

  mutating func emit(o: T) {
    // locking
    if let cb = on {
      cb(o, connection)
    }
    else {
      queue.append(o)
    }
  }
}
