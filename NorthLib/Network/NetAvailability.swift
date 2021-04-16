//
//  NetAvailability.swift
//
//  Created by Norbert Thies on 23.05.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import SystemConfiguration
import Network

/**
 The class NetAvailability enables the tracking of the connection status to the 
 internet. 
 
 All connection status checking is based on an instance of this class. E.g.
 ````
 let net = NetAvailability()
 if net.isAvailable { print("network available") }
 ````
 allows for checking whether internet is available at all. The expression 
 ````
 net.isMobile
 ```` 
 queries whether the connection to the internet is via a cellular or mobile network.
 If you are interested whether a certain host is reachable you may use:
 ````
 let net = NetAvailability("www.apple.com")
 if net.isAvailable { print("can reach apple.com") }
 ````
 If you are interested in network availability changes you may use `onChange` to 
 define a closure that is called upon changes:
 ````
 net.onChange { (flags: SCNetworkReachabilityFlags) in
   print("network availability has changed, flags=\(flags\)")
 }
 ````
 If you are only interested in events that call a closure when internet availability 
 goes up or down, you may use:
 ````
 let net = NetAvailability()
 
 net.whenUp {
   print("network available")
 }
 
 net.whenDown {
   print("network no longer available")
 }
 ````
 
 
 may we should migrate to use NSURLSession config waitForConnectivity
 https://developer.apple.com/forums/thread/99142
 ...needs a different concept
 */


open class NWPathNetAvailability {
  
  let monitor:NWPathMonitor
  
  /// Is network connectivity available?
  public var isAvailable: Bool {
    return monitor.currentPath.status == .satisfied
  }

  /// Is network connection via mobile networks?
  public var isMobile: Bool {
    return monitor.currentPath.usesInterfaceType(.cellular)
  }
  
  /// Defines the closure to call when a network change has happened
  public func onChange(_ closure: ((SCNetworkReachabilityFlags)->())?) {
    _onChangeClosure = closure
  }
  
  var _onChangeClosure: ((SCNetworkReachabilityFlags)->())? = nil
  
//  public private(set) var online:Bool
  
  /// Check for reachability of the given host
  public init() {
    monitor = NWPathMonitor()
    let queue = DispatchQueue.global(qos: .background)
    monitor.start(queue: queue)
    
    monitor.pathUpdateHandler = {   [weak self] path in
//      self?.online = path.status == .satisfied
      var stat = ""
      switch path.status {
        case .requiresConnection:
          stat = "requiresConnection"
        case .satisfied:
          stat = "satisfied"
        case .unsatisfied:
          stat = "unsatisfied"
        default:
          stat = "<unknown with raw: \(path.status.hashValue)>"
      }
      
      print("NWPathNetAvailability ....update status: \(stat)")
      guard let closure = self?._onChangeClosure else { return }
      closure(SCNetworkReachabilityFlags.init(rawValue: 0))
    }
  }
}

/*
open class NetAvailability {
  
  // destination to test for reachability
  private var destination: SCNetworkReachability
  
  private var lastFlags: SCNetworkReachabilityFlags
  
  private var reachabilityFlags: SCNetworkReachabilityFlags {
    var flags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(self.destination, &flags)
    return flags
  }
  
  /// Is network connectivity available?
  public func isAvailable(flags: SCNetworkReachabilityFlags? = nil) -> Bool {
    var fl = flags
    if fl == nil { fl = reachabilityFlags }
    return isReachable(flags: fl!)
  }
  
  /// Is network connectivity available?
  public var isAvailable: Bool { return isAvailable() }

  /// Is network connection via mobile networks?
  public func isMobile(flags: SCNetworkReachabilityFlags? = nil) -> Bool {
    var fl = flags
    if fl == nil { fl = reachabilityFlags }
    return isReachable(flags: fl!) && fl!.contains(.isWWAN)
  }
  
  /// Is network connection via mobile networks?
  public var isMobile: Bool { return isMobile() }
  
  private func isReachable(flags: SCNetworkReachabilityFlags) -> Bool {
    if let _host = self.host, flags.rawValue == 0 {
      return self.isReachableNewInstance(host: _host)
    }
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    let autoConnect = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
    let withoutUser = autoConnect && !flags.contains(.interventionRequired)
    return isReachable && (!needsConnection || withoutUser)
  }
  
  private var host: String?
  private func isReachableNewInstance(host:String) -> Bool {
    guard let hdest = SCNetworkReachabilityCreateWithName(nil, "https://dl.taz.de") else {
      return false
    }
    var newFlags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(hdest, &newFlags)
    
    let isReachable = newFlags.contains(.reachable)
    let needsConnection = newFlags.contains(.connectionRequired)
    let autoConnect = newFlags.contains(.connectionOnDemand) || newFlags.contains(.connectionOnTraffic)
    let withoutUser = autoConnect && !newFlags.contains(.interventionRequired)
    print("newFeeder Status... \(isReachable && (!needsConnection || withoutUser))")
    return isReachable && (!needsConnection || withoutUser)
  }
  
  /// Check for general network availability
  required public init(_ destination: SCNetworkReachability? = nil) {
    if let destination = destination { self.destination = destination }
    else {
      var addr = sockaddr()
      addr.sa_len = UInt8(MemoryLayout<sockaddr>.size)
      addr.sa_family = sa_family_t(AF_INET)
      self.destination = SCNetworkReachabilityCreateWithAddress(nil, &addr)!
    }
    var fl = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(self.destination, &fl)
    self.lastFlags = fl
    let callback: SCNetworkReachabilityCallBack = { (reachability,flags,info) in
      guard let info = info else { return }
      print("Reachabillity info:\(info), flags:\(flags), reachability:\(reachability)")
      let net = Unmanaged<NetAvailability>.fromOpaque(info).takeUnretainedValue()
      net.changeCallback(flags: flags)
      net.lastFlags = flags
    }
    var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, 
                    copyDescription: nil)
    context.info = UnsafeMutableRawPointer(Unmanaged<NetAvailability>.passUnretained(self).toOpaque())
    SCNetworkReachabilitySetCallback(self.destination, callback, &context)
    let current = OperationQueue.current?.underlyingQueue
    SCNetworkReachabilitySetDispatchQueue(self.destination, current!)
  }
  
  // deinit removes the callback
  deinit {
    SCNetworkReachabilitySetDispatchQueue(self.destination, nil)
    SCNetworkReachabilitySetCallback(self.destination, nil, nil)
  }
  
  /// Check for reachability of the given host
  convenience public init(host: String) {
    let hdest = SCNetworkReachabilityCreateWithName(nil, host)
    self.init(hdest)
    self.host = host
  }
  
  // changeCallback is called upon network reachability changes
  private func changeCallback(flags: SCNetworkReachabilityFlags) {
    /* all show 0 but safari works*/
    var newFlags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(self.destination, &newFlags)
    print("Compare Reachabillity Flags: \n  last: \(self.lastFlags)\n  flags: \(flags)\n  newFlags: \(newFlags)")
    
    
    if let closure = self._onChangeClosure {
      closure(flags)
    }
    if let closure = self._whenUpClosure {
      if isAvailable(flags: flags) && !isAvailable(flags: lastFlags) { closure() }
    }
    if let closure = self._whenDownClosure {
      if !isAvailable(flags: flags) && isAvailable(flags: lastFlags) { closure() }
    }
  }
  
  var _onChangeClosure: ((SCNetworkReachabilityFlags)->())? = nil
  var _whenUpClosure: (()->())? = nil
  var _whenDownClosure: (()->())? = nil
  
  /// Defines the closure to call when a network change has happened
  public func onChange(_ closure: ((SCNetworkReachabilityFlags)->())?) {
    _onChangeClosure = closure
  }
  
  /// Defines the closure to call when the network goes up
  public func whenUp(_ closure: (()->())?) {
    _whenUpClosure = closure
  }
  
  /// Defines the closure to call when the network goes down
  public func whenDown(_ closure: (()->())?) {
    _whenDownClosure = closure
  }  
  
} // NetAvailability
*/
