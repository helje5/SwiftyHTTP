//
//  AppDelegate.swift
//  SwiftyClient
//
//  Created by Helge Heß on 6/30/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Dispatch
import Cocoa
import SwiftyHTTP


class AppDelegate: NSObject, NSApplicationDelegate {
  
  func doStuff() {
    log("Fetch: \(urlField.stringValue)")
    
    GET(urlField.stringValue)
      .done {
        self.log()
        self.log("request  \($0)")
        self.log("response \($1)")
        self.log("body:\n\($1.bodyAsString)")
      }
      .fail {
        self.log("failed \($0): \($1)")
      }
      .always { self.log("---") }
  }
  

  /* Cocoa app boilerplate */
  
  @IBOutlet var window        : NSWindow!
  @IBOutlet var logViewParent : NSScrollView!
  @IBOutlet var urlField      : NSTextField!
  
  @IBAction func fetch(sender: AnyObject!) {
    //logView.string = ""
    doStuff()
  }
  
  var logView : NSTextView {
    // NSTextView doesn't work with weak?
    return logViewParent.contentView.documentView as NSTextView
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification?) {
    doStuff()
  }
  
  func applicationWillTerminate(aNotification: NSNotification?) {
  }
  
  
  func log(string: String) {
    // log to shell
    println(string)
    
    // log to view. Careful, must run in main thread!
    dispatch_async(dispatch_get_main_queue()) {
      self.logView.appendString(string + "\n")
    }
  }
  func log() {
    log("")
  }
}

extension NSTextView {
  
  func appendString(string: String) {
    var ls = NSAttributedString(string: string)
    textStorage.appendAttributedString(ls)
    
    let charCount = (self.string as NSString).length
    let r = NSMakeRange(charCount, 0)
    self.scrollRangeToVisible(r)
    
    needsDisplay = true
  }
  
}
