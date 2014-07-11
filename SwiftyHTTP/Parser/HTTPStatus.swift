//
//  HTTPStatus.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/19/14.
//  Copyright (c) 2014 Helge Hess. All rights reserved.
//

enum HTTPStatus {
  // Either inherit from Int (and have raw values) OR have cases with arguments
  // Slightly annoying.
  
  case OK, Created, Accepted, NoContent, ResetContent, PartialContent
  case MultiStatus, AlreadyReported
  
  case MultipleChoices, MovedPermanently, Found, SeeOther, NotModified
  case UseProxy, SwitchProxy
  case TemporaryRedirect
  case ResumeIncomplete
  
  case BadRequest, Unauthorized, 💰Required, Forbidden, NotFound
  case MethodNotAllowed, NotAcceptable
  case ProxyAuthenticationRequired
  case RequestTimeout
  case Conflict, Gone
  case LengthRequired
  case PreconditionFailed
  case RequestEntityTooLarge, RequestURITooLong
  case UnsupportedMediaType
  case RequestRangeNotSatisfiable
  case ExpectationFailed
  case IAmATeapot // there is no teapot Emoji? only a teacan?
  case UnprocessableEntity, Locked, FailedDependency, UnorderedCollection
  case UpgradeRequired
  
  case InternalServerError, NotImplemented, BadGateway, ServiceUnavailable
  case GatewayTimeout, HTTPVersioNotSupported
  case VariantAlsoNegotiates
  case InsufficientStorage, LoopDetected
  case NotExtended
  
  case Extension(Int, String) // status, statusText
}

extension HTTPStatus {
  
  init(_ status: Int, _ text: String? = nil) {
    switch status {
      case 200: self = .OK
      case 201: self = .Created
      case 204: self = .NoContent
      case 207: self = .MultiStatus
      
      case 400: self = .BadRequest
      case 401: self = .Unauthorized
      case 402: self = .💰Required
      case 403: self = .Forbidden
      case 404: self = .NotFound
      case 405: self = .MethodNotAllowed
      case 406: self = .NotAcceptable
      case 407: self = .ProxyAuthenticationRequired
      case 408: self = .RequestTimeout
      
      case 500: self = .InternalServerError
      case 501: self = .NotImplemented
      
      // FIXME: complete me
      
      default:
        let statusText = text ? text! : HTTPStatus.textForStatus(status)
        self = .Extension(status, statusText)
    }
  }
  
  var status : Int {
    // FIXME: complete me
  
    switch self {
      case .OK:                  return 200
      case .Created:             return 201
      case .NoContent:           return 204
      case .MultiStatus:         return 207
      
      case .BadRequest:          return 400
      case .Unauthorized:        return 401
      case .💰Required:          return 402
      case .Forbidden:           return 403
      case .NotFound:            return 404
      case .MethodNotAllowed:    return 405
      case .NotAcceptable:       return 406
      case .ProxyAuthenticationRequired: return 407
      case .RequestTimeout:      return 408
      
      case .InternalServerError: return 500
      case .NotImplemented:      return 501
      
      case .Extension(let code, _): return code
      
      default:
        return -1 // don't want an Optional here
    }
  }
  
  var statusText : String {
    switch self {
      case .Extension(_, let text):
        return text
      default:
        return HTTPStatus.textForStatus(self.status)
    }
  }
  
  static func textForStatus(status: Int) -> String {
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

extension HTTPStatus : Printable {
  
  var description: String {
    return "\(status) \(statusText)"
  }
  
}
