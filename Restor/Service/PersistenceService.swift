//
//  PersistenceService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

fileprivate class CacheValue: EACacheValue {
    private var _key: String
    private var _value: CKRecord
    private var _ts: Int64
    private var _accessCount: Int
    
    init(key: String, value: CKRecord, ts: Int64, accessCount: Int) {
        self._key = key
        self._value = value
        self._ts = ts
        self._accessCount = accessCount
    }
    
    func value() -> Any {
        return self._value as Any
    }
    
    func key() -> String {
        self._key
    }
    
    func ts() -> Int64 {
        self._ts
    }
    
    func accessCount() -> Int {
        self._accessCount
    }
    
    func setValue(_ v: Any) {
        self._value = v as! CKRecord
    }
    
    func setKey(_ k: String) {
        self._key = k
    }
    
    func setTs(_ v: Int64) {
        self._ts = v
    }
    
    func setAccessCount(_ c: Int) {
        self._accessCount = c
    }
}

class PersistenceService {
    static let shared = PersistenceService()
    private lazy var localdb = { return CoreDataService.shared }()
    private lazy var ck = { return CloudKitService.shared }()
    var wsCache = EALFUCache(size: 8)
    var projCache = EALFUCache(size: 16)
    var reqCache = EALFUCache(size: 32)
    var reqDataCache = EALFUCache(size: 64)  // assuming we have one header and a param for a request, the size is double
    var reqBodyCache = EALFUCache(size: 32)  // same as req
    var fileCache = EALFUCache(size: 16)
    var imageCache = EALFUCache(size: 16)
    
    enum SubscriptionId: String {
        case fileChange = "file-change"
        case imageChange = "image-change"
        case projectChange = "project-change"
        case requestChange = "request-change"
        case requestMethodChange = "request-method-change"
        case workspaceChange = "workspace-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue]
        }
    }
    
    enum RecordType: String {
        case file = "File"
        case image = "Image"
        case project = "Project"
        case request = "Request"
        case requestMethod = "RequestMethod"
        case workspace = "Workspace"
    }
    
    func initDefaultWorkspace() -> EWorkspace? {
        if !isRunningTests { return self.localdb.getDefaultWorkspace() }
        return nil
    }
    
    func clearCache() {
        self.wsCache.resetCache()
        self.projCache.resetCache()
        self.reqCache.resetCache()
    }
    
    // MARK: - CloudKit
    
    func getSubscriptionIdForRecordType(_ type: RecordType) -> String {
        switch type {
        case .file:
            return SubscriptionId.fileChange.rawValue
        case .image:
            return SubscriptionId.imageChange.rawValue
        case .project:
            return SubscriptionId.projectChange.rawValue
        case .request:
            return SubscriptionId.requestChange.rawValue
        case .requestMethod:
            return SubscriptionId.requestMethodChange.rawValue
        case .workspace:
            return SubscriptionId.workspaceChange.rawValue
        }
    }
    
    func fetchWorkspaceRecord(_ ws: EProject, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = ws.id else { completion(.failure(AppError.error)); return }
        if let cached = self.wsCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: ws.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.wsCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchProjectRecord(_ proj: EProject, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = proj.id else { completion(.failure(AppError.error)); return }
        if let cached = self.projCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: proj.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.projCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchRequestRecord(_ req: ERequest, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = req.id else { completion(.failure(AppError.error)); return }
        if let cached = self.reqCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: req.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.reqCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchRequestDataRecord(_ reqData: ERequestData, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = reqData.id else { completion(.failure(AppError.error)); return }
        if let cached = self.reqDataCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: reqData.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.reqDataCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchRequestBodyDataRecord(_ reqBodyData: ERequestBodyData, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = reqBodyData.id else { completion(.failure(AppError.error)); return }
        if let cached = self.reqBodyCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: reqBodyData.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.reqBodyCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchFileRecord(_ file: EFile, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = file.id else { completion(.failure(AppError.error)); return }
        if let cached = self.fileCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: file.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.fileCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchImageRecord(_ image: EImage, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let id = image.id else { completion(.failure(AppError.error)); return }
        if let cached = self.imageCache.get(id), let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: image.getZoneID())
        self.ck.fetchRecord(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                Log.debug(hm[recordID] as Any)
                if let record = hm[recordID] {
                    self.reqDataCache.add(CacheValue(key: recordID.recordName, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let err):
                Log.error("Error fetching record \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func saveWorkspaceToCloud(_ ws: EWorkspace, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let wsId = ws.id else { Log.error("EWorkspace id is nil"); return }
        let zoneID = ws.getZoneID()
        let recordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
        let record = self.ck.createRecord(recordID: recordID, recordType: RecordType.workspace.rawValue)
        // TODO: add to save queue
    }
    
    func saveRequestToCloud(_ req: ERequest) {
        guard let id = req.id else { Log.error("ERequest id is nil"); return }
        guard let wsId = req.project?.workspace?.id else { Log.error("Error getting workspace id"); return }
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let ckReqID = self.ck.recordID(entityId: id, zoneID: zoneID)
        let ckReq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
        // todo: get project
        // let ckProj = fetchProject()
        //req.updateCKRecord(ckReq, project: ckProj)
    }
    
    /*
     
     1. Check if CKRecord is present in cache. If present, return, else fetch from cloud, add to cache, return
     2. If when saving, the server updated error is given, resolve conflict, save record, add to cache.
     3. Maintain separate cache for each entity type: workspace, project, request
     4. Cache size:
     
     */
}
