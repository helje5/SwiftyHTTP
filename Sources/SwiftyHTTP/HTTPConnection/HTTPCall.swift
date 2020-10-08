//
//  HTTPCall.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 7/7/14.
//  Copyright (c) 2014-2020 Always Right Institute. All rights reserved.
//

import Dispatch

/**
 * Sample:
 *   GET("http://www.apple.com/")
 *     .done   { print("got \($0): \($1)")     }
 *     .fail   { print("failed \($0): \($1)")  }
 *     .always { print("we are done here ...") }
 */
public func GET(_ url: URL, headers: Dictionary<String, String> = [:],
                version: ( Int, Int ) = HTTPv11) -> HTTPCall
{
  func isURLOK(_ url: URL) -> Bool {
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
    let rq   = HTTPRequest(method: HTTPMethod.get, url: "/")
    let call = HTTPCall(url: url, request: rq)
    call.stopWithError(.urlMalformed)
    return call
  }
  
  /* prepare request */
  let request = HTTPRequest(method:  HTTPMethod.get,
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

public func GET(_ url: String, headers: Dictionary<String, String> = [:],
                version: ( Int, Int ) = HTTPv11) -> HTTPCall
{
  return GET(parse_url(url), headers: headers, version: version)
}



let dnsQueue     = DispatchQueue.global(qos: .default)
let lockQueue    = DispatchQueue(label: "com.ari.SwiftyHTTPCall", attributes: [])
var runningCalls = [ HTTPCall ]()
let userAgent    = "AlwaysRightInstitute-SwiftyHTTP/0.42 (Macintozh) (Roxx)"

var callCounter  = 0

open class HTTPCall : Equatable {
  
  public enum Error : CustomStringConvertible {
    case dnsLookup, connect, urlMalformed
    
    public var description : String {
      switch self {
        case .dnsLookup:    return "DNS lookup failed"
        case .connect:      return "Could not connect to server"
        case .urlMalformed: return "Given URL cannot be processed"
      }
    }
  }
  
  enum State {
    case idle
    case dnsLookup, connect, send, receive
    // case Fail(Error) // didn't quite get this to work right
    // eg, this doesn't work anymore: assert(state == .Idle)?
    case fail
    case done // case Done(HTTPResponse)
    
    var isFinished : Bool {
      return self == .fail || self == .done
    }
  }
  
  public let url     : URL
  public let request : HTTPRequest
  let debugOn        = true
  let callID         : Int
  
  var state          : State  = .idle
  var error          : Error? = nil // FIXME: should be an associated value
  var connection     : HTTPConnection?
  var response       : HTTPResponse?
  
  public init(url: URL, request: HTTPRequest) {
    self.url     = url
    self.request = request
    
    var nextID = 0
    lockQueue.sync {
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
  
  open func done(_ cb: @escaping ( HTTPRequest, HTTPResponse ) -> Void) -> Self {
    if state == .done {
      cb(request, response!)
    }
    else if state == .fail {
      // noop
    }
    else {
      successCB = cb
    }
    return self
  }
  open func fail(_ cb: @escaping ( HTTPRequest, Error ) -> Void) -> Self {
    if state == .fail {
      cb(request, error!)
    }
    else if state == .done {
      // noop
    }
    else {
      failCB = cb
    }
    return self
  }
  open func always(_ cb: @escaping ( HTTPRequest, HTTPResponse?, Error? ) -> Void) -> Self {
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
  
  @discardableResult
  open func done(_ cb: @escaping ( HTTPResponse ) -> Void) -> Self {
    return done { _, res in cb(res) }
  }
  @discardableResult
  open func fail(_ cb: @escaping ( Error ) -> Void) -> Self {
    return fail { _, res in cb(res) }
  }
  @discardableResult
  open func always(_ cb: @escaping ( HTTPResponse?, Error? ) -> Void) -> Self {
    return always { _, res, error in cb(res, error) }
  }
  @discardableResult
  open func always(_ cb: @escaping () -> Void) -> Self {
    return always { _, _, _ in cb() }
  }
  
  
  /* main runner */
  
  open func run() {
    assert(state == State.idle)
    
    /* keep reference around, even if the caller does not */
    lockQueue.async {
      runningCalls.append(self)
    }
    
    /* start the twisting */
    doLookup()
  }
  
  func unregister() {
    if self.debugOn {
      print("HC(\(callID)) unregister ...")
    }
    lockQueue.async {
      let idxOrNot = runningCalls.firstIndex(of: self)
      // assert(idxOrNot != nil)
      if let idx = idxOrNot {
        runningCalls.remove(at: idx)
      }
      else {
        print("HC(\(self.callID)) ERROR: did not find call \(self)")
      }
    }
  }
  
  func stopWithError(_ error: Error) {
    if self.debugOn {
      print("HC(\(callID)) stop on error \(self.error as Any)")
    }
    
    // would like: state = .Fail(error)
    self.error = error
    self.state = .fail
    
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
    assert(state == .idle)
    state = .dnsLookup
    
    dnsQueue.async { () -> Void in
      gethoztbyname(self.url.host!, flags: AI_CANONNAME) {
        ( name, _, address : sockaddr_in? ) -> Void in
        if let address = address {
          var addr = address
          addr.port = self.url.portOrDefault!
          if self.debugOn {
            print("HC(\(self.callID)) resolved host \(name): \(address)")
          }
          self.doConnect(addr)
        }
        else {
          self.stopWithError(.dnsLookup)
        }
      }
    }
  }
  
  func doConnect(_ address: sockaddr_in) {
    assert(state == .dnsLookup)
    state = .connect
    
    // FIXME: keep pool
    let socket = ActiveSocketIPv4()!
    
    // this callback setup is not quite right yet, we need to pass over errors
    let ok = socket.connect(address) {_ in
      if self.debugOn {
        debugPrint(
          "HC(\(self.callID)) connected to \(socket.remoteAddress as Any)")
      }
      
      self.connection = HTTPConnection(socket)
        .onResponse(self.handleResponse)
        .onClose(self.handleClose)
      
      /* send HTTP request */
      self.state = .send
      
      self.connection!.sendRequest(self.request) {
        // TBD: is the timing of this quite right?
        self.state = .receive
        if self.debugOn {
          debugPrint("HC(\(self.callID)) did send request \(self.request)")
        }
      }
      
      // OK, now the stack rewinds, the response is coming in as a separate
      // callback
    }
    
    if !ok {
      stopWithError(.connect)
    }
  }
  
  func handleResponse(_ res: HTTPResponse, _ con: HTTPConnection) {
    if self.debugOn {
      print("HC(\(callID)) got response \(res): \(con)")
    }
    
    self.state = .done
    
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
  
  func handleClose(_ fd: FileDescriptor) {
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
