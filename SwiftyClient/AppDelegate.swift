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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  
  func doStuff() {
    log("Fetch: \(urlField.stringValue)")
    
    GET(urlField.stringValue)
      .done { rq, res in
        self.log()
        self.log("request  \(rq)")
        self.log("response \(res)")
        self.log("body:\n\(res.bodyAsString ?? "-")")
      }
      .fail { rq, err in
        self.log("failed \(rq): \(err)")
      }
      .always { self.log("---") }
  }
  

  /* Cocoa app boilerplate */
  
  @IBOutlet var window        : NSWindow!
  @IBOutlet var logViewParent : NSScrollView!
  @IBOutlet var urlField      : NSTextField!
  
  @IBAction func fetch(_ sender: AnyObject!) {
    //logView.string = ""
    doStuff()
  }
  
  var logView : NSTextView {
    // NSTextView doesn't work with weak?
    return logViewParent.contentView.documentView as! NSTextView
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    doStuff()
  }
  
  func applicationWillTerminate(aNotification: NSNotification) {
  }
  
  
  func log(_ string: String) {
    // log to shell
    print(string)
    
    // log to view. Careful, must run in main thread!
    DispatchQueue.main.async {
      self.logView.appendString(string + "\n")
    }
  }
  func log() {
    log("")
  }
}

extension NSTextView {
  
  func appendString(_ string: String) {
    if let ts = textStorage {
      let ls = NSAttributedString(string: string)
      ts.append(ls)
    }
    let s = self.string
    let charCount = (s as NSString).length
    self.scrollRangeToVisible(NSMakeRange(charCount, 0))
    needsDisplay = true
  }
}
