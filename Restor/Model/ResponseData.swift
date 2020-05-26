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
    var metrics: URLSessionTaskTransactionMetrics?
    var error: Error?
    var data: Data?
    var cookiesData: Data?
    var cookies: [HTTPCookie] = []
    var responseSize: Int = 0
    var isSecure = false
    private var responseHeaders: [String: String] = [:] {
        didSet { self.updateResponseHeaderKeys() }
    }
    private var responseHeaderKeys: [String] = []
    var connectionInfo: ConnectionInfo = ConnectionInfo()
    var created: Int64 = 0
    
    struct ConnectionInfo {
        var elapsed: Int64 = 0
        var dnsTime: Double = 0
        var connectionTime: Double = 0
        var secureConnectionTime: Double = 0
        var fetchStart: Int64 = 0  // Date ts
        var requestTime: Double = 0 // Request start, request end
        var responseTime: Double = 0
        var networkProtocolName: String = ""
        var isProxyConnection: Bool = false
        var isReusedConnection: Bool = false
        var requestHeaderBytesSent: Int64 = 0
        var requestBodyBytesSent: Int64 = 0
        var responseHeaderBytesReceived: Int64 = 0
        var responseBodyBytesReceived: Int64 = 0
        var localAddress: String = ""
        var remoteAddress: String = ""
        var isCellular: Bool = false
        var isMultipath: Bool = false
    }
    
    /// Indicates if the response object is created from a live response or from history.
    enum Mode {
        case memory
        case history
    }
    
    init(error: Error, elapsed: Int64, request: ERequest) {
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
        if let proj = request.project {
            self.method = self.localdb.getRequestMethodData(at: request.selectedMethodIndex.toInt(), projId: proj.getId())?.name ?? ""
        }
    }
    
    init(history: EHistory) {
        self.init(history: history, elapsed: 0)
    }
        
    init(history: EHistory, elapsed: Int64) {
        self.created = Date().currentTimeNanos()
        self.mode = .history
        self.history = history
        self.urlRequestString = history.request ?? ""
        self.method = history.method ?? ""
        self.url = history.url ?? ""
        self.isSecure = self.isHTTPS(url: self.url)
        self.requestId = history.requestId ?? ""
        self.wsId = history.wsId ?? ""
        self.responseData = history.responseData
        self.statusCode = history.statusCode.toInt()
        self.status = (200..<299) ~= self.statusCode
        self.responseSize = history.responseBodySize.toInt()
        self.connectionInfo.elapsed = elapsed
        self.updateResponseHeaders()
        self.updateCookies()
    }
    
    init(response: HTTPURLResponse, request: ERequest, urlRequest: URLRequest, responseData: Data?, metrics: URLSessionTaskTransactionMetrics? = nil) {
        self.init(response: response, request: request, urlRequest: urlRequest, responseData: responseData, elapsed: 0, responseSize: 0, metrics: metrics)
    }
    
    init(response: HTTPURLResponse, request: ERequest, urlRequest: URLRequest, responseData: Data?, elapsed: Int64, responseSize: Int64, metrics: URLSessionTaskTransactionMetrics? = nil) {
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
        self.responseData = data
        self.statusCode = response.statusCode
        self.responseSize = responseSize.toInt()
        self.status = (200..<299) ~= self.statusCode
        self.connectionInfo.elapsed = elapsed
        self.updateResponseHeaders()
        self.updateCookies()
    }
    
    func isHTTPS(url: String?) -> Bool {
        return url?.starts(with: "https") ?? false
    }
    
    mutating func updateMetrics() {
        var cInfo = self.connectionInfo
        switch self.mode {
        case .memory:
            guard let metrics = self.metrics else { return }
            if let d1 = metrics.connectStartDate, let d2 = metrics.connectEndDate {
                cInfo.connectionTime = Date.msDiff(start: d1, end: d2)
            }
            if let d1 = metrics.domainLookupStartDate, let d2 = metrics.domainLookupEndDate {
                cInfo.dnsTime = Date.msDiff(start: d1, end: d2)
            }
            if let x = metrics.fetchStartDate {
                cInfo.fetchStart = x.currentTimeNanos()
            }
            if let d1 = metrics.requestStartDate, let d2 = metrics.requestEndDate {
                cInfo.requestTime = Date.msDiff(start: d1, end: d2)
            }
            if let d1 = metrics.responseStartDate, let d2 = metrics.responseEndDate {
                cInfo.responseTime = Date.msDiff(start: d1, end: d2)
            }
            if let d1 = metrics.secureConnectionStartDate, let d2 = metrics.secureConnectionEndDate {
                cInfo.secureConnectionTime = Date.msDiff(start: d1, end: d2)
            }
        case .history:
            break
        }
        self.connectionInfo = cInfo
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
    }
    
    mutating func updateCookies() {
        if self.mode == .memory {
            if let url = self.urlRequest?.url {
                self.cookies = HTTPCookie.cookies(withResponseHeaderFields: self.responseHeaders, for: url)
                self.cookiesData = HTTPCookie.toData(self.cookies)
            }
        } else if self.mode == .history {
            self.cookiesData = self.history?.cookies
        }
        if let cookies = self.cookiesData {
            self.cookies = HTTPCookie.fromData(cookies)
        }
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
            error: \(String(describing: self.error))
            data: \(String(describing: self.data))
            elapsed: \(self.connectionInfo.elapsed)
            size: \(self.responseSize)
            """
    }
}
