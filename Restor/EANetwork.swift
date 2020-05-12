//
//  EANetwork.swift
//  Restor
//
//  Created by jsloop on 17/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import SystemConfiguration

// MARK: - Reachability

public enum EAReachabilityError: Error {
    case failedToCreateWithAddress(sockaddr, Int32)
    case failedToCreateWithHostname(String, Int32)
    case unableToSetCallback(Int32)
    case unableToSetDispatchQueue(Int32)
    case unableToGetFlags(Int32)
}

/// A class used to check if internet connectivity is present.
public class EAReachability {
    static let shared = EAReachability()
    
    static func isConnectedToNetwork() -> Bool {
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(self.getReachabilityForZeroAddress()!, &flags) == false { return false }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
    
    private static func getReachabilityForZeroAddress() -> SCNetworkReachability? {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        return defaultRouteReachability
    }
    
    deinit {
        self.stopNotifier()
    }
    
    public enum Connection: CustomStringConvertible {
        case unavailable
        case wifi
        case cellular
        public var description: String {
            switch self {
            case .unavailable:
                return "No connection"
            case .wifi:
                return "Wi-Fi"
            case .cellular:
                return "Cellular"
            }
        }
    }
    public var allowCellularConnection = true
    public var nc = NotificationCenter.default
    private (set) var flags: SCNetworkReachabilityFlags? {
        didSet {
            guard flags != oldValue else { return }
            self.notifyReachabilityChanged()
        }
    }
    fileprivate let reachabilityRef: SCNetworkReachability
    fileprivate let serialQueue: DispatchQueue
    fileprivate (set) var isNotifierRunning = false
    fileprivate var isRunningOnDevice: Bool = {
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }()
    
    public var whenReachable: ((EAReachability) -> Void)?
    public var whenUnreachable: ((EAReachability) -> Void)?
    
    public var connection: Connection {
        if flags == nil { try? self.setReachabilityFlags() }
        switch flags?.connection {
        case .unavailable?, nil:
            return .unavailable
        case .cellular?:
            return self.allowCellularConnection ? .cellular : .unavailable
        case .wifi?:
            return .wifi
        }
    }
    
    var description: String {
        return self.flags?.description ?? "unavailable flags"
    }
    
    required public init(reachabilityRef: SCNetworkReachability) {
        self.reachabilityRef = reachabilityRef
        self.serialQueue = EACommon.defaultQueue
    }
    
    public convenience init(hostname: String) throws {
        guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else { throw EAReachabilityError.failedToCreateWithHostname(hostname, SCError()) }
        self.init(reachabilityRef: ref)
    }
    
    public convenience init() {
        self.init(reachabilityRef: EAReachability.getReachabilityForZeroAddress()!)
    }
    
    func notifyReachabilityChanged() {
        let notify = { [weak self] in
            guard let self = self else { return }
            self.connection != .unavailable ? self.whenReachable?(self) : self.whenUnreachable?(self)
            self.nc.post(name: .reachabilityDidChange, object: self)
        }
        notify()
    }
    
    func setReachabilityFlags() throws {
        try self.serialQueue.sync { [unowned self] in
            var flags = SCNetworkReachabilityFlags()
            if !SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags) {
                self.stopNotifier()
                throw EAReachabilityError.unableToGetFlags(SCError())
            }
            self.flags = flags
        }
    }
    
    func startNotifier() throws {
        guard !self.isNotifierRunning else { return }
        let callback: SCNetworkReachabilityCallBack = { reachability, flags, info in
            guard let info = info else { return }
            // This variable will be retained because of the callbacks we give to `SCNetworkReachablityContext`
            let weakReachability = Unmanaged<EAReachabilityBridge>.fromOpaque(info).takeUnretainedValue()
            // The weak object may not exist if it's been deallocated and the callback was already in flight.
            weakReachability.reachability?.flags = flags
        }
        let weakReachability = EAReachabilityBridge(reachability: self)
        let opaqueWeakReachability = Unmanaged<EAReachabilityBridge>.passUnretained(weakReachability).toOpaque()
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutableRawPointer(opaqueWeakReachability),
            retain: { (info: UnsafeRawPointer) -> UnsafeRawPointer in
                let unmanagedWeakReachability = Unmanaged<EAReachabilityBridge>.fromOpaque(info)
                _ = unmanagedWeakReachability.retain()
                return UnsafeRawPointer(unmanagedWeakReachability.toOpaque())
            }, release: { (info: UnsafeRawPointer) in
                let unmanagedWeakReachability = Unmanaged<EAReachabilityBridge>.fromOpaque(info)
                unmanagedWeakReachability.release()
            }, copyDescription: { (info: UnsafeRawPointer) -> Unmanaged<CFString> in
                let unmanagedWeakReachability = Unmanaged<EAReachabilityBridge>.fromOpaque(info)
                let weakReachability = unmanagedWeakReachability.takeUnretainedValue()
                let desc = weakReachability.reachability?.description ?? "nil"
                return Unmanaged.passRetained(desc as CFString)
            })
        if !SCNetworkReachabilitySetCallback(self.reachabilityRef, callback, &context) {
            self.stopNotifier()
            throw EAReachabilityError.unableToSetCallback(SCError())
        }
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, self.serialQueue) {
            self.stopNotifier()
            throw EAReachabilityError.unableToSetDispatchQueue(SCError())
        }
        try self.setReachabilityFlags()
        self.isNotifierRunning = true
    }
    
    func stopNotifier() {
        defer { self.isNotifierRunning = false }
        SCNetworkReachabilitySetCallback(self.reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, nil)
    }
}

public extension Notification.Name {
    static let reachabilityDidChange = Notification.Name("reachability-did-change")
    static let offline = Notification.Name("offline")
    static let online = Notification.Name("online")
}

extension SCNetworkReachabilityFlags {
    typealias Connection = EAReachability.Connection
    
    var isReachableFlagSet: Bool { contains(.reachable) }
    var isConnectionRequiredFlagSet: Bool { contains(.connectionRequired) }
    var isInterventionRequiredFlagSet: Bool { contains(.interventionRequired) }
    var isConnectionOnTrafficFlagSet: Bool { contains(.connectionOnTraffic) }
    var isConnectionOnDemandFlagSet: Bool { contains(.connectionOnDemand) }
    var isConnectionOnTrafficOrDemandFlagSet: Bool { !intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty }
    var isTransientConnectionFlagSet: Bool { contains(.transientConnection) }
    var isLocalAddressFlagSet: Bool { contains(.isLocalAddress) }
    var isDirectFlagSet: Bool { contains(.isDirect) }
    var isConnectionRequiredAndTransientFlagSet: Bool { intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection] }
    
    var isOnWWANFlagSet: Bool {
        #if os(iOS)
        return contains(.isWWAN)
        #else
        return false
        #endif
    }
    
    var description: String {
        let W = self.isOnWWANFlagSet ? "W" : "-"
        let R = self.isReachableFlagSet ? "R" : "-"
        let c = self.isConnectionRequiredFlagSet ? "c" : "-"
        let t = self.isTransientConnectionFlagSet ? "t" : "-"
        let i = self.isInterventionRequiredFlagSet ? "i" : "-"
        let C = self.isConnectionOnTrafficFlagSet ? "C" : "-"
        let D = self.isConnectionOnDemandFlagSet ? "D" : "-"
        let l = self.isLocalAddressFlagSet ? "l" : "-"
        let d = self.isDirectFlagSet ? "d" : "-"
        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
    }
    
    var connection: Connection {
        guard self.isReachableFlagSet else { return .unavailable }
        #if targetEnvironment(simulator)
        return .wifi
        #else
        var conn = Connection.unavailable
        if !self.isConnectionRequiredFlagSet { conn = .wifi }
        if self.isConnectionOnTrafficOrDemandFlagSet { if !self.isInterventionRequiredFlagSet { conn = .wifi } }
        if self.isOnWWANFlagSet { conn = .cellular }
        return conn
        #endif
    }
}

/**
 `EAReachabilityBridge` can be used to interact with CoreFoundation with no retain cycles. CoreFoundation callbacks expect retain/release pairs whenever an opaque
 `info` parameter is given. The callbacks checks for memory race conditions when invoking the callbacks.
 
 ### Race Condition
 
 If we pass `SCNetworkReachabilitySetCallback` a direct reference to our `EAReachability` class without providing the retain/release callbacks, then a race
 condition could lead to a crash when:
 - `Reachability` is deallocated on thread X
 - A `SCNetworkReachability` callback(s) are already in flight on thread Y
 
 ### Retain Cycle
 
 If we pass `EAReachability` to CoreFoundation and also provide the retain/release callback functions, this would create a retain cycle once CoreFoundation retains
 the class. This fixes the crash as this is an expected way from CoreFoundation perspective, but not much with Swift/ARC. This reference will be release only
 by manually calling the `stopNotifier()` method. The `deinit` does not gets called.
 
 ### ReachablityBridge
 By wrapping the Reachablity in a weak wrapper and providing both the callbacks, we can interact with CoreFoundation without any crash, and automatic stopping
 of the notifier on `deinit`.
 */

private class EAReachabilityBridge {
    weak var reachability: EAReachability?
    init(reachability: EAReachability) {
        self.reachability = reachability
    }
}

// MARK: - HTTP Client

public class EAHTTPClient: NSObject {
    private lazy var queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.estoapps.ios.network-queue"
        q.qualityOfService = .utility
        return q
    }()
    private var session: URLSession!
    private let nc = NotificationCenter.default
    private var isOffline = false
    private var url: URL?
    private var method: Method = .get
    
    public enum Method {
        case get
        case post
        case put
        case patch
        case delete
        case custom(String)
        
        var rawValue: String {
            switch self {
            case .get:
                return "GET"
            case .post:
                return "POST"
            case .put:
                return "PUT"
            case .patch:
                return "PATCH"
            case .delete:
                return "DELETE"
            case .custom(let x):
                return x
            }
        }
    }
    
    override init() {
        super.init()
        self.session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: self.queue)
        self.bootstrap()
    }
    
    init(config: URLSessionConfiguration) {
        super.init()
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: self.queue)
        self.bootstrap()
    }
    
    init(url: URL, method: Method) {
        super.init()
        self.session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: self.queue)
        self.url = url
        self.method = method
        self.bootstrap()
    }
    
    func bootstrap() {
        self.initEvents()
    }
    
    private func initEvents() {
        if isRunningTests { return }
        self.nc.addObserver(self, selector: #selector(self.networkDidBecomeAvailable(_:)), name: .online, object: nil)
        self.nc.addObserver(self, selector: #selector(self.networkDidBecomeUnavailable(_:)), name: .offline, object: nil)
    }
    
    @objc private func networkDidBecomeAvailable(_ notif: Notification) {
        Log.debug("nw: online")
        self.isOffline = false
    }
    
    @objc private func networkDidBecomeUnavailable(_ notif: Notification) {
        Log.debug("nw: offline")
        self.isOffline = true
    }
    
    public func process(url: URL?, queryParams: [String: String], headers: [String: String], body: Data?, method: Method, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = url else { return }
        guard var urlComp = URLComponents(string: url.absoluteString) else { return }
        if !queryParams.isEmpty {
            urlComp.queryItems = queryParams.map({ (key, value) -> URLQueryItem in URLQueryItem(name: key, value: value) })
        }
        if (!queryParams.isEmpty && !headers.isEmpty && headers.contains(where: { (key, value) -> Bool in
            key.lowercased() == "content-type" && value.lowercased() == "application/x-www-form-urlencoded"
        })) {
            urlComp.percentEncodedQuery = urlComp.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let aUrl = urlComp.url else { return }
        var req = URLRequest(url: aUrl)
        req.httpMethod = method.rawValue
        let task = self.session.dataTask(with: req) { data, resp, err in
            guard let data = data, let resp = resp as? HTTPURLResponse,
                (200..<300) ~= resp.statusCode, err == nil else {
                Log.error("http-client - response error: \(err!)")
                completion(.failure(err!))
                return
            }
            completion(.success(data))
        }
        task.resume()
    }
    
    public func get(queryParams: [String: String], headers: [String: String], completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: nil, method: .get, completion: completion)
    }
    
    public func post() {
        
    }
    
    public func put() {
        
    }
    
    public func patch() {
        
    }
    
    public func delete() {
        
    }
}

extension EAHTTPClient: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = protectionSpace.serverTrust {
                let cred = URLCredential(trust: trust)
                completionHandler(.useCredential, cred)
            } else {
                // SSL certificate validation failure
                completionHandler(.performDefaultHandling, nil)
            }
        } else if protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            // TODO
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
