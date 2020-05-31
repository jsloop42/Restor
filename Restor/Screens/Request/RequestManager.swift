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
    var request: ERequest
    var fsm: RequestStateMachine
    private let localdb = CoreDataService.shared
    private let http: EAHTTPClient
    private let nc = NotificationCenter.default
    private var validateSSL = true
    
    init(request: ERequest) {
        self.request = request
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
    
    func prepareRequest() {
        Log.debug("[req-man] prepare-request")
        let urlReq = self.requestToURLRequest(self.request)
        if urlReq == nil {
            Log.debug("urlrequest is nil -> moving to cancel state")
            self.fsm.enter(RequestCancelState.self)
            return
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
            let state = self.fsm.state(forClass: RequestResponseState.self)
            state?.data = info
            self.fsm.enter(RequestResponseState.self)
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
            
            // TODO: test
            ws.saveResponse = true
            // TODO: end test
            
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
                history.cookies = info.cookiesData
                self.localdb.saveMainContext()
                if let ws = self.localdb.getWorkspace(id: history.getWsId()), ws.isSyncEnabled { PersistenceService.shared.saveHistoryToCloud(history!) }
            }
            AppState.requestState.removeValue(forKey: request.getId())
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
        // TODO:
    }
    
    func getURL(_ str: String?) -> URL? {
        guard var str = str else { return nil }
        if !str.starts(with: "http://") && !str.starts(with: "https://") { str = "http://\(str)" }
        return URL(string: str)
    }
    
    func requestToURLRequest(_ req: ERequest) -> URLRequest? {
        Log.debug("[req-man] request-to-url-request")
        guard let projId = request.project?.getId() else { return nil }
        guard let url = self.getURL(req.url) else { return nil }
        guard var urlComp = URLComponents(string: url.absoluteString) else { return nil }
        let qp = self.localdb.getParamsRequestData(request.getId())
        if !qp.isEmpty {
            urlComp.queryItems = qp.map({ data -> URLQueryItem in URLQueryItem(name: data.key ?? "", value: data.value ?? "") })
        }
        var headers: [String: String] = [:]
        let _headers = self.localdb.getHeadersRequestData(request.getId())
        if !_headers.isEmpty {
            _headers.forEach { data in
                if let name = data.key, let val = data.value {
                    if name.lowercased() == "content-type" && val.lowercased() == "application/x-www-form-urlencoded" {
                        urlComp.percentEncodedQuery = urlComp.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                    }
                }
                headers[data.key ?? ""] = data.value ?? ""
            }
        }
        let method = self.localdb.getRequestMethodData(at: request.selectedMethodIndex.toInt(), projId: projId)
        guard let aUrl = urlComp.url else { return nil }
        var urlReq = URLRequest(url: aUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        var bodyData: Data?
        if let body = request.body {
            let bodyType = RequestBodyType(rawValue: body.selected.toInt()) ?? .json
            switch bodyType {
            case .json:
                if let x = body.json { bodyData = x.data(using: .utf8) }
            case .xml:
                if let x = body.xml { bodyData = x.data(using: .utf8) }
            case .raw:
                if let x = body.raw { bodyData = x.data(using: .utf8) }
            case .form:
                urlReq = self.getFormData(req, urlReq: urlReq)
            case .multipart:
                urlReq = self.getMultipartData(req, urlReq: urlReq)
            case .binary:
                urlReq = self.getBinaryData(req, urlReq: urlReq)
            }
        }
        urlReq.httpMethod = method?.name
        urlReq.allHTTPHeaderFields = headers
        urlReq.httpBody = bodyData
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
