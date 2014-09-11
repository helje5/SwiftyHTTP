//
//  SwiftyHTTP.h
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/25/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

@import Foundation;

//! Project version number for SwiftyHTTP.
FOUNDATION_EXPORT double SwiftyHTTPVersionNumber;

//! Project version string for SwiftyHTTP.
FOUNDATION_EXPORT const unsigned char SwiftyHTTPVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SwiftyHTTP/PublicHeader.h>


// No more bridging header in v0.0.4, need to make all C stuff public
#import <SwiftyHTTP/http_parser.h>

// I think the originals are not mapped because they are using varargs
FOUNDATION_EXPORT int ari_fcntlVi (int fildes, int cmd, int val);
FOUNDATION_EXPORT int ari_ioctlVip(int fildes, unsigned long request, int *val);
