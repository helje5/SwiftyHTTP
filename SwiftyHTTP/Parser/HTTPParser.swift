//
//  HTTPParser.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/18/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public enum HTTPParserType {
  case Request, Response, Both
}

public final class HTTPParser {
  
  enum ParseState {
    case Idle, URL, HeaderName, HeaderValue, Body
  }
  
  let parser     : COpaquePointer = nil
  let buffer     = RawByteBuffer(capacity: 4096)
  var parseState = ParseState.Idle
  
  var isWiredUp  = false
  var url        : String?
  var lastName   : String?
  var headers    = Dictionary<String, String>(minimumCapacity: 32)
  var body       : [UInt8]?
  
  var message    : HTTPMessage?
  
  
  public init(type: HTTPParserType = .Both) {
    var cType: http_parser_type
    switch type {
      case .Request:  cType = HTTP_REQUEST
      case .Response: cType = HTTP_RESPONSE
      case .Both:     cType = HTTP_BOTH
    }
    parser = http_parser_init(cType)
  }
  deinit {
    http_parser_free(parser)
  }
  
  
  /* callbacks */
  
  public func onRequest(cb: ((HTTPRequest) -> Void)?) -> Self {
    requestCB = cb
    return self
  }
  public func onResponse(cb: ((HTTPResponse) -> Void)?) -> Self {
    responseCB = cb
    return self
  }
  public func onHeaders(cb: ((HTTPMessage) -> Bool)?) -> Self {
    headersCB = cb
    return self
  }
  public func onBodyData
    (cb: ((HTTPMessage, UnsafePointer<CChar>, UInt) -> Bool)?) -> Self
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
    return http_body_is_final(parser) == 0 ? false:true
  }
  
  public func write
    (buffer: UnsafePointer<CChar>, _ count: Int) -> HTTPParserError
  {
    // Note: the parser doesn't expect this to be 0-terminated.
    let len = UInt(count)
    
    if !isWiredUp {
      wireUpCallbacks()
    }
    
    let bytesConsumed = http_parser_execute(self.parser, buffer, len)
    
    let errno = http_parser_get_errno(parser)
    let err   = HTTPParserError(errno)
    
    if err != .OK {
      // Now hitting this, not quite sure why. Maybe a Safari feature?
      let s = http_errno_name(errno)
      let d = http_errno_description(errno)
      println("BYTES consumed \(bytesConsumed) from \(buffer)[\(len)] " +
              "ERRNO: \(err) \(s) \(d)")
    }
    return err
  }
  
  public func write(buffer: [CChar]) -> HTTPParserError {
    let count = buffer.count
    return write(buffer, count)
  }
  
  
  /* pending data handling */
  
  func clearState() {
    self.url      = nil
    self.lastName = nil
    self.body     = nil
    self.headers.removeAll(keepCapacity: true)
  }
  
  public func addData(data: UnsafePointer<CChar>, length: UInt) -> Int32 {
    if parseState == .Body && bodyDataCB != nil && message != nil {
      return bodyDataCB!(message!, data, length) ? 42 : 0
    }
    else {
      buffer.add(data, length: Int(length))
    }
    return 0
  }
  
  func processDataForState
    (state: ParseState, d: UnsafePointer<CChar>, l: UInt) -> Int32
  {
    if (state == parseState) { // more data for same field
      return addData(d, length: l)
    }
    
    switch parseState {
      case .HeaderValue:
        // finished parsing a header
        assert(lastName != nil)
        if let n = lastName {
          headers[n] = buffer.asString()
        }
        buffer.reset()
        lastName = nil
      
      case .HeaderName:
        assert(lastName == nil)
        lastName = buffer.asString()
        buffer.reset()
      
      case .URL:
        assert(url == nil)
        url = buffer.asString()
        buffer.reset()
      
      case .Body:
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
  
  public var isRequest  : Bool { return http_parser_get_type(parser) == 0 }
  public var isResponse : Bool { return http_parser_get_type(parser) == 1 }
  
  public class func parserCodeToMethod(rq: CUnsignedInt) -> HTTPMethod? {
    return parserCodeToMethod(http_method(rq))
  }
  public class func parserCodeToMethod(rq: http_method) -> HTTPMethod? {
    var method : HTTPMethod?
    // Trying to use HTTP_DELETE gives http_method not convertible to
    // _OptionalNilComparisonType
    switch rq { // hardcode C enum value, defines from http_parser n/a
      case HTTP_DELETE:      method = HTTPMethod.DELETE
      case HTTP_GET:         method = HTTPMethod.GET
      case HTTP_HEAD:        method = HTTPMethod.HEAD
      case HTTP_POST:        method = HTTPMethod.POST
      case HTTP_PUT:         method = HTTPMethod.PUT
      case HTTP_CONNECT:     method = HTTPMethod.CONNECT
      case HTTP_OPTIONS:     method = HTTPMethod.OPTIONS
      case HTTP_TRACE:       method = HTTPMethod.TRACE
      case HTTP_COPY:        method = HTTPMethod.COPY
      case HTTP_LOCK:        method = HTTPMethod.LOCK
      case HTTP_MKCOL:       method = HTTPMethod.MKCOL
      case HTTP_MOVE:        method = HTTPMethod.MOVE
      case HTTP_PROPFIND:    method = HTTPMethod.PROPFIND
      case HTTP_PROPPATCH:   method = HTTPMethod.PROPPATCH
      case HTTP_SEARCH:      method = HTTPMethod.SEARCH
      case HTTP_UNLOCK:      method = HTTPMethod.UNLOCK
        
      case HTTP_REPORT:      method = HTTPMethod.REPORT((nil, nil))
        // FIXME: peek body ..
        
      case HTTP_MKACTIVITY:  method = HTTPMethod.MKACTIVITY
      case HTTP_CHECKOUT:    method = HTTPMethod.CHECKOUT
      case HTTP_MERGE:       method = HTTPMethod.MERGE
        
      case HTTP_MSEARCH:     method = HTTPMethod.MSEARCH
      case HTTP_NOTIFY:      method = HTTPMethod.NOTIFY
      case HTTP_SUBSCRIBE:   method = HTTPMethod.SUBSCRIBE
      case HTTP_UNSUBSCRIBE: method = HTTPMethod.UNSUBSCRIBE
        
      case HTTP_PATCH:      method = HTTPMethod.PATCH
      case HTTP_PURGE:      method = HTTPMethod.PURGE
      
      case HTTP_MKCALENDAR: method = HTTPMethod.MKCALENDAR
      
      default:
        // Note: extra custom methods don't work (I think)
        method = nil
    }
    return method
  }
  
  func headerFinished() -> Int32 {
    self.processDataForState(.Body, d: "", l: 0)
    
    message = nil
    
    var major : CUnsignedShort = 1
    var minor : CUnsignedShort = 1
    
    if isRequest {
      var rq : CUnsignedInt = 0
      http_parser_get_request_info(parser, &major, &minor, &rq)
      
      var method  = HTTPParser.parserCodeToMethod(rq)
      
      message = HTTPRequest(method: method!, url: url!,
                            version: ( Int(major), Int(minor) ),
                            headers: headers)
      self.clearState()
    }
    else if isResponse {
      var status : CUnsignedInt = 200
      http_parser_get_response_info(parser, &major, &minor, &status)
      
      // TBD: also grab status text? Doesn't matter in the real world ...
      message = HTTPResponse(status: HTTPStatus(Int(status)),
                             version: ( Int(major), Int(minor) ),
                             headers: headers)
      self.clearState()
    }
    else { // FIXME: PS style great error handling
      let msgtype = http_parser_get_type(parser)
      println("Unexpected message? \(msgtype)")
      assert(msgtype == 0 || msgtype == 1)
    }
    
    if let m = message {
      if  let cb = headersCB {
        return cb(m) ? 0 : 42
      }
    }
    
    return 0
  }
  
  func messageFinished() -> Int32 {
    self.processDataForState(.Idle, d: "", l: 0)
    
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
      println("did not parse a message ...")
      return 42
    }
  }
  
  /* callbacks */
  
  func wireUpCallbacks() {
    // http_cb      => (p: COpaquePointer) -> Int32
    // http_data_cb => (p: COpaquePointer, d: CString, l: UInt)
    // Note: CString is NOT a real C string, it's length terminated
    http_parser_set_on_message_begin(parser, {
      [unowned self] (_: COpaquePointer) -> Int32 in
      self.message  = nil
      self.clearState()
      return 0
    })
    http_parser_set_on_message_complete(parser, {
      [unowned self] (_: COpaquePointer) -> Int32 in
      self.messageFinished()
     })
    http_parser_set_on_headers_complete(parser) {
      [unowned self] (_: COpaquePointer) -> Int32 in
      self.headerFinished()
    }
    http_parser_set_on_url(parser) { [unowned self] in
      self.processDataForState(.URL, d: $1, l: $2)
    }
    http_parser_set_on_header_field(parser) { [unowned self] in
      self.processDataForState(.HeaderName, d: $1, l: $2)
    }
    http_parser_set_on_header_value(parser) { [unowned self] in
      self.processDataForState(.HeaderValue, d: $1, l: $2)
    }
    http_parser_set_on_body(parser) { [unowned self] in
      self.processDataForState(.Body, d: $1, l: $2)
    }
  }
}

extension HTTPParser : Printable {
  
  public var description : String {
    return "<HTTPParser \(parseState) @\(buffer.count)>"
  }
}

public enum HTTPParserError : Printable {
  // manual mapping, Swift doesn't directly bridge the http_parser macros but
  // rather creates constants for them
  case OK
  case cbMessageBegin, cbURL, cbBody, cbMessageComplete, cbStatus
  case cbHeaderField, cbHeaderValue, cbHeadersComplete
  case InvalidEOFState, HeaderOverflow, ClosedConnection
  case InvalidVersion, InvalidStatus, InvalidMethod, InvalidURL
  case InvalidHost, InvalidPort, InvalidPath, InvalidQueryString
  case InvalidFragment
  case LineFeedExpected
  case InvalidHeaderToken, InvalidContentLength, InvalidChunkSize
  case InvalidConstant, InvalidInternalState
  case NotStrict, Paused
  case Unknown
  
  public init(_ errcode: http_errno) {
    switch (errcode) {
      case HPE_OK:                     self = .OK
      case HPE_CB_message_begin:       self = .cbMessageBegin
      case HPE_CB_url:                 self = .cbURL
      case HPE_CB_header_field:        self = .cbHeaderField
      case HPE_CB_header_value:        self = .cbHeaderValue
      case HPE_CB_headers_complete:    self = .cbHeadersComplete
      case HPE_CB_body:                self = .cbBody
      case HPE_CB_message_complete:    self = .cbMessageComplete
      case HPE_CB_status:              self = .cbStatus
      case HPE_INVALID_EOF_STATE:      self = .InvalidEOFState
      case HPE_HEADER_OVERFLOW:        self = .HeaderOverflow
      case HPE_CLOSED_CONNECTION:      self = .ClosedConnection
      case HPE_INVALID_VERSION:        self = .InvalidVersion
      case HPE_INVALID_STATUS:         self = .InvalidStatus
      case HPE_INVALID_METHOD:         self = .InvalidMethod
      case HPE_INVALID_URL:            self = .InvalidURL
      case HPE_INVALID_HOST:           self = .InvalidHost
      case HPE_INVALID_PORT:           self = .InvalidPort
      case HPE_INVALID_PATH:           self = .InvalidPath
      case HPE_INVALID_QUERY_STRING:   self = .InvalidQueryString
      case HPE_INVALID_FRAGMENT:       self = .InvalidFragment
      case HPE_LF_EXPECTED:            self = .LineFeedExpected
      case HPE_INVALID_HEADER_TOKEN:   self = .InvalidHeaderToken
      case HPE_INVALID_CONTENT_LENGTH: self = .InvalidContentLength
      case HPE_INVALID_CHUNK_SIZE:     self = .InvalidChunkSize
      case HPE_INVALID_CONSTANT:       self = .InvalidConstant
      case HPE_INVALID_INTERNAL_STATE: self = .InvalidInternalState
      case HPE_STRICT:                 self = .NotStrict
      case HPE_PAUSED:                 self = .Paused
      case HPE_UNKNOWN:                self = .Unknown
      default: self = .Unknown
    }
  }
  
  public var description : String { return errorDescription }
  
  public var errorDescription : String {
    switch self {
      case OK:                   return "Success"
      case cbMessageBegin:       return "The on_message_begin callback failed"
      case cbURL:                return "The on_url callback failed"
      case cbBody:               return "The on_body callback failed"
      case cbMessageComplete:
        return "The on_message_complete callback failed"
      case cbStatus:             return "The on_status callback failed"
      case cbHeaderField:        return "The on_header_field callback failed"
      case cbHeaderValue:        return "The on_header_value callback failed"
      case cbHeadersComplete:
        return "The on_headers_complete callback failed"
      
      case InvalidEOFState:      return "Stream ended at an unexpected time"
      case HeaderOverflow:
        return "Too many header bytes seen; overflow detected"
      case ClosedConnection:
        return "Data received after completed connection: close message"
      case InvalidVersion:       return "Invalid HTTP version"
      case InvalidStatus:        return "Invalid HTTP status code"
      case InvalidMethod:        return "Invalid HTTP method"
      case InvalidURL:           return "Invalid URL"
      case InvalidHost:          return "Invalid host"
      case InvalidPort:          return "Invalid port"
      case InvalidPath:          return "Invalid path"
      case InvalidQueryString:   return "Invalid query string"
      case InvalidFragment:      return "Invalid fragment"
      case LineFeedExpected:     return "LF character expected"
      case InvalidHeaderToken:   return "Invalid character in header"
      case InvalidContentLength:
        return "Invalid character in content-length header"
      case InvalidChunkSize:     return "Invalid character in chunk size header"
      case InvalidConstant:      return "Invalid constant string"
      case InvalidInternalState: return "Encountered unexpected internal state"
      case NotStrict:            return "Strict mode assertion failed"
      case Paused:               return "Parser is paused"
      default:                   return "Unknown Error"
    }
  }
}


/* hack to make some structs work */
// FIXME: can't figure out how to access errcode.value. Maybe because it
//        is not 'public'?

extension http_errno : Equatable {
  // struct: init(_ value: UInt32); var value: UInt32;
}
extension http_method : Equatable {
  // struct: init(_ value: UInt32); var value: UInt32;
}
public func ==(lhs: http_errno, rhs: http_errno) -> Bool {
  // this just recurses (of course):
  //   return lhs == rhs
  // this failes, maybe because it's not public?:
  //   return lhs.value == rhs.value
  // Hard hack, does it actually work? :-)
  return isByteEqual(lhs, rhs)
}
public func ==(lhs: http_method, rhs: http_method) -> Bool {
  return isByteEqual(lhs, rhs)
}
