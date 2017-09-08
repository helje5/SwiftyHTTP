//
//  FileDescriptor.swift
//  SwiftSockets
//
//  Created by Helge Hess on 13/07/15.
//  Copyright (c) 2014-2015 Always Right Institute. All rights reserved.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

extension POSIXErrorCode : Error {}

/// This essentially wraps the Integer representing a file descriptor in a
/// struct for the whole reason to attach methods to it.
public struct FileDescriptor: ExpressibleByIntegerLiteral, ExpressibleByNilLiteral {

  public static let stdin  = FileDescriptor(STDIN_FILENO)
  public static let stdout = FileDescriptor(STDOUT_FILENO)
  public static let stderr = FileDescriptor(STDERR_FILENO)
  
  public let fd : Int32
  
  public init(_ fd: Int32) {
    self.fd = fd
  }
  
  public init(integerLiteral value: Int) {
    self.init(Int32(value))
  }
  public init(nilLiteral: ()) {
    self.init(-1)
  }
  
  
  // MARK: - Operations
  
  public static func open(_ path: String, flags: CInt)
                     -> ( Error?, FileDescriptor? )
  {
    let fd = sysOpen(path, flags)
    guard fd >= 0 else {
      return ( POSIXErrorCode(rawValue: sysErrno)!, nil )
    }
    
    return ( nil, FileDescriptor(fd) )
  }
  
  public func close() {
    _ = sysClose(fd)
  }
  
  public func read(_ count: Int) -> ( Error?, [ UInt8 ]? ) {
    // TODO: inefficient init. Also: reuse buffers.
    var buf = [ UInt8 ](repeating: 0, count: count)
    
    // synchronous
    
    let readCount = sysRead(fd, &buf, count)
    guard readCount >= 0 else {
      return ( POSIXErrorCode(rawValue: sysErrno)!, nil )
    }
    
    if readCount == 0 { return ( nil, [] ) } // EOF
    
    // TODO: super inefficient. how to declare sth which works with either?
    buf = Array(buf[0..<readCount]) // TODO: slice to array, lame
    return ( nil, buf )
  }
  
  public func write<T>(_ buffer: [ T ], count: Int = -1)
                -> ( Error?, Int )
  {
    guard buffer.count > 0 else { return ( nil, 0 ) }
    
    let lCount = count < 0 ? buffer.count : count
    
    // TODO: This is funny. It accepts an array of any type?!
    //       Is it actually what we want?
    let writeCount = sysWrite(fd, buffer, lCount)
    
    guard writeCount >= 0 else {
      return ( POSIXErrorCode(rawValue: sysErrno)!, 0 )
    }
    
    return ( nil, writeCount )
  }
  
  
  // MARK: - File Descriptor
  
  public var isValid   : Bool { return fd >= 0 }
  
  public var isStdInOutErr : Bool {
    return fd == STDIN_FILENO || fd == STDOUT_FILENO || fd == STDERR_FILENO
  }
  
  
  // MARK: - Description
  
  // must live in the main-class as 'declarations in extensions cannot be
  // overridden yet' (Same in Swift 2.0)
  func descriptionAttributes() -> String {
    if fd == STDIN_FILENO  { return " stdin"  }
    if fd == STDOUT_FILENO { return " stdout" }
    if fd == STDERR_FILENO { return " stderr" }
    let s = fd >= 0 ? " fd=\(fd)" : " closed"
    return s
  }
}


// MARK: - File Descriptor Flags

extension FileDescriptor { // Socket Flags
  
  public var flags : Int32? {
    get {
      let rc = ari_fcntlVi(fd, F_GETFL, 0)
      return rc >= 0 ? rc : nil
    }
    set {
      let rc = ari_fcntlVi(fd, F_SETFL, Int32(newValue!))
      if rc == -1 {
        print("Could not set new socket flags \(rc)")
      }
    }
  }
  
  public var isNonBlocking : Bool {
    get {
      if let f = flags {
        return (f & O_NONBLOCK) != 0 ? true : false
      }
      else {
        print("ERROR: could not get non-blocking socket property! \(self)")
        return false
      }
    }
    set {
      if newValue {
        if let f = flags {
          flags = f | O_NONBLOCK
        }
        else {
          flags = O_NONBLOCK
        }
      }
      else {
        flags = flags! & ~O_NONBLOCK
      }
    }
  }
  
}


// MARK: - Polling

public extension FileDescriptor {
  
  public var isDataAvailable: Bool { return pollFlag(POLLRDNORM) }
  
  public func pollFlag(_ flag: Int32) -> Bool {
    let rc: Int32? = poll(flag, timeout: 0)
    if let flags = rc {
      if (flags & flag) != 0 {
        return true
      }
    }
    return false
  }
  
  // Swift doesn't allow let's in here?!
  var pollEverythingMask : Int32 { return (
    POLLIN | POLLPRI    | POLLOUT
           | POLLRDNORM | POLLWRNORM
           | POLLRDBAND | POLLWRBAND)
  }
  
  // Swift doesn't allow let's in here?!
  var debugPoll : Bool { return false }
  
  public func poll(_ events: Int32, timeout: UInt? = 0) -> Int32? {
    // This is declared as Int32 because the POLLRDNORM and such are
    guard isValid else { return nil }
    
    let ctimeout = timeout != nil ? Int32(timeout!) : -1 /* wait forever */
    
    var fds = pollfd(fd: self.fd, events: CShort(events), revents: 0)
    let rc  = sysPoll(&fds, 1, ctimeout)
    
    guard rc >= 0 else {
      print("poll() returned an error")
      return nil
    }
    
    if debugPoll {
      let s = pollMaskToString(fds.revents)
      print("Poll result \(rc) flags \(fds.revents)\(s)")
    }
    
    guard rc != 0 else { return nil }
    
    return Int32(fds.revents)
  }

  var numberOfBytesAvailableForReading : Int? {
    // Note: this doesn't seem to work with GCD, returns 0
    var count = Int32(0)
    let rc    = ari_ioctlVip(fd, sysFIONREAD, &count);
    print("rc \(rc)")
    return rc != -1 ? Int(count) : nil
  }
}

private func pollMaskToString(_ mask16: Int16) -> String {
  var s = ""
  let mask = Int32(mask16)
  if 0 != (mask & POLLIN)     { s += " IN"  }
  if 0 != (mask & POLLPRI)    { s += " PRI" }
  if 0 != (mask & POLLOUT)    { s += " OUT" }
  if 0 != (mask & POLLRDNORM) { s += " RDNORM" }
  if 0 != (mask & POLLWRNORM) { s += " WRNORM" }
  if 0 != (mask & POLLRDBAND) { s += " RDBAND" }
  if 0 != (mask & POLLWRBAND) { s += " WRBAND" }
  return s
}


// MARK: - Equatable, Hashable

extension FileDescriptor: Equatable, Hashable {

  public var hashValue: Int { return fd.hashValue }
  
}

public func ==(lhs: FileDescriptor, rhs: FileDescriptor) -> Bool {
  return lhs.fd == rhs.fd
}


// MARK: - Description

extension FileDescriptor: CustomStringConvertible {
  
  public var description : String {
    return "<FileDescriptor:" + descriptionAttributes() + ">"
  }
  
}


// MARK: - Boolean

extension FileDescriptor { // TBD: Swift doesn't want us to do this
  
  public var boolValue : Bool {
    return isValid
  }
  
}
