//
//  HTTPRequest.swift
//  SwiftyHTTP
//
//  Created by Helge Heß on 6/25/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

let HTTPv11 = ( major: 1, minor: 1 )
let HTTPv10 = ( major: 1, minor: 0 )
let HTTPv09 = ( major: 0, minor: 9 )

class HTTPRequest : HTTPMessage {
  
  let method : HTTPMethod
  let url    : String
  
  init(method: HTTPMethod, url: String, version: ( Int, Int ) = HTTPv11,
       headers: Dictionary<String, String> = [:] )
  {
    self.method = method
    self.url    = url
    
    super.init(version: version, headers: headers)
  }
  
  override func descriptionAttributes() -> String {
    var s = " \(method) \(url)"
    s += super.descriptionAttributes()
    return s
  }
}
