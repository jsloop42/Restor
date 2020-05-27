//
//  ResponseData.swift
//  Restor
//
//  Created by jsloop on 24/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

struct ResponseData: CustomDebugStringConvertible {
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var utils = { EAUtils.shared }()
    var status: Bool = false
    var mode: Mode = .memory
    var statusCode: Int = 0
    var url: String = ""
    var method: String = ""
    var request: ERequest?
    var urlRequestString: String = ""
    var requestId: String = ""
    var wsId: String = ""
    var urlRequest: URLRequest?
    var history: EHistory?
    var response: HTTPURLResponse?
    var responseData: Data?
    var metrics: URLSessionTaskMetrics?
    var error: Error?
    var data: Data?
    var cookiesData: Data?
    var cookies: [EAHTTPCookie] = []
    var isSecure = false
    private var responseHeaders: [String: String] = [:] {
        didSet { self.updateResponseHeaderKeys() }
    }
    private var responseHeaderKeys: [String] = []
    var connectionInfo: ConnectionInfo = ConnectionInfo()
    var created: Int64 = 0
    private var metricsMap: [String: String] = [:]
    private var metricsKeys: [String] = []
    private var detailsMap: [String: String] = [:]
    private var detailsKeys: [String] = []
    var hasRequestBody = false
    
    struct ConnectionInfo {
        var elapsed: Int64 = 0  // Total response time
        var dnsTime: Double = 0  // DNS Resolution Time
        var connectionTime: Double = 0  // Connection Time
        var secureConnectionTime: Double = 0  // SSL Handshake Time
        var fetchStart: Int64 = 0  // Date ts
        var requestTime: Double = 0 // Request start, request end
        var responseTime: Double = 0
        var networkProtocolName: String = ""
        var isProxyConnection: Bool = false
        var isReusedConnection: Bool = false
        var requestHeaderBytesSent: Int64 = -1
        var requestBodyBytesSent: Int64 = -1
        var responseHeaderBytesReceived: Int64 = -1
        var responseBodyBytesReceived: Int64 = -1
        var localAddress: String = ""
        var localPort: Int64 = 0
        var remoteAddress: String = ""
        var remotePort: Int64 = 0
        var isCellular: Bool = false
        var isMultipath: Bool = false
        var negotiatedTLSCipherSuite: String = ""  // TLS Cipher Suite
        var negotiatedTLSProtocolVersion: String = ""  // TLS Protocol
        var connection: String = EAReachability.Connection.cellular.description
    }
    
    /// Indicates if the response object is created from a live response or from history.
    enum Mode {
        case memory
        case history
    }
    
    init(error: Error, elapsed: Int64, request: ERequest, metrics: URLSessionTaskMetrics?) {
        self.error = error
        self.mode = .memory
        self.status = false
        self.connectionInfo.elapsed = elapsed
        self.statusCode = -1
        self.request = request
        self.url = request.url ?? ""
        self.isSecure = self.isHTTPS(url: self.url)
        self.wsId = request.getWsId()
        self.requestId = request.getId()
        self.hasRequestBody = request.body != nil
        if let proj = request.project { self.method = self.localdb.getRequestMethodData(at: request.selectedMethodIndex.toInt(), projId: proj.getId())?.name ?? "" }
        if let x = metrics { self.updateFromMetrics(x) }
    }
        
    init(history: EHistory) {
        self.created = Date().currentTimeNanos()
        self.mode = .history
        self.history = history
        self.urlRequestString = history.request ?? ""
        self.method = history.method ?? ""
        self.url = history.url ?? ""
        self.isSecure = self.isHTTPS(url: self.url)
        self.requestId = history.requestId ?? ""
        self.wsId = history.wsId ?? ""
        self.hasRequestBody = history.hasRequestBody
        self.responseData = history.responseData
        self.statusCode = history.statusCode.toInt()
        self.status = (200..<299) ~= self.statusCode
        self.connectionInfo.elapsed = history.elapsed
        self.updateResponseHeaders()
        self.updateCookies()
        self.updateMetrics(history)
    }
    
    init(response: HTTPURLResponse, request: ERequest, urlRequest: URLRequest, responseData: Data?, metrics: URLSessionTaskMetrics? = nil) {
        self.init(response: response, request: request, urlRequest: urlRequest, responseData: responseData, elapsed: 0, metrics: metrics)
    }
    
    init(response: HTTPURLResponse, request: ERequest, urlRequest: URLRequest, responseData: Data?, elapsed: Int64, metrics: URLSessionTaskMetrics? = nil) {
        self.created = Date().currentTimeNanos()
        self.mode = .memory
        self.response = response
        self.request = request
        self.urlRequest = urlRequest
        self.urlRequestString = urlRequest.toString()
        self.method = urlRequest.httpMethod ?? ""
        self.url = urlRequest.url?.absoluteString ?? ""
        self.isSecure = self.isHTTPS(url: self.url)
        self.requestId = request.getId()
        self.wsId = request.getWsId()
        self.hasRequestBody = request.body != nil
        self.responseData = data
        self.statusCode = response.statusCode
        self.status = (200..<299) ~= self.statusCode
        self.connectionInfo.elapsed = elapsed
        self.updateResponseHeaders()
        self.updateCookies()
        if let x = metrics { self.updateFromMetrics(x) }
    }
    
    func isHTTPS(url: String?) -> Bool {
        return url?.starts(with: "https") ?? false
    }
    
    func updateMetrics(_ history: EHistory) {
        // TODO:
    }
    
    mutating func updateFromMetrics() {
        guard let metrics = self.metrics else { return }
        self.updateFromMetrics(metrics)
    }
    
    mutating func updateFromMetrics(_ metrics: URLSessionTaskMetrics) {
        var cInfo = self.connectionInfo
        Log.debug("elapsed: \(self.connectionInfo.elapsed) - duration: \(metrics.taskInterval.duration)")
        if metrics.transactionMetrics.isEmpty { return }
        let hasMany = metrics.transactionMetrics.count > 1
        switch self.mode {
        case .memory:
            if hasMany {
                
            } else {  // only one transaction metrics
                guard let tmetrics = metrics.transactionMetrics.first else { return }
                if let d1 = tmetrics.connectStartDate, let d2 = tmetrics.connectEndDate {
                    cInfo.connectionTime = Date.msDiff(start: d1, end: d2)
                }
                if let d1 = tmetrics.domainLookupStartDate, let d2 = tmetrics.domainLookupEndDate {
                    cInfo.dnsTime = Date.msDiff(start: d1, end: d2)
                }
                if let x = tmetrics.fetchStartDate {
                    cInfo.fetchStart = x.currentTimeNanos()
                }
                if let d1 = tmetrics.requestStartDate, let d2 = tmetrics.requestEndDate {
                    cInfo.requestTime = Date.msDiff(start: d1, end: d2)
                }
                if let d1 = tmetrics.responseStartDate, let d2 = tmetrics.responseEndDate {
                    cInfo.responseTime = Date.msDiff(start: d1, end: d2)
                }
                if let d1 = tmetrics.secureConnectionStartDate, let d2 = tmetrics.secureConnectionEndDate {
                    cInfo.secureConnectionTime = Date.msDiff(start: d1, end: d2)
                }
                cInfo.networkProtocolName = tmetrics.networkProtocolName ?? ""
                cInfo.isProxyConnection = tmetrics.isProxyConnection
                cInfo.isReusedConnection = tmetrics.isReusedConnection
                if #available(iOS 13.0, *) {
                    cInfo.requestHeaderBytesSent = tmetrics.countOfRequestHeaderBytesSent
                    cInfo.requestBodyBytesSent = tmetrics.countOfRequestBodyBytesSent
                    cInfo.responseHeaderBytesReceived = tmetrics.countOfResponseHeaderBytesReceived
                    cInfo.responseBodyBytesReceived = tmetrics.countOfResponseBodyBytesReceived
                    cInfo.localAddress = tmetrics.localAddress ?? ""
                    cInfo.remoteAddress = tmetrics.remoteAddress ?? ""
                    cInfo.localPort = (tmetrics.localPort ?? 0).toInt64()
                    cInfo.remotePort = (tmetrics.remotePort ?? 0).toInt64()
                    cInfo.isCellular = tmetrics.isCellular
                    cInfo.connection = (tmetrics.isCellular || tmetrics.isExpensive || tmetrics.isConstrained) ? EAReachability.Connection.cellular.description
                        : EAReachability.Connection.wifi.description
                    cInfo.isMultipath = tmetrics.isMultipath
                    if let x = tmetrics.negotiatedTLSCipherSuite?.rawValue {
                        cInfo.negotiatedTLSCipherSuite = EATLSCipherSuite(x)?.toString() ?? ""
                    }
                    if let x = tmetrics.negotiatedTLSProtocolVersion {
                        cInfo.negotiatedTLSProtocolVersion = EATLSProtocolVersion(x.rawValue)?.toString() ?? ""
                    }
                } else {
                    self.updateResponseBodySizeFromHeaders()
                }
            }
            break
        case .history:
            break
        }
        self.connectionInfo = cInfo
    }
    
    mutating func updateResponseBodySizeFromHeaders() {
        if !self.responseHeaders.isEmpty {
            if let sizeMap = self.responseHeaders.first(where: { (key: AnyHashable, value: Any) -> Bool in
                if let key = key as? String { return key.lowercased() == "content-length" }
                return false
            }) {
                self.connectionInfo.responseBodyBytesReceived = Int64(sizeMap.value) ?? 0
            }
        }
    }
    
    func getResponseHeaders() -> [String: String] {
        return self.responseHeaders
    }
    
    func getResponseHeaderKeys() -> [String] {
        return self.responseHeaderKeys
    }
    
    mutating func updateResponseHeaders() {
        if self.mode == .memory {
            self.responseHeaders = self.response?.allHeaderFields as? [String : String] ?? [:]
        } else if self.mode == .history {
            if let data = self.history?.responseHeaders, let hm = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] {
                self.responseHeaders = hm
            }
        }
        self.updateResponseHeaderKeys()
    }
    
    mutating func updateResponseHeaderKeys() {
        self.responseHeaderKeys = self.responseHeaders.allKeys()
        self.responseHeaderKeys.sort { (a, b) in a.lowercased() <= b.lowercased() }
    }
    
    mutating func updateCookies() {
        if self.mode == .memory {
            if let url = self.urlRequest?.url {
                self.cookies = EAHTTPCookie.from(headers: self.responseHeaders, for: url)
                self.cookiesData = try? JSONEncoder().encode(self.cookies)
            }
        } else if self.mode == .history {
            self.cookiesData = self.history?.cookies
            if let data = self.cookiesData, let xs = try? JSONDecoder().decode([EAHTTPCookie].self, from: data) {
                self.cookies = xs
            }
        }
        self.cookies.sort { (a, b) in a.name.lowercased() <= b.name.lowercased() }
    }
    
    mutating func updateMetricsMap() {
        let cinfo = self.connectionInfo
        if cinfo.elapsed > 0 {
            self.metricsMap["Elapsed"] = self.utils.formatElapsed(cinfo.elapsed)
        }
        self.metricsMap["Total Response Time"] = self.utils.formatElapsed(cinfo.responseTime.toInt64())
        self.metricsMap["DNS Resolution Time"] = self.utils.formatElapsed(cinfo.dnsTime.toInt64())
        self.metricsMap["Connection Time"] = self.utils.formatElapsed(cinfo.connectionTime.toInt64())
        self.metricsMap["Request Time"] = self.utils.formatElapsed(cinfo.requestTime.toInt64())
        self.metricsMap["Response Time"] = self.utils.formatElapsed(cinfo.responseTime.toInt64())
        if self.isSecure {
            self.metricsMap["SSL Handshake Time"] = self.utils.formatElapsed(cinfo.secureConnectionTime.toInt64())
        }
        if #available(iOS 13.0, *) {
            self.metricsMap["Request Header Size"] = self.utils.bytesToReadable(cinfo.requestHeaderBytesSent)
            if self.hasRequestBody {
                self.metricsMap["Request Body Size"] = self.utils.bytesToReadable(cinfo.requestBodyBytesSent)
            }
            self.metricsMap["Response Header Size"] = self.utils.bytesToReadable(cinfo.responseHeaderBytesReceived)
            self.metricsMap["Response Body Size"] = self.utils.bytesToReadable(cinfo.responseBodyBytesReceived)
        }
        self.metricsKeys = self.metricsMap.allKeys().sorted()
    }
    
    func getMetricsMap() -> [String: String] {
        return self.metricsMap
    }
    
    func getMetricsKeys() -> [String] {
        return self.metricsKeys
    }
    
    mutating func updateDetailsMap() {
        let cinfo = self.connectionInfo
        self.detailsMap["Date"] = Date(timeIntervalSince1970: TimeInterval(self.created)).fmt_YYYY_MM_dd_HH_mm_ss
        self.detailsMap["Local Address"] = cinfo.localAddress
        self.detailsMap["Local Port"] = "\(cinfo.localPort)"
        self.detailsMap["Remote Address"] = cinfo.remoteAddress
        self.detailsMap["Remote Port"] = "\(cinfo.remotePort)"
        if !cinfo.connection.isEmpty { self.detailsMap["Connection"] = "\(cinfo.connection)" }
        if cinfo.isMultipath { self.detailsMap["Routing"] = "Multipath" }
        if self.isSecure {
            self.detailsMap["SSL Cipher Suite"] = cinfo.negotiatedTLSCipherSuite
            self.detailsMap["TLS"] = cinfo.negotiatedTLSProtocolVersion
        }
        self.detailsKeys = self.detailsMap.allKeys().sorted()
    }
    
    func getDetailsMap() -> [String: String] {
        return self.detailsMap
    }
    
    func getDetailsKeys() -> [String] {
        return self.detailsKeys
    }
    
    var debugDescription: String {
        return
            """
            \(type(of: self)))
            status: \(self.status)
            statusCode: \(self.statusCode)
            request: \(String(describing: self.request))
            urlRequest: \(String(describing: self.urlRequest))
            response: \(String(describing: self.response))
            cookies: \(String(describing: self.cookies))
            error: \(String(describing: self.error))
            data: \(String(describing: self.data))
            elapsed: \(self.connectionInfo.elapsed)
            size: \(self.connectionInfo.responseBodyBytesReceived)
            mode: \(self.mode)
            """
    }
}
