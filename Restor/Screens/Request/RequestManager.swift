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

struct ResponseData: CustomDebugStringConvertible {
    var status: Bool
    var statusCode: Int
    var request: ERequest
    var urlRequest: URLRequest
    var response: HTTPURLResponse?
    var error: Error?
    var data: Data?
    var elapsed: Int
    var size: Int
    
    var debugDescription: String {
        return
            """
            \(type(of: self)))
            status: \(self.status)
            statusCode: \(self.statusCode)
            request: \(self.request)
            urlRequest: \(self.urlRequest)
            response: \(String(describing: self.response))
            error: \(String(describing: self.error))
            data: \(String(describing: self.data))
            elapsed: \(self.elapsed)
            size: \(self.size)
            """
    }
}

class RequestManager {
    var request: ERequest
    var fsm: RequestStateMachine
    private let localdb = CoreDataService.shared
    private let http: EAHTTPClient
    private let nc = NotificationCenter.default
    
    init(request: ERequest) {
        self.request = request
        self.http = EAHTTPClient()
        self.fsm = RequestStateMachine(states: RequestManager.getAllRequestStates(request), request: request)
        self.fsm.manager = self
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
            let elapsed = start.elapsedTime()
            let state = self.fsm.state(forClass: RequestResponseState.self)
            state?.result = result
            state?.urlRequest = urlReq
            state?.result = result
            state?.elapsed = elapsed
            self.fsm.enter(RequestResponseState.self)
        })
        self.nc.post(name: .requestDidSend, object: self, userInfo: ["request": self.request])
    }
    
    func responseDidObtain(_ result: Result<(Data, HTTPURLResponse), Error>, request: URLRequest) {
        Log.debug("[req-man] response-did-obtain")
        if let _ = self.fsm.currentState as? RequestCancelState { return }
        guard let state = self.fsm.state(forClass: RequestResponseState.self) else { return }
        switch result {
        case .success(let (data, resp)):
            Log.debug("[req-man] resp; \(resp) - data: \(data)")
            state.response = resp
            state.data = data
            state.success = (200..<300) ~= resp.statusCode
            state.statusCode = resp.statusCode
        case .failure(let err):
            Log.error("[req-man] error: \(err)")
            state.error = err
        }
        var size = 0
        if let sizeMap = state.response?.allHeaderFields.first(where: { (key: AnyHashable, value: Any) -> Bool in
            if let key = key as? String { return key.lowercased() == "content-length" }
            return false
        }) {
            size = Int(sizeMap.value as? String ?? "0") ?? 0
        }
        let info = ResponseData(status: state.success, statusCode: state.statusCode, request: self.request, urlRequest: state.urlRequest!, response: state.response, error: state.error,
                                data: state.data, elapsed: state.elapsed, size: size)
        self.saveResponse(info)
    }
    
    func saveResponse(_ info: ResponseData) {
        let ctx = self.localdb.mainMOC
        ctx.performAndWait {
            Log.debug("[req-man] save-response - \(info)")
            guard let ws = self.localdb.getWorkspace(id: self.request.getWsId()) else { return }
            var history: EHistory!
            // Save history if save response is enabled
            
            // TODO: test
            ws.saveResponse = true
            // TODO: end test
            
            if ws.saveResponse {
                let histId = self.localdb.historyId()
                let req = info.request
                let resp = info.response
                let urlReq = info.urlRequest
                let data: String = {
                    guard let rdata = info.data else { return "" }
                    return String(data: rdata, encoding: .utf8) ?? ""
                }()
                history = self.localdb.createHistory(id: histId, requestId: req.getId(), wsId: req.getWsId(), request: urlReq.toString(), response: data,
                                                     responseHeaders: URLRequest.headersToData(resp?.allHeaderFields), statusCode: info.statusCode.toInt64(),
                                                     elapsed: info.elapsed.toInt64(), responseBodySize: info.size.toInt64(), checkExists: true, ctx: ctx)
            } else {
                // Save only basic info
                let histId = self.localdb.historyId()
                history = self.localdb.createHistory(id: histId, wsId: info.request.getWsId(), ctx: ctx)
                if history != nil {
                    history.statusCode = info.statusCode.toInt64()
                    history.elapsed = info.elapsed.toInt64()
                    history.responseBodySize = info.size.toInt64()
                    history.requestId = info.request.getId()
                    let req = info.urlRequest
                    history.request = "\(req.httpMethod ?? "") \(req.url?.path ?? "") HTTP/1.1"
                }
            }
            if history != nil {
                self.localdb.saveMainContext()
                if let ws = self.localdb.getWorkspace(id: history.getWsId()), ws.isSyncEnabled { PersistenceService.shared.saveHistoryToCloud(history!) }
            }
            AppState.requestState.removeValue(forKey: request.getId())
            self.nc.post(name: .responseDidReceive, object: self, userInfo: ["data": info, "historyId": history.getId()])
        }
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
        if !str.starts(with: "http://") || !str.starts(with: "https://") { str = "http://\(str)" }
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
