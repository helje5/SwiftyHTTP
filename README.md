SwiftyHTTP
==========

A simple GCD based HTTP library for Swift. This project is 'pure' Swift/C,
it does not use any bridged Objective-C classes.

SwiftyHTTP is a demo on how to integrate Swift with raw C APIs. More
for stealing Swift coding ideas than for actually using the code in a real
project. In most real world Swift apps you have access to Cocoa, use it.

**Note**: This is just my second [Swift](https://developer.apple.com/swift/)
project. Any suggestions on how to improve the code are welcome. I expect
lots and lots :-)

###First things first: Samples

Server:
```Swift
let httpd = HTTPServer()
  .onRequest {
    rq, res, con in
    res.bodyAsString = "<h2>Always Right, Never Wrong!</h2>"
    con.sendResponse(res)
  }
  .listen(1337)
```

Server using the Node.JS like Connect bonus class:
```Swift
let httpd = Connect()
  .use { rq, res, _, next in
    println("\(rq.method) \(rq.url) \(res.status)")
    next()
  }
  .use("/hello") { rq, res, con, next in
    res.bodyAsString = "Hello!"
    con.sendResponse(res)
  }
  .use("/") { rq, res, con, next in
    res.bodyAsString = "Always, almost sometimes."
    con.sendResponse(res)
  }
  .listen(1337)
```

Client (do not use this, use NSURLSession!):
```Swift
GET("http://www.apple.com/")
  .done {
    println()
    println("request  \($0)")
    println("response \($1)")
    println("body:\n\($1.bodyAsString)")
  }
  .fail {
    println("failed \($0): \($1)")
  }
  .always { println("---") }
```


###Targets

The project includes three targets:
- SwiftyHTTP
- SwiftyServer
- SwiftyClient

I suggest you start out looking at the SwiftyServer.

####SwiftyHTTP

A framework containing the HTTP classes and relevant extensions. It has a few
'subprojects':
- Foundation
- Sockets
- Parser
- HTTP

#####Foundation

This has just the 'RawByteBuffer' class. Which is kinda like a RawByte array.
I bet there are better ways to implement this! Please suggest some! :-)

Also a few - highly inefficient - extensions to convert between String's and
CString's. I would love some suggestions on those as well.

But remember: NSxyz is forbidden for this venture! :-)

#####Sockets

Just a local copy of the SwiftSockets project - I wish GIT had proper externals
;-) (https://github.com/AlwaysRightInstitute/SwiftSockets)

#####Parser

This uses the C HTTP parser which is also used in Node.JS. I couldn't
directly use it being C callback driven - a feature (currently?)
unsupported by Swift.
The fix was to rewrite the parser to use C blocks instead of function pointers.
Along that way I also removed some great features of the parser, like no
malloc() at all :->

It also contains the main request/response classes: HTTPRequest and
HTTPResponse, both subclasses of HTTPMessage.
And enums for HTTP status values (like `💰Required`) and request methods (GET
etc).

#####HTTP

HTTPConnectionPool is an abstract base class and manages open connections,
either incoming or outgoing. The HTTPConnection sits on top of the SwiftSockets
and manages one HTTP connection (it connects the socket to the parser).

HTTPServer is the server class. Uses SwiftSockets to listen for incoming
connections. See above for a sample.

As a bonus - this also has a tiny Connect class - which is modelled after the
Node.JS Connect thingy (which in turn is apparently modelled after RoR Rack).
It allows you to hook up a set of blocks for request processing, instead of
having just a single entry point.
Not sure I like that stuff, but it seems to fit into Swift quite well.
Find a sample above.

Finally there is a simple HTTP client. Doesn't do anything fancy. Do not - ever
- use this. Use NSURLSession and companions.

####SwiftyServer

Great httpd server - great in counting the requests it got sent. This is not
actually serving any files ;-) Comes along as a Cocoa app. Compile it, run it,
then connect to it in the browser via http://127.0.0.1:1337/Awesome-O!

![](http://i.imgur.com/4ShGZXS.png)

####SwiftyClient

Just a demo on how to do HTTP requests via SwiftyHTTP. No, it doesn't do JSON
decoding and such.

Again: You do NOT want to use it in a real iOS/OSX app! Use NSURLSession and
companions - it gives you plenty of extra features you want to have for realz.

![](http://i.imgur.com/ny0PSKH.png)

###Goals

- [x] Max line length: 80 characters
- [ ] Great error handling
  - [x] PS style great error handling
  - [x] println() error handling
  - [ ] Real error handling
- [x] Twisted (no blocking reads or writes)
  - [x] Async reads and writes
    - [x] Never block on reads
    - [x] Never block on listen
  - [ ] Async connect()
- [x] No NS'ism
- [ ] Use as many language features Swift provides
  - [x] Generics
    - [x] Generic function
    - [x] typealias
  - [x] Closures
    - [x] weak self
    - [x] trailing closures
    - [x] implicit parameters
  - [x] Unowned
  - [x] Extensions on structs
  - [x] Extensions to organize classes
  - [x] Protocols on structs
  - [x] Tuples
  - [x] Trailing closures
  - [ ] @Lazy
  - [x] Pure Swift weak delegates via @class
  - [x] Optionals
    - [x] Implicitly unwrapped optionals
  - [x] Convenience initializers
  - [x] Class variables on structs
  - [x] CConstPointer, CConstVoidPointer
    - [x] withCString {}
  - [x] UnsafePointer
  - [x] sizeof()
  - [x] Standard Protocols
    - [x] Printable
    - [x] LogicValue
    - [x] OutputStream
    - [x] Equatable
    - [x] Hashable
    - [x] Sequence (GeneratorOf<T>)
  - [x] Left shift AND right shift
  - [x] Enums on steroids
  - [ ] Dynamic type system, reflection
  - [x] Operator overloading
  - [x] UCS-4 identifiers (🐔🐔🐔)
  - [ ] ~~RTF source code with images and code sections in different fonts~~
  - [x] Nested classes/types
  - [ ] Patterns
    - [x] Use wildcard pattern to ignore value
  - [ ] @auto-closure
  - [ ] reinterpretCast()

###Why?!

This is an experiment to get acquainted with Swift. To check whether something
real can be implemented in 'pure' Swift. Meaning, without using any Objective-C
Cocoa classes (no NS'ism).
Or in other words: Can you use Swift without writing all the 'real' code in
wrapped Objective-C? :-)

###Contact

[@helje5](http://twitter.com/helje5) | helge@alwaysrightinstitute.com

![](http://www.alwaysrightinstitute.com/ARI.png)

