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
    var sessionName = "Default"
    
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
        self.updateDetailsMap()
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
        self.sessionName = history.sessionName ?? "Default"
        self.updateResponseHeadersMap()
        self.updateCookies()
        self.updateMetricsDetails(history)
        self.updateDetailsMap()
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
        self.responseData = responseData
        self.statusCode = response.statusCode
        self.status = (200..<299) ~= self.statusCode
        self.connectionInfo.elapsed = elapsed
        self.updateResponseHeadersMap()
        self.updateCookies()
        if let x = metrics { self.updateFromMetrics(x) }
        self.updateDetailsMap()
    }
    
    func isHTTPS(url: String?) -> Bool {
        return url?.starts(with: "https") ?? false
    }
    
    /// Updates metrics, details from the given history object.
    mutating func updateMetricsDetails(_ history: EHistory) {
        var cinfo = self.connectionInfo
        cinfo.connectionTime = history.connectionTime
        cinfo.dnsTime = history.dnsResolutionTime
        cinfo.elapsed = history.elapsed
        cinfo.fetchStart = history.fetchStartTime
        cinfo.requestTime = history.requestTime
        cinfo.responseTime = history.responseTime
        cinfo.secureConnectionTime = history.secureConnectionTime
        cinfo.networkProtocolName = history.networkProtocolName ?? ""
        cinfo.isProxyConnection = history.isProxyConnection
        cinfo.isReusedConnection = history.isReusedConnection
        cinfo.requestHeaderBytesSent = history.requestHeaderBytes
        cinfo.requestBodyBytesSent = history.requestBodyBytes
        cinfo.responseHeaderBytesReceived = history.responseHeaderBytes
        cinfo.responseBodyBytesReceived = history.responseBodyBytes
        cinfo.localAddress = history.localAddress ?? ""
        cinfo.localPort = history.localPort
        cinfo.remoteAddress = history.remoteAddress ?? ""
        cinfo.remotePort = history.remotePort
        cinfo.isCellular = history.isCellular
        cinfo.connection = history.connection ?? ""
        cinfo.isMultipath = history.isMultipath
        cinfo.negotiatedTLSCipherSuite = history.tlsCipherSuite ?? ""
        cinfo.negotiatedTLSProtocolVersion = history.tlsProtocolVersion ?? ""
        self.connectionInfo = cinfo
        self.updateMetricsMap()
    }
    
    mutating func updateFromMetrics() {
        guard let metrics = self.metrics else { return }
        self.updateFromMetrics(metrics)
    }
    
    mutating func updateFromMetrics(_ metrics: URLSessionTaskMetrics) {
        var cInfo = self.connectionInfo
        Log.debug("elapsed: \(self.connectionInfo.elapsed) - duration: \(metrics.taskInterval.duration)")
        let elapsed = self.connectionInfo.elapsed
        if metrics.transactionMetrics.isEmpty { return }
        let hasMany = metrics.transactionMetrics.count > 1
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
            if let d1 = tmetrics.fetchStartDate, let d2 = tmetrics.responseEndDate {
                cInfo.elapsed = Date.msDiff(start: d1, end: d2).toInt64()
            }
            if cInfo.elapsed == 0 && elapsed > 0 { cInfo.elapsed = elapsed }
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
                cInfo.isCellular = (tmetrics.isCellular || tmetrics.isExpensive || tmetrics.isConstrained)
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
    
    mutating func updateResponseHeadersMap() {
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
            self.metricsMap["Elapsed"] = self.utils.millisToReadable(cinfo.elapsed.toDouble())
        }
        self.metricsMap["DNS Resolution Time"] = self.utils.millisToReadable(cinfo.dnsTime)
        self.metricsMap["Connection Time"] = self.utils.millisToReadable(cinfo.connectionTime)
        self.metricsMap["Request Time"] = self.utils.millisToReadable(cinfo.requestTime)
        self.metricsMap["Response Time"] = self.utils.millisToReadable(cinfo.responseTime)
        if self.isSecure {
            self.metricsMap["SSL Handshake Time"] = self.utils.millisToReadable(cinfo.secureConnectionTime)
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
        self.detailsMap["Date"] = Date(timeIntervalSince1970: TimeInterval(self.created / 1000_000)).fmt_YYYY_MM_dd_HH_mm_ss
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
            elapsed: \(self.connectionInfo.elapsed)
            size: \(self.connectionInfo.responseBodyBytesReceived)
            mode: \(self.mode)
            sessionName: \(self.sessionName)
            connectionInfo: \(self.connectionInfo)
            """
    }
}
