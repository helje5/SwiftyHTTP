//
//  SwiftyHTTP.h
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/25/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for SwiftyHTTP.
FOUNDATION_EXPORT double SwiftyHTTPVersionNumber;

//! Project version string for SwiftyHTTP.
FOUNDATION_EXPORT const unsigned char SwiftyHTTPVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SwiftyHTTP/PublicHeader.h>


// No more bridging header in v0.0.4, need to make all C stuff public
#import <SwiftyHTTP/Parser/http_parser.h>
