//
//  EHistory.swift
//  Restor
//
//  Created by jsloop on 20/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class EHistory: NSManagedObject, Entity {
    
    static func initFromResponseData(_ respData: ResponseData) -> EHistory {
        let history = EHistory(context: CoreDataService.shared.mainMOC)
        let ts = Date().currentTimeNanos()
        history.changeTag = ts
        history.created = ts
        history.modified = ts
        history.connection = respData.connectionInfo.connection
        history.connectionTime = respData.connectionInfo.connectionTime
        history.cookies = respData.cookiesData
        history.dnsResolutionTime = respData.connectionInfo.dnsTime
        history.elapsed = respData.connectionInfo.elapsed
        history.fetchStartTime = respData.connectionInfo.fetchStart
        history.hasRequestBody = respData.hasRequestBody
        history.id = CoreDataService.shared.historyId()
        history.isCellular = respData.connectionInfo.isCellular
        history.isMultipath = respData.connectionInfo.isMultipath
        history.isProxyConnection = respData.connectionInfo.isProxyConnection
        history.isReusedConnection = respData.connectionInfo.isReusedConnection
        history.isSecure = respData.isSecure
        history.isSynced = false
        history.localAddress = respData.connectionInfo.localAddress
        history.localPort = respData.connectionInfo.localPort
        history.method = respData.method
        history.networkProtocolName = respData.connectionInfo.networkProtocolName
        history.remoteAddress = respData.connectionInfo.remoteAddress
        history.remotePort = respData.connectionInfo.remotePort
        history.request = respData.urlRequest?.toString() ?? ""
        history.requestBodyBytes = respData.connectionInfo.requestBodyBytesSent
        history.requestHeaderBytes = respData.connectionInfo.requestHeaderBytesSent
        history.requestId = respData.requestId
        history.requestTime = respData.connectionInfo.requestTime
        history.responseBodyBytes = respData.connectionInfo.responseBodyBytesReceived
        history.responseData = respData.responseData
        history.responseHeaderBytes = respData.connectionInfo.responseHeaderBytesReceived
        // history.responseHeaders = respData.
        history.responseTime = respData.connectionInfo.responseTime
        history.secureConnectionTime = respData.connectionInfo.secureConnectionTime
        //history.sessionName = respData.connectionInfo.s
        history.statusCode = respData.statusCode.toInt64()
        history.tlsCipherSuite = respData.connectionInfo.negotiatedTLSCipherSuite
        history.tlsProtocolVersion = respData.connectionInfo.negotiatedTLSProtocolVersion
        history.url = respData.url
        history.version = 0
        history.wsId = respData.wsId
        return history
    }
    
    public var recordType: String { return "History" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.wsId ?? ""
    }
    
    public func setWsId(_ id: String) {
        self.wsId = id
    }
    
    public func getName() -> String {
        return ""
    }
    
    public func getCreated() -> Int64 {
        return self.created
    }
    
    public func getModified() -> Int64 {
        return self.modified
    }
    
    public func setModified(_ ts: Int64? = nil) {
        self.modified = ts ?? Date().currentTimeNanos()
    }
    
    public func getChangeTag() -> Int64 {
        return self.changeTag
    }
    
    public func setChangeTag(_ ts: Int64? = nil) {
        self.changeTag = ts ?? Date().currentTimeNanos()
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public override func willSave() {
        
    }
    
    public func updateCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            if let id = self.id, let data = self.cookies {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["cookies"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["elapsed"] = self.elapsed as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["isSecure"] = self.isSecure as CKRecordValue
            record["request"] = (self.request ?? "") as CKRecordValue  // urlRequestString
            record["requestId"] = (self.requestId ?? "") as CKRecordValue
            record["responseBodyBytes"] = self.responseBodyBytes as CKRecordValue
            if let id = self.id, let data = self.responseData {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["responseData"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            if let id = self.id, let data = self.responseHeaders {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["responseHeaders"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["statusCode"] = self.statusCode as CKRecordValue
            record["url"] = (self.url ?? "") as CKRecordValue
            record["method"] = (self.method ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
        }
    }
    
    public func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["cookies"] as? CKAsset, let url = x.fileURL {
                    do { self.cookies = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["request"] as? String { self.request = x }
                if let x = record["requestId"] as? String { self.requestId = x }
                if let x = record["responseData"] as? CKAsset, let url = x.fileURL {
                    do { self.responseData = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["responseHeaders"] as? CKAsset, let url = x.fileURL {
                    do { self.responseHeaders = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["statusCode"] as? Int64 { self.statusCode = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let x = record["wsId"] as? String { self.wsId = x }
            }
        }
    }
}
