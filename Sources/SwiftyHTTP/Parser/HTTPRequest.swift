//
//  HTTPRequest.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/25/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

public let HTTPv11 = ( major: 1, minor: 1 )
public let HTTPv10 = ( major: 1, minor: 0 )
public let HTTPv09 = ( major: 0, minor: 9 )

public class HTTPRequest : HTTPMessage {
  
  public let method : HTTPMethod
  public let url    : URL
  
  public var path : String {
    assert(url.path != nil, "HTTP request URL has no path?!")
    return url.path ?? ""
  }
  
  public init(method: HTTPMethod, url: URL, version: ( Int, Int ) = HTTPv11,
              headers: Dictionary<String, String> = [:] )
  {
    self.method = method
    self.url    = url

    assert(url.path != nil, "HTTP request URL has no path?!")
    
    super.init(version: version, headers: headers)
  }
  public convenience init
    (method: HTTPMethod, url: String, version: ( Int, Int ) = HTTPv11,
     headers: Dictionary<String, String> = [:] )
  {
    self.init(method: method, url: URL(url), version: version, headers: headers)
  }
  
  override func descriptionAttributes() -> String {
    var s = " \(method) \(url)"
    s += super.descriptionAttributes()
    return s
  }
}
