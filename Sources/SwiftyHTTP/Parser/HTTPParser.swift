//
//  HTTPParser.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/18/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public enum HTTPParserType {
  case request, response, both
}

public final class HTTPParser {
  
  enum ParseState {
    case idle, url, headerName, headerValue, body
  }
  
  var parser     = http_parser()
  var settings   = http_parser_settings()
  let buffer     = RawByteBuffer(capacity: 4096)
  var parseState = ParseState.idle
  
  var isWiredUp  = false
  var url        : String?
  var lastName   : String?
  var headers    = Dictionary<String, String>(minimumCapacity: 32)
  var body       : [UInt8]?
  
  var message    : HTTPMessage?
  
  public init(type: HTTPParserType = .both) {
    var cType: http_parser_type
    switch type {
      case .request:  cType = HTTP_REQUEST
      case .response: cType = HTTP_RESPONSE
      case .both:     cType = HTTP_BOTH
    }
    http_parser_init(&parser, cType)
    
    /* configure callbacks */
    
    // TBD: what is the better way to do this?
    let ud = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    parser.data = ud
  }
  
  
  /* callbacks */
  
  public func onRequest(_ cb: ((HTTPRequest) -> Void)?) -> Self {
    requestCB = cb
    return self
  }
  public func onResponse(_ cb: ((HTTPResponse) -> Void)?) -> Self {
    responseCB = cb
    return self
  }
  public func onHeaders(_ cb: ((HTTPMessage) -> Bool)?) -> Self {
    headersCB = cb
    return self
  }
  public func onBodyData
    (_ cb: ((HTTPMessage, UnsafePointer<CChar>, UInt) -> Bool)?) -> Self
  {
    bodyDataCB = cb
    return self
  }
  public func resetEventHandlers() {
    requestCB  = nil
    responseCB = nil
    headersCB  = nil
    bodyDataCB = nil
  }
  var requestCB  : ((HTTPRequest)  -> Void)?
  var responseCB : ((HTTPResponse) -> Void)?
  var headersCB  : ((HTTPMessage)  -> Bool)?
  var bodyDataCB : ((HTTPMessage, UnsafePointer<CChar>, UInt) -> Bool)?
  
  
  /* write */
  
  public var bodyIsFinal: Bool {
    return http_body_is_final(&parser) == 0 ? false:true
  }
  
  public func write
    (_ buffer: UnsafePointer<CChar>, _ count: Int) -> HTTPParserError
  {
    // Note: the parser doesn't expect this to be 0-terminated.
    let len = count
    
    if !isWiredUp {
      wireUpCallbacks()
    }
    
    let bytesConsumed = http_parser_execute(&parser, &settings, buffer, len)
    
    let errno = http_errno(parser.http_errno)
    let err   = HTTPParserError(errno)
    
    if err != .ok {
      // Now hitting this, not quite sure why. Maybe a Safari feature?
      let s = http_errno_name(errno)
      let d = http_errno_description(errno)
      debugPrint("BYTES consumed \(bytesConsumed) from \(buffer)[\(len)] " +
                 "ERRNO: \(err) \(s) \(d)")
    }
    return err
  }
  
  public func write(_ buffer: [CChar]) -> HTTPParserError {
    let count = buffer.count
    return write(buffer, count)
  }
  
  
  /* pending data handling */
  
  func clearState() {
    self.url      = nil
    self.lastName = nil
    self.body     = nil
    self.headers.removeAll(keepingCapacity: true)
  }
  
  public func addData(_ data: UnsafePointer<Int8>, length: Int) -> Int32 {
    if parseState == .body && bodyDataCB != nil && message != nil {
      return bodyDataCB!(message!, data, UInt(length)) ? 42 : 0
    }
    else {
      buffer.add(data, length: length)
    }
    return 0
  }
  
  func processDataForState
    (_ state: ParseState, d: UnsafePointer<Int8>, l: Int) -> Int32
  {
    if (state == parseState) { // more data for same field
      return addData(d, length: l)
    }
    
    switch parseState {
      case .headerValue:
        // finished parsing a header
        assert(lastName != nil)
        if let n = lastName {
          headers[n] = buffer.asString()
        }
        buffer.reset()
        lastName = nil
      
      case .headerName:
        assert(lastName == nil)
        lastName = buffer.asString()
        buffer.reset()
      
      case .url:
        assert(url == nil)
        url = buffer.asString()
        buffer.reset()
      
      case .body:
        if bodyDataCB == nil {
          body = buffer.asByteArray()
        }
        buffer.reset()
      
      default: // needs some block, no empty default possible
        break
    }
    
    /* start a new state */
    
    parseState = state
    buffer.reset()
    return addData(d, length: l)
  }
  
  public var isRequest  : Bool { return parser.type == 0 }
  public var isResponse : Bool { return parser.type == 1 }
  
  public class func parserCodeToMethod(_ rq: UInt8) -> HTTPMethod? {
    return parserCodeToMethod(http_method(CUnsignedInt(rq)))
  }
  public class func parserCodeToMethod(_ rq: http_method) -> HTTPMethod? {
    var method : HTTPMethod?
    // Trying to use HTTP_DELETE gives http_method not convertible to
    // _OptionalNilComparisonType
    switch rq { // hardcode C enum value, defines from http_parser n/a
      case HTTP_DELETE:      method = HTTPMethod.delete
      case HTTP_GET:         method = HTTPMethod.get
      case HTTP_HEAD:        method = HTTPMethod.head
      case HTTP_POST:        method = HTTPMethod.post
      case HTTP_PUT:         method = HTTPMethod.put
      case HTTP_CONNECT:     method = HTTPMethod.connect
      case HTTP_OPTIONS:     method = HTTPMethod.options
      case HTTP_TRACE:       method = HTTPMethod.trace
      case HTTP_COPY:        method = HTTPMethod.copy
      case HTTP_LOCK:        method = HTTPMethod.lock
      case HTTP_MKCOL:       method = HTTPMethod.mkcol
      case HTTP_MOVE:        method = HTTPMethod.move
      case HTTP_PROPFIND:    method = HTTPMethod.propfind
      case HTTP_PROPPATCH:   method = HTTPMethod.proppatch
      case HTTP_SEARCH:      method = HTTPMethod.search
      case HTTP_UNLOCK:      method = HTTPMethod.unlock
        
      case HTTP_REPORT:      method = HTTPMethod.report((nil, nil))
        // FIXME: peek body ..
        
      case HTTP_MKACTIVITY:  method = HTTPMethod.mkactivity
      case HTTP_CHECKOUT:    method = HTTPMethod.checkout
      case HTTP_MERGE:       method = HTTPMethod.merge
        
      case HTTP_MSEARCH:     method = HTTPMethod.msearch
      case HTTP_NOTIFY:      method = HTTPMethod.notify
      case HTTP_SUBSCRIBE:   method = HTTPMethod.subscribe
      case HTTP_UNSUBSCRIBE: method = HTTPMethod.unsubscribe
        
      case HTTP_PATCH:      method = HTTPMethod.patch
      case HTTP_PURGE:      method = HTTPMethod.purge
      
      case HTTP_MKCALENDAR: method = HTTPMethod.mkcalendar
      
      default:
        // Note: extra custom methods don't work (I think)
        method = nil
    }
    return method
  }
  
  func headerFinished() -> Int32 {
    self.processDataForState(.body, d: "", l: 0)
    
    message = nil
    
    let major = parser.http_major
    let minor = parser.http_minor
    
    if isRequest {
      let method  = HTTPParser.parserCodeToMethod(http_method(parser.method))
      
      message = HTTPRequest(method: method!, url: url!,
                            version: ( Int(major), Int(minor) ),
                            headers: headers)
      self.clearState()
    }
    else if isResponse {
      let status = parser.status_code
      
      // TBD: also grab status text? Doesn't matter in the real world ...
      message = HTTPResponse(status: HTTPStatus(rawValue: Int(status))!,
                             version: ( Int(major), Int(minor) ),
                             headers: headers)
      self.clearState()
    }
    else { // FIXME: PS style great error handling
      debugPrint("Unexpected message? \(parser.type)")
      assert(parser.type == 0 || parser.type == 1)
    }
    
    if let m = message {
      if  let cb = headersCB {
        return cb(m) ? 0 : 42
      }
    }
    
    return 0
  }
  
  func messageFinished() -> Int32 {
    self.processDataForState(.idle, d: "", l: 0)
    
    if let m = message {
      m.bodyAsByteArray = body
      
      if let rq = m as? HTTPRequest {
        if let cb = requestCB {
          cb(rq)
        }
      }
      else if let res = m as? HTTPResponse {
        if let cb = responseCB {
          cb(res)
        }
      }
      else {
        assert(false, "Expected Request or Response object")
      }
      
      return 0
    }
    else {
      debugPrint("did not parse a message ...")
      return 42
    }
  }
  
  /* callbacks */
  
  func wireUpCallbacks() {
    // Note: CString is NOT a real C string, it's length terminated
    
    settings.on_message_begin = { parser in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.message = nil
      me.clearState()
      return 0
    }
    settings.on_message_complete = { parser in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.messageFinished()
      return 0
    }
    settings.on_headers_complete = { parser in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.headerFinished()
      return 0
    }
    
    settings.on_url = { parser, data, len in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.processDataForState(ParseState.url, d: data!, l: len)
      return 0
    }
    settings.on_header_field = { parser, data, len in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.processDataForState(ParseState.headerName, d: data!, l: len)
      return 0
    }
    settings.on_header_value = { parser, data, len in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.processDataForState(ParseState.headerValue, d: data!, l: len)
      return 0
    }
    settings.on_body = { parser, data, len in
      let me = unsafeBitCast(parser?.pointee.data, to: HTTPParser.self)
      me.processDataForState(ParseState.body, d: data!, l: len)
      return 0
    }
  }
}

extension HTTPParser : CustomStringConvertible {
  
  public var description : String {
    return "<HTTPParser \(parseState) @\(buffer.count)>"
  }
}

public enum HTTPParserError : CustomStringConvertible {
  // manual mapping, Swift doesn't directly bridge the http_parser macros but
  // rather creates constants for them
  case ok
  case cbMessageBegin, cbURL, cbBody, cbMessageComplete, cbStatus
  case cbHeaderField, cbHeaderValue, cbHeadersComplete
  case invalidEOFState, headerOverflow, closedConnection
  case invalidVersion, invalidStatus, invalidMethod, invalidURL
  case invalidHost, invalidPort, invalidPath, invalidQueryString
  case invalidFragment
  case lineFeedExpected
  case invalidHeaderToken, invalidContentLength, invalidChunkSize
  case invalidConstant, invalidInternalState
  case notStrict, paused
  case unknown
  
  public init(_ errcode: http_errno) {
    switch (errcode) {
      case HPE_OK:                     self = .ok
      case HPE_CB_message_begin:       self = .cbMessageBegin
      case HPE_CB_url:                 self = .cbURL
      case HPE_CB_header_field:        self = .cbHeaderField
      case HPE_CB_header_value:        self = .cbHeaderValue
      case HPE_CB_headers_complete:    self = .cbHeadersComplete
      case HPE_CB_body:                self = .cbBody
      case HPE_CB_message_complete:    self = .cbMessageComplete
      case HPE_CB_status:              self = .cbStatus
      case HPE_INVALID_EOF_STATE:      self = .invalidEOFState
      case HPE_HEADER_OVERFLOW:        self = .headerOverflow
      case HPE_CLOSED_CONNECTION:      self = .closedConnection
      case HPE_INVALID_VERSION:        self = .invalidVersion
      case HPE_INVALID_STATUS:         self = .invalidStatus
      case HPE_INVALID_METHOD:         self = .invalidMethod
      case HPE_INVALID_URL:            self = .invalidURL
      case HPE_INVALID_HOST:           self = .invalidHost
      case HPE_INVALID_PORT:           self = .invalidPort
      case HPE_INVALID_PATH:           self = .invalidPath
      case HPE_INVALID_QUERY_STRING:   self = .invalidQueryString
      case HPE_INVALID_FRAGMENT:       self = .invalidFragment
      case HPE_LF_EXPECTED:            self = .lineFeedExpected
      case HPE_INVALID_HEADER_TOKEN:   self = .invalidHeaderToken
      case HPE_INVALID_CONTENT_LENGTH: self = .invalidContentLength
      case HPE_INVALID_CHUNK_SIZE:     self = .invalidChunkSize
      case HPE_INVALID_CONSTANT:       self = .invalidConstant
      case HPE_INVALID_INTERNAL_STATE: self = .invalidInternalState
      case HPE_STRICT:                 self = .notStrict
      case HPE_PAUSED:                 self = .paused
      case HPE_UNKNOWN:                self = .unknown
      default: self = .unknown
    }
  }
  
  public var description : String { return errorDescription }
  
  public var errorDescription : String {
    switch self {
      case .ok:                   return "Success"
      case .cbMessageBegin:       return "The on_message_begin callback failed"
      case .cbURL:                return "The on_url callback failed"
      case .cbBody:               return "The on_body callback failed"
      case .cbMessageComplete:
        return "The on_message_complete callback failed"
      case .cbStatus:             return "The on_status callback failed"
      case .cbHeaderField:        return "The on_header_field callback failed"
      case .cbHeaderValue:        return "The on_header_value callback failed"
      case .cbHeadersComplete:
        return "The on_headers_complete callback failed"
      
      case .invalidEOFState:      return "Stream ended at an unexpected time"
      case .headerOverflow:
        return "Too many header bytes seen; overflow detected"
      case .closedConnection:
        return "Data received after completed connection: close message"
      case .invalidVersion:       return "Invalid HTTP version"
      case .invalidStatus:        return "Invalid HTTP status code"
      case .invalidMethod:        return "Invalid HTTP method"
      case .invalidURL:           return "Invalid URL"
      case .invalidHost:          return "Invalid host"
      case .invalidPort:          return "Invalid port"
      case .invalidPath:          return "Invalid path"
      case .invalidQueryString:   return "Invalid query string"
      case .invalidFragment:      return "Invalid fragment"
      case .lineFeedExpected:     return "LF character expected"
      case .invalidHeaderToken:   return "Invalid character in header"
      case .invalidContentLength:
        return "Invalid character in content-length header"
      case .invalidChunkSize:     return "Invalid character in chunk size header"
      case .invalidConstant:      return "Invalid constant string"
      case .invalidInternalState: return "Encountered unexpected internal state"
      case .notStrict:            return "Strict mode assertion failed"
      case .paused:               return "Parser is paused"
      default:                   return "Unknown Error"
    }
  }
}
