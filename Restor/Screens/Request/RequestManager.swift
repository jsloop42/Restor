//
//  RequestManager.swift
//  Restor
//
//  Created by jsloop on 16/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

extension Notification.Name {
    static let requestDidSend = Notification.Name("request-did-send")
    static let requestDidCancel = Notification.Name("request-did-cancel")
    static let responseDidReceive = Notification.Name("response-did-receive")
}

final class RequestManager {
    typealias ExtrapolateResult = (result: String, shouldExtrapolate: Bool, didExtrapolate: Bool)
    var request: ERequest
    var env: EEnv? {
        didSet {
            self.envVars = self.env?.variables?.allObjects as? [EEnvVar] ?? []
        }
    }
    var envVars: [EEnvVar] = []
    var fsm: RequestStateMachine
    private let localdb = CoreDataService.shared
    private let http: EAHTTPClient
    private let nc = NotificationCenter.default
    private var validateSSL = true
    
    init(request: ERequest, env: EEnv? = nil) {
        self.request = request
        self.env = env
        self.http = EAHTTPClient()
        self.fsm = RequestStateMachine(states: RequestManager.getAllRequestStates(request), request: request)
        self.fsm.manager = self
        self.http.delegate = self
        self.validateSSL = self.request.validateSSL
    }
    
    private static func getAllRequestStates(_ req: ERequest) -> [GKState] {
        return [RequestPrepareState(req), RequestSendState(req), RequestResponseState(req), RequestCancelState(req)]
    }
    
    func start() {
        self.fsm.enter(RequestPrepareState.self)
    }
    
    func prepareRequest() throws {
        Log.debug("[req-man] prepare-request")
        let urlReq = try self.requestToURLRequest(self.request)
        if urlReq == nil {
            Log.debug("urlrequest is nil -> moving to cancel state")
            throw AppError.invalidURL
        }
        let state = self.fsm.state(forClass: RequestSendState.self)
        state?.urlReq = urlReq
        self.fsm.enter(RequestSendState.self)
    }
    
    func sendRequest(_ urlReq: URLRequest) {
        Log.debug("[req-man] send-request")
        let start = DispatchTime.now()
        self.http.process(request: urlReq, completion: { result in
            let elapsed = start.elapsedTime().toInt64()
            self.responseDidObtain(result, request: urlReq, elapsed: elapsed)
        })
        self.nc.post(name: .requestDidSend, object: self, userInfo: ["request": self.request])
    }
    
    func responseDidObtain(_ result: Result<(Data, HTTPURLResponse, URLSessionTaskMetrics?), Error>, request: URLRequest, elapsed: Int64) {
        Log.debug("[req-man] response-did-obtain")
        if let _ = self.fsm.currentState as? RequestCancelState { return }
        guard let state = self.fsm.state(forClass: RequestResponseState.self) else { return }
        switch result {
        case .success(let (data, resp, metrics)):
            Log.debug("[req-man] resp; \(resp) - data: \(data)")
            state.response = resp
            state.responseBodyData = data
            state.metrics = metrics
        case .failure(let err):
            Log.error("[req-man] error: \(err)")
            state.error = err
        }
        DispatchQueue.main.async {
            var info: ResponseData!
            if let err = state.error {
                info = ResponseData(error: err, elapsed: elapsed, request: state.request, metrics: state.metrics)
            }
            if let resp = state.response {
                info = ResponseData(response: resp, request: state.request, urlRequest: request, responseData: state.responseBodyData,
                                    elapsed: elapsed, metrics: state.metrics)
            }
            self.saveResponse(&info)
        }
    }
    
    func saveResponse(_ info: inout ResponseData) {
        let ctx = self.localdb.mainMOC
        ctx.performAndWait {
            var info = info
            Log.debug("[req-man] save-response - \(info)")
            guard let ws = self.localdb.getWorkspace(id: self.request.getWsId()) else { return }
            var history: EHistory!
            // Save history if save response is enabled
            if ws.saveResponse {
                history = EHistory.initFromResponseData(info)
            } else {
                // Save only basic info
                let histId = self.localdb.historyId()
                history = self.localdb.createHistory(id: histId, wsId: info.wsId, ctx: ctx)
                if history != nil {
                    history.statusCode = info.statusCode.toInt64()
                    history.elapsed = info.connectionInfo.elapsed
                    history.responseBodyBytes = info.connectionInfo.responseBodyBytesReceived
                    history.requestId = info.requestId
                    history.url = info.url
                    history.isSecure = info.isSecure
                    history.method = info.method
                    history.request = "\(info.method) \(info.url) HTTP/1.1"
                }
            }
            if history != nil {
                info.history = history
                if let cookies = info.cookiesData as NSObject? { history.cookies = cookies }
                self.localdb.saveMainContext()
                if let ws = self.localdb.getWorkspace(id: history.getWsId()), ws.isSyncEnabled { PersistenceService.shared.saveHistoryToCloud(history!) }
            }
            AppState.requestState.removeValue(forKey: self.request.getId())
            let state = self.fsm.state(forClass: RequestResponseState.self)
            state?.data = info
            self.fsm.enter(RequestResponseState.self)
        }
    }
    
    func viewResponseScreen(data: ResponseData) {
        self.nc.post(name: .responseDidReceive, object: self, userInfo: ["data": data])
    }
    
    func cancelRequest() {
        Log.debug("[req-man] cancel-request")
        self.fsm.enter(RequestCancelState.self)
    }
    
    /// The request is cancelled and the FSM is now in cancelled state. Performs clean up.
    func requestDidCancel() {
        Log.debug("[req-man] request-did-cancel")
        self.nc.post(name: .requestDidCancel, object: self, userInfo: ["request": self.request])
    }
    
    func getURL(_ str: String?) throws -> URL? {
        guard var str = str else { return nil }
        let exp = try self.checkExtrapolationResult(self.extrapolate(str))
        str = exp.result
        if !str.starts(with: "http://") && !str.starts(with: "https://") { str = "http://\(str)" }
        return URL(string: str)
    }

    /// Checks if the string is in template form
    func shouldExtrapolate(_ str: String) -> Bool {
        // opening bracket match
        let idxL = str.firstIndex(of: "{")?.distance(in: str)
        if idxL == nil { return false }
        // closing bracket match
        if str[idxL! + 1] != "{" { return false }
        let idxR = str.firstIndex(of: "}")?.distance(in: str)
        if idxR == nil { return false }
        if idxR! <= idxL! { return false }
        if idxR! == str.count - 1 { return false }
        if str[idxR! + 1] != "}" { return false }
        return true
    }

    func extrapolate(_ string: String) -> ExtrapolateResult {
        let isExp = self.shouldExtrapolate(string)
        if self.envVars.isEmpty && isExp { return (string, true, false) }
        if !isExp { return (string, false, false) }
        let substr = string.slice(from: "{{", to: "}}") ?? ""
        if substr.isEmpty { return (string, isExp, false) }
        if let envVar = (self.envVars.first { x in x.name == substr }), let val = envVar.value as? String {
            let ret = string.replacingOccurrences(of: "{{\(substr)}}", with: val, options: .caseInsensitive)
            return (ret, isExp, string != ret)
        }
        return (string, isExp, false)
    }

    func checkExtrapolationResult(_ exp: ExtrapolateResult) throws -> ExtrapolateResult {
        if (exp.shouldExtrapolate && !exp.didExtrapolate) {  // extrapolate error
            throw AppError.extrapolate
        }
        return exp
    }
    
    func addContentType(_ value: String, urlReq: URLRequest) -> URLRequest {
        var urlReq = urlReq
        let contentType = urlReq.value(forHTTPHeaderField: "Content-Type") ?? ""
        let contentTypeLower = urlReq.value(forHTTPHeaderField: "content-type") ?? ""
        if (contentType.isEmpty && contentTypeLower.isEmpty) {
            urlReq.addValue(value, forHTTPHeaderField: "Content-Type")
        }
        return urlReq
    }
    
    func requestToURLRequest(_ req: ERequest) throws -> URLRequest? {
        Log.debug("[req-man] request-to-url-request")
        guard let projId = request.project?.getId() else { return nil }
        guard let url = try self.getURL(req.url) else { return nil }
        guard var urlComp = URLComponents(string: url.absoluteString) else { return nil }
        let qp = self.localdb.getParamsRequestData(request.getId())
        if !qp.isEmpty {
            urlComp.queryItems = try qp.map({ data -> URLQueryItem in
                let nameExp = try self.checkExtrapolationResult(self.extrapolate(data.key ?? ""))
                let valueExp = try self.checkExtrapolationResult(self.extrapolate(data.value ?? ""))
                return URLQueryItem(name: nameExp.result, value: valueExp.result)
            })
        }
        var headers: [String: String] = [:]
        let _headers = self.localdb.getHeadersRequestData(request.getId())
        if !_headers.isEmpty {
            try _headers.forEach { data in
                if let name = data.key, let val = data.value {
                    let keyExp = try self.checkExtrapolationResult(self.extrapolate(name))
                    let valueExp = try self.checkExtrapolationResult(self.extrapolate(val))
                    if keyExp.result.lowercased() == "content-type" && valueExp.result.lowercased() == "application/x-www-form-urlencoded" {
                        urlComp.percentEncodedQuery = urlComp.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                    }
                    headers[keyExp.result] = valueExp.result
                }
            }
        }
        headers["X-Restor-Id"] = UUID().uuidString.lowercased()
        let method = self.localdb.getRequestMethodData(at: request.selectedMethodIndex.toInt(), projId: projId)
        guard let aUrl = urlComp.url else { return nil }
        var urlReq = URLRequest(url: aUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        if let body = request.body {
            let bodyType = RequestBodyType(rawValue: body.selected.toInt()) ?? .json
            switch bodyType {
            case .json:
                if let x = body.json {
                    urlReq.httpBody = x.data(using: .utf8)
                    urlReq = self.addContentType("application/json", urlReq: urlReq)
                }
            case .xml:
                if let x = body.xml {
                    urlReq.httpBody = x.data(using: .utf8)
                    urlReq = self.addContentType("text/xml", urlReq: urlReq)
                }
            case .raw:
                if let x = body.raw { urlReq.httpBody = x.data(using: .utf8) }
            case .form:
                urlReq = self.getFormData(req, urlReq: urlReq)
            case .multipart:
                urlReq = self.getMultipartData(req, urlReq: urlReq)
            case .binary:
                urlReq = self.getBinaryData(req, urlReq: urlReq)
                urlReq = self.addContentType("application/octet-stream", urlReq: urlReq)
            }
        }
        urlReq.httpMethod = method?.name
        urlReq.allHTTPHeaderFields = headers
        Log.debug("curl: \(urlReq.curl())")
        return urlReq
    }
    
    func getFormData(_ req: ERequest, urlReq: URLRequest) -> URLRequest {
        Log.debug("[req-man] get-form-data")
        guard let body = req.body else { return urlReq }
        let bodyId = body.getId()
        let forms = self.localdb.getFormRequestData(bodyId, type: .form)
        let boundary = "Boundary-\(UUID().uuidString)"
        var acc: String!
        forms.forEach { data in
            let name = data.key ?? ""
            let val = data.value ?? ""
            if !data.disabled {
                if acc == nil { acc = "" }
                acc += "--\(boundary)\r\n"
                acc += "Content-Disposition:form-data; name=\"\(name)\""
                let format = RequestBodyFormFieldFormatType(rawValue: data.fieldFormat.toInt()) ?? .text
                if format == .text {
                    acc += "\r\n\r\n\(val)\r\n"
                } else {
                    let files = self.localdb.getFiles(data.getId(), type: .form)
                    files.forEach { file in
                        if let fdata = file.data, let fname = file.name {
                            acc += "; filename=\"\(fname)\"\r\n" +
                                   "Content-Type: \"content-type header\"\r\n\r\n\(fdata)\r\n"
                        }
                    }
                    if let image = data.image, let fdata = image.data, let fname = image.name {
                        acc += "; filename=\"\(fname)\"\r\n" +
                               "Content-Type: \"content-type header\"\r\n\r\n\(fdata)\r\n"
                    }
                }
            }
        }
        acc += "--\(boundary)--\r\n";
        var _urlReq = urlReq
        if acc != nil {
            _urlReq.httpBody = acc.data(using: .utf8)
            _urlReq.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
        return _urlReq
    }
    
    func getMultipartData(_ req: ERequest, urlReq: URLRequest) -> URLRequest {
        Log.debug("[req-man] get-multipart-data")
        guard let body = req.body else { return urlReq }
        let bodyId = body.getId()
        let mpart = self.localdb.getFormRequestData(bodyId, type: .multipart)
        var acc: String!
        mpart.forEach { data in
            if !data.disabled {
                if acc == nil { acc = "" }
                acc += "\(data.key ?? "")=\(data.value ?? "")"
            }
        }
        var _urlReq = urlReq
        if acc != nil { _urlReq.httpBody = acc.data(using: .utf8) }
        return _urlReq
    }
    
    func getBinaryData(_ req: ERequest, urlReq: URLRequest) -> URLRequest {
        Log.debug("[req-man] get-binary-data")
        guard let body = req.body, let bin = body.binary else { return urlReq }
        var _urlReq = urlReq
        if let file = (bin.files?.allObjects as? [EFile])?.first, let data = file.data {
            _urlReq.httpBody = data
        } else if let image = bin.image, let data = image.data {
            _urlReq.httpBody = data
        }
        return _urlReq
    }
}

extension RequestManager: EAHTTPClientDelegate {
    func shouldValidateSSL() -> Bool {
        return self.validateSSL
    }
    
    func getClientCertificate() -> (Data, String) {
        return (Data(count: 0), "")
    }
}
