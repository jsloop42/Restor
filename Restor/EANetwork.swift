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

public protocol EAHTTPClientDelegate: class {
    /// Returns the certificate data and the password associated with it
    func getClientCertificate() -> (Data, String)
}

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
    public weak var delegate: EAHTTPClientDelegate?
    
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
    
    public override init() {
        super.init()
        self.session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: self.queue)
        self.bootstrap()
    }
    
    public init(config: URLSessionConfiguration) {
        super.init()
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: self.queue)
        self.bootstrap()
    }
    
    public init(url: URL, method: Method) {
        super.init()
        self.session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: self.queue)
        self.url = url
        self.method = method
        self.bootstrap()
    }
    
    public func bootstrap() {
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
        self.process(request: req) { result in
            switch result {
            case .success(let (data, _)):
                completion(.success(data))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public func process(request: URLRequest, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        let task = self.session.dataTask(with: request) { data, resp, err in
            guard let data = data, let resp = resp as? HTTPURLResponse,
                (200..<300) ~= resp.statusCode, err == nil else {
                Log.error("http-client - response error: \(err!)")
                completion(.failure(err!))
                return
            }
            completion(.success((data, resp)))
        }
        task.resume()
    }
    
    /// Get uses query parameters. Specifying body data does not have any specific semantics associated with it.
    public func get(queryParams: [String: String], headers: [String: String], body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: body, method: .get, completion: completion)
    }
    
    /// Post uses body data for creation or modification. Query parameters can be used for response modification for example.
    public func post(queryParams: [String: String], headers: [String: String], body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: body, method: .post, completion: completion)
    }
    
    /// Put uses body data for creation or modification. Query parameters can be used for response modification for example.
    public func put(queryParams: [String: String], headers: [String: String], body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: body, method: .put, completion: completion)
    }
    
    /// Patch uses body data for modification. Query parameters can be used for response modification for example.
    public func patch(queryParams: [String: String], headers: [String: String], body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: body, method: .patch, completion: completion)
    }
    
    /// Delete can have query params (for eg: filter data criteria), but body does not have any semantics.
    public func delete(queryParams: [String: String], headers: [String: String], body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        self.process(url: self.url, queryParams: queryParams, headers: headers, body: body, method: .delete, completion: completion)
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
            if let (cert, pass) = self.delegate?.getClientCertificate() {
                let pkcs12 = PKCS12(data: cert, password: pass)
                if let cred = URLCredential(pkcs12: pkcs12) {
                    challenge.sender?.use(cred, for: challenge)
                    completionHandler(.useCredential, cred)
                    return
                }
            }
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension URLRequest {
    public func curl(pretty: Bool? = false) -> String {
        let pretty = pretty ?? false
        var data = ""
        let delim = pretty ? "\\\n" : ""
        let method = "-X \(self.httpMethod ?? "GET") \(delim)"
        let url = "\"\(self.url?.absoluteString ?? "")\""
        let header = self.allHTTPHeaderFields?.reduce("", { (acc, arg) -> String in
            let (key, value) = arg
            return acc + "-H \"\(key): \(value)\" \(delim)"
        }) ?? ""
        if let bodyData = self.httpBody, let bodyString = String(data:bodyData, encoding:.utf8) {
            data = "-d \"\(bodyString)\" \(delim)"
        }
        return "curl -i \(delim)\(method)\(header)\(data)\(url)"
    }
    
    func toString() -> String {
        let method = self.httpMethod ?? ""
        let url = self.url?.absoluteString ?? ""
        let delim = "\n"
        let headers = URLRequest.headersToString(self.allHTTPHeaderFields)
        if let data = self.httpBody, let body = String(data: data, encoding: .utf8) { return "\(method) \(url)\(delim)\(headers)\(delim)\(delim)\(body)" }
        return "\(method) \(url)\(delim)\(headers)"
    }
    
    static func headersToString(_ hm: [AnyHashable: Any]?) -> String {
        return hm?.reduce("", { (acc, arg) -> String in
            let (key, value) = arg
            return acc + "\(key): \(value)\" \n"
        }) ?? ""
    }
}
