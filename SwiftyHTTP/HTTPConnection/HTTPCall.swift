//
//  HTTPCall.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 7/7/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

import Dispatch

/**
 * Sample:
 *   GET("http://www.apple.com/")
 *     .done   { print("got \($0): \($1)")     }
 *     .fail   { print("failed \($0): \($1)")  }
 *     .always { print("we are done here ...") }
 */
public func GET(url: URL, headers: Dictionary<String, String> = [:],
                version: ( Int, Int ) = HTTPv11) -> HTTPCall
{
  func isURLOK(url: URL) -> Bool {
    guard url.scheme != nil && url.scheme == "http" else {
      print("url has no http scheme?")
      return false
    }
    guard url.host != nil else {
      print("url has no host?")
      return false
    }
    
    return true
  }
  
  /* check URL */
  guard isURLOK(url) else {
    let rq   = HTTPRequest(method: HTTPMethod.GET, url: "/")
    let call = HTTPCall(url: url, request: rq)
    call.stopWithError(.URLMalformed)
    return call
  }
  
  /* prepare request */
  let request = HTTPRequest(method:  HTTPMethod.GET,
                            url:     url.pathWithQueryAndFragment,
                            version: version, headers: headers)
  if let hp = url.hostAndPort {
    request["Host"]          = hp
  }
  request["User-Agent"]      = userAgent
  request["X-Q-AlwaysRight"] = "Yes, indeed"
  request["Content-Length"]  = "0"
  request["Connection"]      = "Close" // until we have a pool
  
  /* and go! */
  let call = HTTPCall(url: url, request: request)
  call.run()
  return call
}

public func GET(url: String, headers: Dictionary<String, String> = [:],
                version: ( Int, Int ) = HTTPv11) -> HTTPCall
{
  return GET(parse_url(url), headers: headers, version: version)
}



let dnsQueue     = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
let lockQueue    = dispatch_queue_create("com.ari.SwiftyHTTPCall", nil)!
var runningCalls = [HTTPCall]()
let userAgent    = "AlwaysRightInstitute-SwiftyHTTP/0.42 (Macintozh) (Roxx)"

var callCounter  = 0

public class HTTPCall : Equatable {
  
  public enum Error : CustomStringConvertible {
    case DNSLookup, Connect, URLMalformed
    
    public var description : String {
      switch self {
        case DNSLookup:    return "DNS lookup failed"
        case Connect:      return "Could not connect to server"
        case URLMalformed: return "Given URL cannot be processed"
      }
    }
  }
  
  enum State {
    case Idle
    case DNSLookup, Connect, Send, Receive
    // case Fail(Error) // didn't quite get this to work right
    // eg, this doesn't work anymore: assert(state == .Idle)?
    case Fail
    case Done // case Done(HTTPResponse)
    
    var isFinished : Bool {
      return self == .Fail || self == .Done
    }
  }
  
  public let url     : URL
  public let request : HTTPRequest
  let debugOn        = true
  let callID         : Int
  
  var state          : State  = .Idle
  var error          : Error? = nil // FIXME: should be an associated value
  var connection     : HTTPConnection?
  var response       : HTTPResponse?
  
  public init(url: URL, request: HTTPRequest) {
    self.url     = url
    self.request = request
    
    var nextID = 0
    dispatch_sync(lockQueue) {
      callCounter += 1
      nextID = callCounter // cannot use self.callID in here
    }
    self.callID = nextID
  }
  deinit {
    if debugOn {
      print("HC(\(callID)): deinit HTTPCall ...")
    }
  }
  
  
  /* callbacks (check for incorrect locking) */
  
  public func done(cb: ( HTTPRequest, HTTPResponse ) -> Void) -> Self {
    if state == .Done {
      cb(request, response!)
    }
    else if state == .Fail {
      // noop
    }
    else {
      successCB = cb
    }
    return self
  }
  public func fail(cb: ( HTTPRequest, Error ) -> Void) -> Self {
    if state == .Fail {
      cb(request, error!)
    }
    else if state == .Done {
      // noop
    }
    else {
      failCB = cb
    }
    return self
  }
  public func always(cb: ( HTTPRequest, HTTPResponse?, Error? ) -> Void) -> Self {
    if state.isFinished {
      cb(request, response, error)
    }
    else {
      alwaysCB = cb
    }
    return self
  }
  
  var successCB : (( HTTPRequest, HTTPResponse ) -> Void)? = nil
  var failCB    : (( HTTPRequest, Error )        -> Void)? = nil
  var alwaysCB  : (( HTTPRequest, HTTPResponse?, Error? ) -> Void)? = nil
  
  
  /* convenience callbacks with less arguments */
  
  public func done(cb: ( HTTPResponse ) -> Void) -> Self {
    return done { _, res in cb(res) }
  }
  public func fail(cb: ( Error ) -> Void) -> Self {
    return fail { _, res in cb(res) }
  }
  public func always(cb: ( HTTPResponse?, Error? ) -> Void) -> Self {
    return always { _, res, error in cb(res, error) }
  }
  public func always(cb: () -> Void) -> Self {
    return always { _, _, _ in cb() }
  }
  
  
  /* main runner */
  
  public func run() {
    assert(state == State.Idle)
    
    /* keep reference around, even if the caller does not */
    dispatch_async(lockQueue) {
      runningCalls.append(self)
    }
    
    /* start the twisting */
    doLookup()
  }
  
  func unregister() {
    if self.debugOn {
      print("HC(\(callID)) unregister ...")
    }
    dispatch_async(lockQueue) {
      let idxOrNot = runningCalls.indexOf(self)
      // assert(idxOrNot != nil)
      if let idx = idxOrNot {
        runningCalls.removeAtIndex(idx)
      }
      else {
        print("HC(\(self.callID)) ERROR: did not find call \(self)")
      }
    }
  }
  
  func stopWithError(error: Error) {
    if self.debugOn {
      print("HC(\(callID)) stop on error \(self.error)")
    }
    
    // would like: state = .Fail(error)
    self.error = error
    self.state = .Fail
    
    if let cb = failCB {
      cb(request, error)
      failCB = nil
    }
    if let cb = alwaysCB {
      cb(request, nil, error)
      alwaysCB = nil
    }
    
    /* always close connection on errors */
    if let con = connection {
      con.close()
    }
    
    unregister()
  }
  
  
  /* sub-operations */
  
  func doLookup() {
    assert(state == .Idle)
    state = .DNSLookup
    
    dispatch_async(dnsQueue) { () -> Void in
      gethoztbyname(self.url.host!, flags: AI_CANONNAME) {
        ( name, _, address : sockaddr_in? ) -> Void in
        if address != nil {
          var addr = address!
          addr.port = self.url.portOrDefault!
          if self.debugOn {
            print("HC(\(self.callID)) resolved host \(name): \(address)")
          }
          self.doConnect(addr)
        }
        else {
          self.stopWithError(.DNSLookup)
        }
      }
    }
  }
  
  func doConnect(address: sockaddr_in) {
    assert(state == .DNSLookup)
    state = .Connect
    
    // FIXME: keep pool
    let socket = ActiveSocketIPv4()!
    
    // this callback setup is not quite right yet, we need to pass over errors
    let ok = socket.connect(address) {_ in
      if self.debugOn {
        debugPrint("HC(\(self.callID)) connected to \(socket.remoteAddress)")
      }
      
      self.connection = HTTPConnection(socket)
        .onResponse(self.handleResponse)
        .onClose(self.handleClose)
      
      /* send HTTP request */
      self.state = .Send
      
      self.connection!.sendRequest(self.request) {
        // TBD: is the timing of this quite right?
        self.state = .Receive
        if self.debugOn {
          debugPrint("HC(\(self.callID)) did send request \(self.request)")
        }
      }
      
      // OK, now the stack rewinds, the response is coming in as a separate
      // callback
    }
    
    if !ok {
      stopWithError(.Connect)
    }
  }
  
  func handleResponse(res: HTTPResponse, _ con: HTTPConnection) {
    if self.debugOn {
      print("HC(\(callID)) got response \(res): \(con)")
    }
    
    self.state = .Done
    
    if let cb = successCB {
      cb(request, res)
      successCB = nil
    }
    if let cb = alwaysCB {
      cb(request, res, nil)
      alwaysCB = nil
    }
    
    unregister()
    
    // In here we should put the socket into a pool, if it's still open.
    /* close connection until we actually have a pool ... */
    if let con = connection {
      con.close()
      connection = nil
    }
  }
  
  func handleClose(fd: FileDescriptor) {
    if self.debugOn {
      print("HC(\(callID)) close \(fd)")
    }
    
    /* Nope, unregister happens at the end of the request */
    // No: unregister()
  }
}

public func ==(lhs: HTTPCall, rhs: HTTPCall) -> Bool {
  // required for find() above
  // hm, this is, well, a little bit questionable. But there is no 'find'
  // which takes a predicate? (instead of requiring Equatable)
  return lhs === rhs
}
