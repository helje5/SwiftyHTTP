//
//  AppDelegate.swift
//  SwiftyServer
//
//  Created by Helge Heß on 6/25/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Cocoa
import SwiftyHTTP

class AppDelegate: NSObject, NSApplicationDelegate {
  
  /* our server */
  
  var httpd : Connect!
  var requestCounter = 1 // FIXME: not threadsafe, use sync_dispatch
  
  func startServer() {
    httpd = Connect()
      .onLog {
        [unowned self] in
        self.log($0)
      }
      .useQueue(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    
    /* request counter middleware */
    httpd.use { _, _, _, next in
      self.requestCounter += 1
      next()
    }
    
    /* primary request handler */
    httpd.use { rq, res, con, next in
      var content = "<h3>Swifty request number #\(self.requestCounter)</h3>"
      
      content += "<pre>"
      content += "\r\n"
      content += "  /----------------------------------------------------\\\r\n"
      content += "  |      Welcome to the Always Right Institute!        |\r\n"
      content += "  |         I am a twisted HTTP echo server            |\r\n"
      content += "  \\----------------------------------------------------/\r\n"
      content += "\r\n"
      content += "</pre>"
      
      content += "<pre>Request: \(rq.method) \(rq.url)\n"
      for ( key, value ) in rq.headers {
        content += "  \(key): \(value)\n"
      }
      content += "</pre>"
      
      res.bodyAsString = content
      
      con.sendResponse(res)
      next()
    }
    
    /* logger middleware */
    httpd.use { rq, res, _, _ in
      print("\(rq.method) \(rq.url) \(res.status)")
    }
    
    
    httpd.listen(1337)
  }
  
  
  
  /* Cocoa app boilerplate */
                            
  @IBOutlet var window        : NSWindow!
  @IBOutlet var logViewParent : NSScrollView!
  @IBOutlet var label         : NSTextField!
  
  var logView : NSTextView {
    // NSTextView doesn't work with weak?
    return logViewParent.contentView.documentView as! NSTextView
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    startServer()
    
    label.allowsEditingTextAttributes = true
    label.selectable = true
    
    if let address = httpd.socket.boundAddress {
      let url = "http://127.0.0.1:\(address.port)"
      let s   = "<pre>Connect in your browser via " +
                "'<a href='\(url)'>\(url)</a>'</pre>"

      let utf8 = s.dataUsingEncoding(NSUTF8StringEncoding)!
      let aS   = NSAttributedString(HTML: utf8, documentAttributes: nil)
      label.attributedStringValue = aS!
    }
  }
  
  func applicationWillTerminate(aNotification: NSNotification) {
    httpd?.stop()
    httpd = nil
  }
  
  
  func log(string: String) {
    // log to shell
    print(string)
    
    // log to view. Careful, must run in main thread!
    dispatch_async(dispatch_get_main_queue()) {
      self.logView.appendString(string + "\n")
    }
  }

}

extension NSTextView {
  
  func appendString(string: String) {
    if let ts = textStorage {
      let ls = NSAttributedString(string: string)
      ts.appendAttributedString(ls)
    }
    if let s = self.string {
      let charCount = (s as NSString).length
      self.scrollRangeToVisible(NSMakeRange(charCount, 0))
    }
    needsDisplay = true
  }
  
}
