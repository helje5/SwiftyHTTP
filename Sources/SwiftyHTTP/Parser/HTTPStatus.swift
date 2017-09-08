//
//  HTTPStatus.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public enum HTTPStatus : Equatable {
  // Either inherit from Int (and have raw values) OR have cases with associated
  // values. Pretty annoying and results in all the mapping below (which is
  // kinda OK here given that RFCs are static)
  
  case ok, created, accepted, noContent, resetContent, partialContent
  case multiStatus, alreadyReported, imUsed
  
  case multipleChoices, movedPermanently, found, seeOther, notModified
  case useProxy, switchProxy
  case temporaryRedirect
  case resumeIncomplete // vs .PermanentRedirect
  
  case badRequest, unauthorized, 💰Required, forbidden, notFound
  case methodNotAllowed, notAcceptable
  case proxyAuthenticationRequired
  case requestTimeout
  case conflict, gone
  case lengthRequired
  case preconditionFailed
  case requestEntityTooLarge, requestURITooLong
  case unsupportedMediaType
  case requestRangeNotSatisfiable
  case expectationFailed
  case iAmATeapot // there is no teapot Emoji? only a teacan?
  case unprocessableEntity, locked, failedDependency, unorderedCollection
  case upgradeRequired, preconditionRequired
  
  case internalServerError, notImplemented, badGateway, serviceUnavailable
  case gatewayTimeout, httpVersionNotSupported
  case variantAlsoNegotiates
  case insufficientStorage, loopDetected
  case notExtended
  
  case `extension`(Int, String) // status, statusText
}

extension HTTPStatus  {
  
  public var boolValue : Bool {
    return status >= 200 && status < 300
  }
  
}

extension HTTPStatus : RawRepresentable {
  
  public init?(rawValue: Int) {
    self.init(rawValue)
  }
  
  public var rawValue: Int { return self.status }
}

public extension HTTPStatus {
  
  public init(_ status: Int, _ text: String? = nil) {
    switch status {
      case 200: self = .ok
      case 201: self = .created
      case 202: self = .accepted
      case 204: self = .noContent
      case 205: self = .resetContent
      case 206: self = .partialContent
      case 207: self = .multiStatus
      case 208: self = .alreadyReported
      case 226: self = .imUsed // RFC 3229
      
      case 300: self = .multipleChoices
      case 301: self = .movedPermanently
      case 302: self = .found
      case 303: self = .seeOther
      case 304: self = .notModified
      case 305: self = .useProxy
      case 306: self = .switchProxy
      case 307: self = .temporaryRedirect
      case 308: self = .resumeIncomplete
      
      case 400: self = .badRequest
      case 401: self = .unauthorized
      case 402: self = .💰Required
      case 403: self = .forbidden
      case 404: self = .notFound
      case 405: self = .methodNotAllowed
      case 406: self = .notAcceptable
      case 407: self = .proxyAuthenticationRequired
      case 408: self = .requestTimeout
      case 409: self = .conflict
      case 410: self = .gone
      case 411: self = .lengthRequired
      case 412: self = .preconditionFailed
      case 413: self = .requestEntityTooLarge
      case 414: self = .requestURITooLong
      case 415: self = .unsupportedMediaType
      case 416: self = .requestRangeNotSatisfiable
      case 417: self = .expectationFailed
      case 418: self = .iAmATeapot
      case 422: self = .unprocessableEntity
      case 423: self = .locked
      case 424: self = .failedDependency
      case 425: self = .unorderedCollection
      case 426: self = .upgradeRequired
      case 428: self = .preconditionRequired
      
      case 500: self = .internalServerError
      case 501: self = .notImplemented
      case 502: self = .badGateway
      case 503: self = .serviceUnavailable
      case 504: self = .gatewayTimeout
      case 505: self = .httpVersionNotSupported
      case 506: self = .variantAlsoNegotiates
      case 507: self = .insufficientStorage
      case 508: self = .loopDetected
      case 510: self = .notExtended
      
      // FIXME: complete me
      
      default:
        let statusText = text ?? HTTPStatus.textForStatus(status)
        self = .extension(status, statusText)
    }
  }
  
  public var status : Int {
    // You ask: How to maintain the reverse list of the above? Emacs macro!
  
    switch self {
      case .ok:                          return 200
      case .created:                     return 201
      case .accepted:                    return 202
      case .noContent:                   return 204
      case .resetContent:                return 205
      case .partialContent:              return 206
      case .multiStatus:                 return 207
      case .alreadyReported:             return 208
      case .imUsed:                      return 226 // RFC 3229
      
      case .multipleChoices:             return 300
      case .movedPermanently:            return 301
      case .found:                       return 302
      case .seeOther:                    return 303
      case .notModified:                 return 304
      case .useProxy:                    return 305
      case .switchProxy:                 return 306
      case .temporaryRedirect:           return 307
      case .resumeIncomplete:            return 308
      
      case .badRequest:                  return 400
      case .unauthorized:                return 401
      case .💰Required:                  return 402
      case .forbidden:                   return 403
      case .notFound:                    return 404
      case .methodNotAllowed:            return 405
      case .notAcceptable:               return 406
      case .proxyAuthenticationRequired: return 407
      case .requestTimeout:              return 408
      case .conflict:                    return 409
      case .gone:                        return 410
      case .lengthRequired:              return 411
      case .preconditionFailed:          return 412
      case .requestEntityTooLarge:       return 413
      case .requestURITooLong:           return 414
      case .unsupportedMediaType:        return 415
      case .requestRangeNotSatisfiable:  return 416
      case .expectationFailed:           return 417
      case .iAmATeapot:                  return 418
      case .unprocessableEntity:         return 422
      case .locked:                      return 423
      case .failedDependency:            return 424
      case .unorderedCollection:         return 425
      case .upgradeRequired:             return 426
      case .preconditionRequired:        return 428
      
      case .internalServerError:         return 500
      case .notImplemented:              return 501
      case .badGateway:                  return 502
      case .serviceUnavailable:          return 503
      case .gatewayTimeout:              return 504
      case .httpVersionNotSupported:     return 505
      case .variantAlsoNegotiates:       return 506
      case .insufficientStorage:         return 507
      case .loopDetected:                return 508
      case .notExtended:                 return 510
      
      case .extension(let code, _):      return code
    }
  }
  
  public var statusText : String {
    switch self {
      case .extension(_, let text):
        return text
      default:
        return HTTPStatus.textForStatus(self.status)
    }
  }
  
  public static func textForStatus(_ status: Int) -> String {
    // FIXME: complete me for type safety ;-)
    
    switch status {
      case 200: return "OK"
      case 201: return "Created"
      case 204: return "No Content"
      case 207: return "MultiStatus"
        
      case 400: return "Bad Request"
      case 401: return "Unauthorized"
      case 402: return "Payment Required"
      case 403: return "FORBIDDEN"
      case 404: return "NOT FOUND"
      case 405: return "Method not allowed"
        
      default:
        return "Status \(status)" // don't want an Optional here
    }
  }
  
}

extension HTTPStatus : CustomStringConvertible {
  
  public var description: String {
    return "\(status) \(statusText)"
  }
  
}

extension HTTPStatus : ExpressibleByIntegerLiteral {
  // this allows: let status : HTTPStatus = 418
  
  public init(integerLiteral value: Int) {
    self.init(value)
  }
  
}

extension HTTPStatus : Hashable {

  public var hashValue: Int {
    return self.status
  }
  
}

public func ==(lhs: HTTPStatus, rhs: HTTPStatus) -> Bool {
  return lhs.status == rhs.status
}
