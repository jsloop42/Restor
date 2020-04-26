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

struct DeferredSaveModel: Hashable {
    var record: CKRecord
    var entity: Entity? = nil
    /// Entity id
    var id: String
    var completion: (() -> Void)?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
    
    static func == (lhs: DeferredSaveModel, rhs: DeferredSaveModel) -> Bool {
        return lhs.id == rhs.id
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
    var reqMethodCache = EALFUCache(size: 16)
    var fileCache = EALFUCache(size: 16)
    var imageCache = EALFUCache(size: 16)
    var saveQueueCompletionHandler: (([CKRecord]) -> Void)!
    var saveQueue: EAQueue<DeferredSaveModel>!
    private let nc = NotificationCenter.default
    var defaultZoneCursor: CKQueryOperation.Cursor?
    private let store = UserDefaults.standard
    private let lastSyncedKey = "last-synced-key"
    private let lastSyncTimeKey = "last-sync-time-key"
    private let defaultQueryCursorKey = "default-query-cursor-key"
    private let syncRecordKey = "sync-record-key"
    private let defaultZoneRecordFetchLimit = 50
    private let opQueue = EAOperationQueue()
    private var syncTimer: DispatchSourceTimer?
    private var previousSyncTime: Int = 0
    private var isSyncFromCloudSuccess = false
    private var isSyncToCloudSuccess = false
    private var isSyncTimeSet = false
    private var queryDefaultZoneRecordRepeatTimer: EARepeatTimer!
    private var fetchZoneChangesDelayTimer: EARescheduler!
    private var syncFromCloudOpCount = 0
    private var isSyncToCloudTriggered = false  // On app launch, is syncing to cloud initialised
    private var syncToCloudTimer: DispatchSourceTimer!
    private var syncToCloudCtx: NSManagedObjectContext!
    private var wsSyncFrc: NSFetchedResultsController<EWorkspace>!
    private var projSyncFrc: NSFetchedResultsController<EProject>!
    private var reqSyncFrc: NSFetchedResultsController<ERequest>!
    private var projDelFrc: NSFetchedResultsController<EProject>!  // Since the back reference gets removed, we need to query them separately
    private var reqDelFrc: NSFetchedResultsController<ERequest>!
    private var reqDataDelFrc: NSFetchedResultsController<ERequestData>!
    private var reqBodyDataDelFrc: NSFetchedResultsController<ERequestBodyData>!
    private var reqMethodDataDelFrc: NSFetchedResultsController<ERequestMethodData>!
    private var fileDelFrc: NSFetchedResultsController<EFile>!
    private var imageDelFrc: NSFetchedResultsController<EImage>!
    private var wsSyncIdx = 0
    private var projSyncIdx = 0
    private var reqSyncIdx = 0
    private var projDelSyncIdx = 0
    private var reqDelSyncIdx = 0
    private var reqDataDelSyncIdx = 0
    private var reqBodyDataDelSyncIdx = 0
    private var reqMethodDataDelSyncIdx = 0
    private var fileDelSyncIdx = 0
    private var imageDelSyncIdx = 0
    
    enum SubscriptionId: String {
        case fileChange = "file-change"
        case imageChange = "image-change"
        case projectChange = "project-change"
        case requestChange = "request-change"
        case requestBodyChange = "request-body-change"
        case requestDataChange = "request-data-change"
        case requestMethodChange = "request-method-change"
        case workspaceChange = "workspace-change"
        case zoneChange = "zone-change"  // default zone change
        case databaseChange = "database-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestBodyChange.rawValue, SubscriptionId.requestDataChange.rawValue,
                    SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue, SubscriptionId.databaseChange.rawValue]
        }
    }
    
    enum CursorKey: String {
        case workspace = "workspace-cursor-key"
        case project = "project-cursor-key"
        case request = "request-cursor-key"
        case requestBodyData = "request-body-data-cursor-key"
        case requestData = "request-data-cursor-key"
        case requestMethodData = "request-method-data-cursor-key"
        case file = "file-cursor-key"
        case image = "image-cursor-key"
        case zone = "zone-cursor-key"
        
        init(type: RecordType) {
            switch type {
            case .workspace:
                self = .workspace
            case .project:
                self = .project
            case .request:
                self = .request
            case .requestBodyData:
                self = .requestBodyData
            case .requestData:
                self = .requestData
            case .requestMethodData:
                self = .requestMethodData
            case .file:
                self = .file
            case .image:
                self = .image
            case .zone:
                self = .zone
            }
        }
    }
    
    init() {
        self.previousSyncTime = self.getLastSyncTime()
        self.initSaveQueue()
        self.subscribeToCloudKitEvents()
        self.syncFromCloud()
    }
    
    func initDefaultWorkspace() -> EWorkspace? {
        if !isRunningTests { return self.localdb.getDefaultWorkspace() }
        return nil
    }
    
    func clearCache() {
        self.wsCache.resetCache()
        self.projCache.resetCache()
        self.reqCache.resetCache()
        self.reqBodyCache.resetCache()
        self.reqDataCache.resetCache()
        self.reqMethodCache.resetCache()
        self.fileCache.resetCache()
        self.imageCache.resetCache()
    }
    
    // MARK: - CloudKit
    
    func initSaveQueue() {
        self.saveQueue = EAQueue<DeferredSaveModel>(interval: 4.0, completion: { elems in
            guard !elems.isEmpty else { return }
            var records: [CKRecord] = []
            var entityMap: [CKRecord.ID: DeferredSaveModel] = [:]
            elems.forEach { records.append($0.record); entityMap[$0.record.recordID] = $0 }
            self.ck.saveRecords(records) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let xs):
                    Log.debug("Save to cloud success")
                    // Update the entities' attribute and cache
                    xs.forEach { record in
                        if let map = entityMap[record.recordID] {
                            if let entity = map.entity {
                                entity.setIsSynced(true)
                                if let type = RecordType(rawValue: record.recordType) {
                                    self.addToCache(record: record, entityId: entity.getId(), type: type)
                                    if type == .workspace {
                                        self.localdb.setWorkspaceActive(entity.getId())
                                    }
                                }
                            }
                            map.completion?()
                        }
                    }
                case .failure(let error):
                    Log.error("Error saving to cloud: \(error)")
                }
            }
        })
    }

    // MARK: - Cache
    
    func isSyncedOnce() -> Bool {
        return self.store.integer(forKey: self.lastSyncedKey) > 0
    }
    
    func setIsSyncedOnce() {
        self.store.set(Date().currentTimeNanos(), forKey: self.lastSyncedKey)
    }
    
    func removeIsSyncedOnce() {
        self.store.removeObject(forKey: self.lastSyncedKey)
    }
    
    // MARK: Query cursor cache
    
    func getCachedDefaultZoneQueryCursor() -> CKQueryOperation.Cursor? {
        guard let data = self.store.data(forKey: self.defaultQueryCursorKey) else { return nil }
        return CKQueryOperation.Cursor.decode(data)
    }
    
    func setDefaultZoneQueryCursorToCache(_ cursor: CKQueryOperation.Cursor) {
        if let data = cursor.encode() { self.store.set(data, forKey: self.defaultQueryCursorKey) }
    }
    
    func removeDefaultZoneQueryCursorFromCache() {
        self.store.removeObject(forKey: self.defaultQueryCursorKey)
    }
    
    func getQueryCursor(_ type: RecordType, zoneID: CKRecordZone.ID) -> CKQueryOperation.Cursor? {
        let key = CursorKey(type: type).rawValue
        if let zonesMap = self.store.dictionary(forKey: key), let data = zonesMap[zoneID.zoneName] as? Data {
            return CKQueryOperation.Cursor.decode(data)
        }
        return nil
    }
    
    func setQueryCursor(_ cursor: CKQueryOperation.Cursor, type: RecordType, zoneID: CKRecordZone.ID) {
        let key = CursorKey(type: type).rawValue
        var zonesMap = self.store.dictionary(forKey: key) ?? [:]
        zonesMap[zoneID.zoneName] = cursor.encode()
        self.store.set(zonesMap, forKey: key)
    }
    
    func removeQueryCursor(for type: RecordType) {
        self.store.removeObject(forKey: CursorKey(type: type).rawValue)
    }
    
    func removeQueryCursor(for type: RecordType, zoneID: CKRecordZone.ID) {
        let key = CursorKey(type: type).rawValue
        var zonesMap = self.store.dictionary(forKey: key) ?? [:]
        zonesMap.removeValue(forKey: zoneID.zoneName)
        self.store.set(zonesMap, forKey: key)
    }
    
    func getFromCache(entityId: String, type: RecordType) -> EACacheValue? {
        switch type {
        case .workspace:
            return self.wsCache.get(entityId)
        case .project:
            return self.projCache.get(entityId)
        case .request:
            return self.reqCache.get(entityId)
        case .requestData:
            return self.reqDataCache.get(entityId)
        case .requestBodyData:
            return self.reqBodyCache.get(entityId)
        case .requestMethodData:
            return self.reqMethodCache.get(entityId)
        case .file:
            return self.fileCache.get(entityId)
        case .image:
            return self.imageCache.get(entityId)
        case .zone:
            return nil
        }
    }
    
    func addToCache(record: CKRecord, entityId: String, type: RecordType) {
        switch type {
        case .workspace:
            self.wsCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .project:
            self.projCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .request:
            self.reqCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestData:
            self.reqDataCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestBodyData:
            self.reqBodyCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestMethodData:
            self.reqMethodCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .file:
            self.fileCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .image:
            self.imageCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .zone:
            break
        }
    }
    
    func addSyncOpToLocal(_ op: EACloudOperation) {
        if self.syncTimer == nil {
            self.syncTimer = DispatchSource.makeTimerSource()
            self.syncTimer?.schedule(deadline: .now() + .milliseconds(1500))
            self.syncTimer?.setEventHandler(handler: {
                var hm = self.getSyncOpFromLocal()
                let xs = hm.allValues()
                xs.forEach { data in
                    if let op = EACloudOperation.decode(data) {
                        if op.opType == .queryRecord {
                            op.completionHandler = self.syncFromCloudHandler(_:)
                        }
                        if self.opQueue.add(op) { hm.removeValue(forKey: op.getKey()) }
                    }
                }
                self.store.set(hm, forKey: self.syncRecordKey)
                if hm.isEmpty { self.syncTimer?.cancel(); self.syncTimer = nil }
            })
            self.syncTimer?.resume()
        }
        if var hm = self.store.dictionary(forKey: self.syncRecordKey) {
            let key = op.getKey()
            if hm[key] == nil, let data = op.encode() {
                hm[key] = data
                self.store.set(hm, forKey: self.syncRecordKey)
            }
        } else {
            self.store.set([op.getKey(): op.encode()], forKey: self.syncRecordKey)
        }
    }
    
    func getSyncOpFromLocal() -> [String: Data] {
        return self.store.dictionary(forKey: self.syncRecordKey) as? [String: Data] ?? [:]
    }
    
    func removeSyncRecordFromLocal(_ op: EACloudOperation) {
        if var hm = self.store.dictionary(forKey: self.syncRecordKey) {
            hm.removeValue(forKey: op.getKey())
            self.store.set(hm, forKey: self.syncRecordKey)
        }
    }
    
    // MARK: - Sync to cloud
    
    func initSyncToCloudState() {
        if self.isSyncToCloudTriggered { return }
        Log.debug("init sync to cloud state")
        DispatchQueue.global().sync {
            if self.syncToCloudTimer != nil { self.destroySyncToCloudState() }
        }
        self.syncToCloudTimer = DispatchSource.makeTimerSource()
        self.syncToCloudTimer.setEventHandler(handler: { [weak self] in self?.syncToCloud() })
        self.syncToCloudTimer.schedule(deadline: .now() + 4.5, repeating: 4.5)  // seconds
        if self.syncToCloudCtx != nil {
            if self.syncToCloudCtx.hasChanges { self.localdb.saveChildContext(self.syncToCloudCtx) }
            self.syncToCloudCtx = self.localdb.getChildMOC()
        }
        self.syncToCloudTimer.resume()
        self.isSyncToCloudTriggered = true
    }
    
    func destroySyncToCloudState() {
        Log.debug("destroy sync to cloud state")
        if self.syncToCloudTimer == nil { return }
        self.syncToCloudTimer.cancel()
        self.syncToCloudTimer.setEventHandler { }
        self.syncToCloudTimer = nil
    }
    
    func syncToCloud() {
        Log.debug("sync to cloud")
        if !self.isSyncTimeSet && self.isSyncFromCloudSuccess {
            Log.debug("setting sync time")
            self.setIsSyncedOnce()
            self.setLastSyncTime()
            self.isSyncTimeSet = true
        }
        if self.syncFromCloudOpCount == 0 && self.isSyncToCloudTriggered && self.isSyncTimeSet {  // => not initial sync - could be from notifications
            Log.debug("updating last sync time")
            self.setLastSyncTime()
        }
        if self.syncFromCloudOpCount > 0 && self.isSyncToCloudTriggered { return }
        if self.saveQueue.count > 16 { return }
        self.initSyncToCloudState()
        if self.wsSyncFrc == nil { self.wsSyncFrc = self.localdb.getWorkspacesToSync(ctx: self.syncToCloudCtx) }
        var count = 0
        var len = 0
        var start = 0
        var done: Bool = true  // sync visit complete
        if let xs = self.wsSyncFrc.fetchedObjects {
            start = self.wsSyncIdx
            len = xs.count
            for i in start..<len {
                self.saveWorkspaceToCloud(xs[i])
                self.wsSyncIdx += 1
                if count == 3 { break }
                count += 1
            }
            if done && self.wsSyncIdx < len { done = false }
        }
        if self.projSyncFrc == nil { self.projSyncFrc = self.localdb.getProjectsToSync(ctx: self.syncToCloudCtx) }
        if let xs = self.projSyncFrc.fetchedObjects {
            start = self.projSyncIdx
            len = xs.count
            count = 0
            for i in start..<len {
                self.saveProjectToCloud(xs[i])
                self.projSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.projSyncIdx < len { done = false }
        }
        if self.reqSyncFrc == nil { self.reqSyncFrc = self.localdb.getRequestsToSync(ctx: self.syncToCloudCtx) }
        if let xs = self.reqSyncFrc.fetchedObjects {
            start = self.reqSyncIdx
            len = xs.count
            count = 0
            for i in start..<len {
                self.saveRequestToCloud(xs[i])
                self.reqSyncIdx += 1
                if count == 3 { break }
                count += 1
            }
            if done && self.reqSyncIdx < len  { done = false }
        }
        // Delete entites marked for delete
        var delxs: [Entity] = []
        let deleteEntities: () -> Void = {
            if delxs.count > 15 {
                self.deleteEntitesFromCloud(delxs, ctx: self.syncToCloudCtx)
                delxs = []
            }
        }
        // project
        if self.projDelFrc == nil { self.projDelFrc = self.localdb.getDataMarkedForDelete(obj: EProject.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EProject> }
        if self.projDelFrc != nil, let xs = self.projDelFrc.fetchedObjects {
            start = self.projDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.projDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.projDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        // request
        if self.reqDelFrc == nil { self.reqDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequest.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequest> }
        if self.reqDelFrc != nil, let xs = self.reqDelFrc.fetchedObjects {
            start = self.reqDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.reqDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.reqDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        if self.reqDataDelFrc == nil { self.reqDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestData> }
        if self.reqDataDelFrc != nil, let xs = self.reqDataDelFrc.fetchedObjects {
            start = self.reqDataDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.reqDataDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.reqDataDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        if self.reqBodyDataDelFrc == nil { self.reqBodyDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestBodyData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestBodyData> }
        if self.reqBodyDataDelFrc != nil, let xs = self.reqBodyDataDelFrc.fetchedObjects {
            start = self.reqBodyDataDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.reqBodyDataDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.reqBodyDataDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        if self.reqMethodDataDelFrc == nil { self.reqMethodDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestMethodData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestMethodData> }
        if self.reqMethodDataDelFrc != nil, let xs = self.reqMethodDataDelFrc.fetchedObjects {
            start = self.reqMethodDataDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.reqMethodDataDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.reqMethodDataDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        if self.fileDelFrc == nil { self.fileDelFrc = self.localdb.getDataMarkedForDelete(obj: EFile.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EFile> }
        if self.fileDelFrc != nil, let xs = self.fileDelFrc.fetchedObjects {
            start = self.fileDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.fileDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.fileDelSyncIdx < len  { done = false }
        }
        deleteEntities()
        if self.imageDelFrc == nil { self.imageDelFrc = self.localdb.getDataMarkedForDelete(obj: EImage.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EImage> }
        if self.imageDelFrc != nil, let xs = self.imageDelFrc.fetchedObjects {
            start = self.imageDelSyncIdx
            len = xs.count
            for i in start..<len {
                delxs.append(xs[i])
                self.imageDelSyncIdx += 1
                if count == 7 { break }
                count += 1
            }
            if done && self.imageDelSyncIdx < len  { done = false }
        }
        self.deleteEntitesFromCloud(delxs, ctx: self.syncToCloudCtx)
        delxs = []
        if done { Log.debug("sync to cloud done"); self.destroySyncToCloudState() }
    }
    
    // MARK: - Sync from cloud
    
    func syncFromCloud() {
        Log.debug("sync from cloud")
        self.queryDefaultZoneRecords(completion: self.syncFromCloudHandler(_:))
    }
    
    func setLastSyncTime() {
        self.store.set(Date().currentTimeNanos(), forKey: self.lastSyncTimeKey)
    }
    
    func getLastSyncTime() -> Int {
        return self.store.integer(forKey: self.lastSyncTimeKey)
    }
    
    func syncFromCloudHandler(_ result: Result<[CKRecord], Error>) {
        Log.debug("sync from cloud handler")
        self.syncToCloud()
        switch result {
        case .success(let records):
            Log.debug("sync from cloud handler: records \(records.count)")
            records.forEach { record in _ = syncRecordFromCloudHandler(record) }
        case .failure(let error):
            Log.error("Error syncing from cloud: \(error)")
        }
        Log.debug("sync from cloud op count: \(self.syncFromCloudOpCount)")
    }
    
    func incSyncFromCloudOp() {
        self.syncFromCloudOpCount += 1
    }
    
    func decSyncFromCloudOp() {
        if self.syncFromCloudOpCount == 0 { self.syncToCloud(); return }
        self.syncFromCloudOpCount -= 1
        self.syncToCloud()
    }
    
    func getQueryRecordCloudOp(recordType: RecordType, zoneID: CKRecordZone.ID, parentId: String? = nil, changeTag: Int? = 0) -> EACloudOperation {
        return EACloudOperation(recordType: recordType, opType: .queryRecord, zoneID: zoneID, parentId: parentId, changeTag: changeTag, block: { [weak self] _ in
            self?.incSyncFromCloudOp()
            self?.queryRecords(zoneID: zoneID, type: recordType, parentId: parentId ?? "", changeTag: changeTag) { result in
                self?.decSyncFromCloudOp()
                self?.syncFromCloudHandler(result)
            }
        })
    }
    
    func syncRecordFromCloudHandler(_ record: CKRecord) -> Bool {
        let changeTag = self.isSyncedOnce() ? self.previousSyncTime : 0
        switch RecordType(rawValue: record.type()) {
        case .zone:
            let zoneID = self.ck.zoneID(workspaceId: record.id())
            let op = EACloudOperation(recordType: .zone, opType: .fetchZoneChange, zoneID: zoneID, block: { [weak self] _ in
                self?.fetchZoneChanges(zoneIDs: [zoneID], isDeleteOnly: true, completion: { self?.syncToCloud() })
            })
            if !self.opQueue.add(op) { self.addSyncOpToLocal(op) }
            fallthrough
        case .workspace:
            self.updateWorkspaceFromCloud(record)
            let wsId = record.id()
            let zoneID = self.ck.zoneID(workspaceId: wsId)
            let op = self.getQueryRecordCloudOp(recordType: .project, zoneID: zoneID, parentId: wsId, changeTag: changeTag)
            op.completionBlock = { Log.debug("op completion: - query project") }
            if !self.opQueue.add(op) { self.addSyncOpToLocal(op); return false }
            return true
        case .project:
            self.updateProjectFromCloud(record)
            let zoneID = record.zoneID()
            let projId = record.id()
            var status = true
            let opreq = self.getQueryRecordCloudOp(recordType: .request, zoneID: zoneID, parentId: projId, changeTag: changeTag)
            opreq.completionBlock = { Log.debug("op completion: - query request") }
            if !self.opQueue.add(opreq) { self.addSyncOpToLocal(opreq); status = false }
            let opreqmeth = self.getQueryRecordCloudOp(recordType: .requestMethodData, zoneID: zoneID, parentId: projId, changeTag: changeTag)
            opreqmeth.completionBlock = { Log.debug("op completion: - query request method") }
            if !self.opQueue.add(opreqmeth) { self.addSyncOpToLocal(opreqmeth); status = false }
            return status
        case .request:
            self.updateRequestFromCloud(record)
            let zoneID = record.zoneID()
            let reqId = record.id()
            var status = false
            let opreqdata = self.getQueryRecordCloudOp(recordType: .requestData, zoneID: zoneID, parentId: reqId, changeTag: changeTag)
            opreqdata.completionBlock = { Log.debug("op completion: - query request") }
            if !self.opQueue.add(opreqdata) { self.addSyncOpToLocal(opreqdata); status = false }
            let opreqbody = self.getQueryRecordCloudOp(recordType: .requestBodyData, zoneID: zoneID, parentId: reqId, changeTag: changeTag)
            opreqbody.completionBlock = { Log.debug("op completion: - query request method") }
            if !self.opQueue.add(opreqbody) { self.addSyncOpToLocal(opreqbody); status = false }
            return status
        case .requestBodyData:
            self.updateRequestBodyDataFromCloud(record)
            let op = self.getQueryRecordCloudOp(recordType: .requestData, zoneID: record.zoneID(), parentId: record.id(), changeTag: changeTag)
            op.completionBlock = { Log.debug("op completion: - query request data") }
            if !self.opQueue.add(op) { self.addSyncOpToLocal(op); return false }
            return true
        case .requestData:
            self.updateRequestDataFromCloud(record)
            let zoneID = record.zoneID()
            let reqDataId = record.id()
            var status = false
            let opreq = self.getQueryRecordCloudOp(recordType: .file, zoneID: zoneID, parentId: reqDataId, changeTag: changeTag)
            opreq.completionBlock = { Log.debug("op completion: - query file") }
            if !self.opQueue.add(opreq) { self.addSyncOpToLocal(opreq); status = false }
            let opreqbody = self.getQueryRecordCloudOp(recordType: .image, zoneID: zoneID, parentId: reqDataId, changeTag: changeTag)
            opreqbody.completionBlock = { Log.debug("op completion: - query image") }
            if !self.opQueue.add(opreqbody) { self.addSyncOpToLocal(opreqbody); status = false }
            return status
        case .requestMethodData:
            self.updateRequestMethodDataFromCloud(record)
        case .file:
            self.updateFileDataFromCloud(record)
        case .image:
            self.updateImageDataFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
        return true
    }
    
    func subscribeToCloudKitEvents() {
        Log.debug("subscribe to cloudkit events")
        self.ck.subscribeToDBChanges(subId: SubscriptionId.databaseChange.rawValue)
    }
    
    func subscribeToWorkspaceChange(_ wsId: String) {
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let subID = self.ck.subscriptionID(self.getSubscriptionIdForRecordType(.workspace), zoneID: zoneID)
        self.ck.subscribe(subID, recordType: RecordType.workspace.rawValue, zoneID: zoneID)
    }
    
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
        case .requestData:
            return SubscriptionId.requestDataChange.rawValue
        case .requestBodyData:
            return SubscriptionId.requestBodyChange.rawValue
        case .requestMethodData:
            return SubscriptionId.requestMethodChange.rawValue
        case .workspace:
            return SubscriptionId.workspaceChange.rawValue
        case .zone:
            return SubscriptionId.zoneChange.rawValue
        }
    }
    
    // MARK: - Cloud record merge (conflict)
    
    /// Check if server record is latest. Cases were a record is created locally, but failed to sync, new record gets added from another device, and then the
    /// former record gets saved, in which case the server copy is latest.
    func isServerLatest(local: CKRecord, server: CKRecord) -> Bool {
        if let lts = local["changeTag"] as? Int64, let rts = server["changeTag"] as? Int64 { return rts > lts }
        return false
    }
    
    func mergeWorkspace(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeProject(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequest(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequestBodyData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }

    func mergeRequestData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequestMethodData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeFileData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeImageData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRecords(local: CKRecord?, server: CKRecord?, recordType: String) -> CKRecord? {
        guard let client = local, let remote = server, let type = RecordType(rawValue: recordType) else { return nil }
        switch type {
        case .workspace:
            return self.mergeWorkspace(local: client, server: remote)
        case .project:
            return self.mergeProject(local: client, server: remote)
        case .request:
            return self.mergeRequest(local: client, server: remote)
        case .requestData:
            return self.mergeRequestData(local: client, server: remote)
        case .requestBodyData:
            return self.mergeRequestBodyData(local: client, server: remote)
        case .requestMethodData:
            return self.mergeRequestMethodData(local: client, server: remote)
        case .file:
            return self.mergeFileData(local: client, server: remote)
        case .image:
            return self.mergeImageData(local: client, server: remote)
        case .zone:
            return server
        }
    }
    
    // MARK: - Cloud record updated
    
    func updateWorkspaceFromCloud(_ record: CKRecord) {
        let wsId = record.id()
        let ctx = self.localdb.getChildMOC()
        var aws = self.localdb.getWorkspace(id: wsId, ctx: ctx)
        var isNew = false
        if aws == nil {
            aws = self.localdb.createWorkspace(id: wsId, name: record.name(), desc: record.desc(), isSyncEnabled: record.isSyncEnabled(), ctx: ctx)
            isNew = true
        }
        guard let ws = aws else { return }
        if isNew || (ws.isSyncEnabled && (!ws.isActive || ws.changeTag < record.changeTag)) {  // => server has new copy
            ws.updateFromCKRecord(record)
            ws.isSynced = true
            ws.isActive = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Workspace synced")
            self.nc.post(Notification(name: NotificationKey.workspaceDidSync))
        }
    }
    
    func updateProjectFromCloud(_ record: CKRecord) {
        let projId = record.id()
        let ctx = self.localdb.getChildMOC()
        var aproj = self.localdb.getProject(id: projId, ctx: ctx)
        var isNew = false
        if aproj == nil {
            aproj = self.localdb.createProject(id: record.id(), wsId: record.getWsId(), name: record.name(), desc: record.desc(), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let proj = aproj else { return }
        if isNew || proj.changeTag < record.changeTag {  // => server has new copy
            proj.updateFromCKRecord(record, ctx: ctx)
            proj.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Project synced")
            self.nc.post(Notification(name: NotificationKey.projectDidSync))
        }
    }
    
    func updateRequestFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        guard let proj = ERequest.getProject(record, ctx: ctx) else { Log.error("Error getting project"); return }
        let reqId = record.id()
        var areq = self.localdb.getRequest(id: reqId, ctx: ctx)
        var isNew = false
        if areq == nil {
            areq = self.localdb.createRequest(id: record.id(), wsId: record.getWsId(), name: record.name(), project: proj, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let req = areq else { return }
        if isNew || req.changeTag < record.changeTag {  // => server has new copy
            req.updateFromCKRecord(record, ctx: ctx)
            req.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request synced")
            self.nc.post(Notification(name: NotificationKey.requestDidSync))
        }
    }
        
    func updateRequestBodyDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let reqId = record.id()
        var aReqBodyData = self.localdb.getRequestBodyData(id: reqId, ctx: ctx)
        var isNew = false
        if aReqBodyData == nil {
            aReqBodyData = self.localdb.createRequestBodyData(id: record.id(), wsId: record.getWsId(), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqBodyData = aReqBodyData else { return }
        if isNew || reqBodyData.changeTag < record.changeTag {  // => server has new copy
            reqBodyData.updateFromCKRecord(record, ctx: ctx)
            reqBodyData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request body synced")
            self.nc.post(Notification(name: NotificationKey.requestBodyDataDidSync))
        }
    }
    
    func updateRequestDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        guard let type = ERequestData.getRecordType(record) else { return }
        let fieldType = ERequestData.getFormFieldFormatType(record)
        let reqId = record.id()
        var aData = self.localdb.getRequestData(id: reqId, ctx: ctx)
        var isNew = false
        if aData == nil {
            aData = self.localdb.createRequestData(id: reqId, wsId: record.getWsId(), type: type, fieldFormat: fieldType, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqData = aData else { return }
        if isNew || reqData.changeTag < record.changeTag {  // => server has new copy
            reqData.updateFromCKRecord(record, ctx: ctx)
            reqData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request data synced")
            self.nc.post(Notification(name: NotificationKey.requestDataDidSync))
        }
    }
    
    func updateRequestMethodDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let reqMethodDataId = record.id()
        var aReqMethodData = self.localdb.getRequestMethodData(id: reqMethodDataId, ctx: ctx)
        var isNew = false
        if aReqMethodData == nil {
            aReqMethodData = self.localdb.createRequestMethodData(id: reqMethodDataId, wsId: record.getWsId(), name: record.name(), isCustom: true, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqMethodData = aReqMethodData else { return }
        if isNew || reqMethodData.changeTag < record.changeTag {  // => server has new copy
            reqMethodData.updateFromCKRecord(record, ctx: ctx)
            reqMethodData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request method data synced")
            self.nc.post(Notification(name: NotificationKey.requestMethodDataDidSync))
        }
    }
    
    func updateFileDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let fileId = record.id()
        var aFileData = self.localdb.getFileData(id: fileId, ctx: ctx)
        var isNew = false
        if aFileData == nil {
            aFileData = self.localdb.createFile(data: Data(), wsId: record.getWsId(), name: record.name(), path: URL(fileURLWithPath: "/tmp/"), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let fileData = aFileData else { return }
        if isNew || fileData.changeTag < record.changeTag {  // => server has new copy
            fileData.updateFromCKRecord(record, ctx: ctx)
            fileData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("File data synced")
            self.nc.post(Notification(name: NotificationKey.fileDataDidSync))
        }
    }
    
    func updateImageDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let fileId = record.id()
        var aImageData = self.localdb.getImageData(id: fileId, ctx: ctx)
        var isNew = false
        if aImageData == nil {
            aImageData = self.localdb.createImage(data: Data(), wsId: record.getWsId(), name: record.name(), type: ImageType.jpeg.rawValue, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let imageData = aImageData else { return }
        if isNew || imageData.changeTag < record.changeTag {  // => server has new copy
            imageData.updateFromCKRecord(record, ctx: ctx)
            imageData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Image data synced")
            self.nc.post(Notification(name: NotificationKey.imageDataDidSync))
        }
    }
    
    func cloudRecordDidChange(_ record: CKRecord) {
        let type = RecordType(rawValue: record.recordType)
        switch type {
        case .workspace:
            self.updateWorkspaceFromCloud(record)
        case .project:
            self.updateProjectFromCloud(record)
        case .request:
            self.updateRequestFromCloud(record)
        case .requestBodyData:
            self.updateRequestBodyDataFromCloud(record)
        case .requestData:
            self.updateRequestDataFromCloud(record)
        case .requestMethodData:
            self.updateRequestMethodDataFromCloud(record)
        case .file:
            self.updateFileDataFromCloud(record)
        case .image:
            self.updateImageDataFromCloud(record)
        case .zone:
            self.updateWorkspaceFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
    }
    
    // MARK: - Cloud record deleted
    
    func workspaceDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteWorkspace(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func projectDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteProject(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequest(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
        
    func requestBodyDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestBodyData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestMethodDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestMethodData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func fileDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteFileData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func imageDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteImageData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func cloudRecordDidDelete(_ recordID: CKRecord.ID) {
        Log.debug("cloud record did delete: \(recordID)")
        let id = self.ck.entityID(recordID: recordID)
        let type = RecordType.from(id: id)
        switch type {
        case .workspace:
            self.workspaceDidDeleteFromCloud(id)
        case .project:
            self.projectDidDeleteFromCloud(id)
        case .request:
            self.requestDidDeleteFromCloud(id)
        case .requestBodyData:
            self.requestBodyDataDidDeleteFromCloud(id)
        case .requestData:
            self.requestDataDidDeleteFromCloud(id)
        case .requestMethodData:
            self.requestMethodDataDidDeleteFromCloud(id)
        case .file:
            self.fileDataDidDeleteFromCloud(id)
        case .image:
            self.imageDataDidDeleteFromCloud(id)
        case .zone:
            break
        case .none:
            Log.error("Unknown record type: \(id)")
        }
    }
    
    func cloudRecordsDidDelete(_ recordsIDs: [CKRecord.ID]) {
        recordsIDs.forEach { self.cloudRecordDidDelete($0) }
    }
    
    // MARK: - Local record deleted
    
    /// Delete data marked for delete. Used mainly after edit request.
    /// - Parameters:
    ///   - set: The entities deleted in the edit request.
    ///   - request: The request object.
    func deleteDataMarkedForDelete(_ set: Set<NSManagedObject>, request: ERequest) {
        Log.debug("delete data marked for delete - set: \(set.count) for req: \(request)")
        guard set.count > 0 else { return }
        self.deleteEntitesFromCloud(set.toArray() as! [Entity])
        App.shared.clearEditRequestDeleteObjects()
    }
    
    func deleteDataMarkedForDelete(_ ws: EWorkspace, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - ws")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        let xs = self.localdb.getProjects(wsId: ws.getId(), includeMarkForDelete: true, ctx: ctx)
        xs.forEach { proj in self.deleteDataMakedForDelete(proj, ctx: ctx) }
        self.deleteEntitesFromCloud([ws], ctx: ctx)
    }
    
    func deleteDataMakedForDelete(_ proj: EProject, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - proj")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        let xs = self.localdb.getRequests(projectId: proj.getId(), includeMarkForDelete: true, ctx: ctx)
        xs.forEach { req in self.deleteDataMarkedForDelete(req, ctx: ctx) }
        self.deleteEntitesFromCloud([proj], ctx: ctx)
    }
    
    func deleteDataMarkedForDelete(_ request: ERequest, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - req")
        guard let ws = request.project?.workspace else { return }
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        if request.markForDelete {
            var acc: [Entity] = []
            if let xs = request.headers?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
            if let xs = request.params?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
            if let body = request.body {
                if let xs = body.form?.allObjects as? [ERequestData] {
                    xs.forEach { reqData in
                        if let files = reqData.files?.allObjects as? [EFile] { acc.append(contentsOf: files) }
                        if let image = reqData.image { acc.append(image) }
                        acc.append(reqData)
                    }
                }
                if let xs = body.multipart?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
                if let bin = body.binary {
                    if let xs = bin.files?.allObjects as? [EFile] { acc.append(contentsOf: xs) }
                    if let image = bin.image { acc.append(image) }
                    acc.append(bin)
                }
                acc.append(body)
            }
            self.deleteEntitesFromCloud([request], ctx: ctx)
        } else {
            self.deleteRequestDataMarkedForDelete(reqId: request.getId(), wsId: ws.getId(), ctx: ctx)
            self.deleteRequestBodyDataMarkedForDelete(request, ctx: ctx)
        }
        self.deleteRequestMethodDataMarkedForDelete(request, ctx: ctx)
    }
    
    func deleteRequestDataMarkedForDelete(reqId: String, wsId: String, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete request data marked for delete: reqId: \(reqId)")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        var xs = self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .header, ctx: ctx)
        xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .param, ctx: ctx))
        xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .form, ctx: ctx))
        xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .multipart, ctx: ctx))
        xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .binary, ctx: ctx))
        var files: [EFile] = []
        xs.forEach { reqData in
            files.append(contentsOf: self.localdb.getFilesMarkedForDelete(reqDataId: reqData.getId(), ctx: ctx))
            self.deleteDataMarkedForDelete(reqData.image, wsId: wsId)
        }
        self.deleteEntitesFromCloud(files, ctx: ctx)
        self.deleteEntitesFromCloud(xs, ctx: ctx)
    }
    
    func deleteDataMarkedForDelete(_ files: [EFile], wsId: String, ctx: NSManagedObjectContext? = nil) {
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        self.deleteEntitesFromCloud(files, ctx: ctx)
    }
    
    func deleteDataMarkedForDelete(_ image: EImage?, wsId: String, ctx: NSManagedObjectContext? = nil) {
        guard let image = image, image.markForDelete else { return }
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        self.deleteEntitesFromCloud([image], ctx: ctx)
    }
    
    func deleteRequestBodyDataMarkedForDelete(_ req: ERequest, ctx: NSManagedObjectContext? = nil) {
        if let body = req.body, body.markForDelete {
            let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
            self.deleteEntitesFromCloud([body], ctx: ctx)
        }
    }
    
    func deleteRequestMethodDataMarkedForDelete(_ req: ERequest, ctx: NSManagedObjectContext? = nil) {
        if let proj = req.project {
            let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
            self.deleteEntitesFromCloud(self.localdb.getRequestMethodDataMarkedForDelete(projId: proj.getId(), ctx: self.localdb.getChildMOC()), ctx: ctx)
        }
    }
    
    private func deleteEntitesFromCloud(_ xs: [Entity], ctx: NSManagedObjectContext? = nil) {
        if xs.isEmpty { return }
        var xs = xs
        Log.debug("delete data count: \(xs.count)")
        var recordIDs = xs.map { elem -> CKRecord.ID in elem.getRecordID() }
        let op = EACloudOperation(deleteRecordIDs: recordIDs) { [weak self] _ in
            self?.ck.deleteRecords(recordIDs: recordIDs) { result in
                switch result {
                case .success(let deleted):
                    Log.debug("Delete records: \(deleted)")
                    deleted.forEach { recordID in
                        if let idx = (recordIDs.firstIndex { oRecordID -> Bool in oRecordID == recordID }) {
                            let elem = xs[idx]
                            xs.remove(at: idx)
                            recordIDs.remove(at: idx)
                            self?.localdb.deleteEntity(elem)
                        }
                    }
                    Log.debug("Remaining entities to delete: \(xs.count)")
                    // if xs.count > 0 { self.deleteEntitesFromCloud(xs, zoneID: zoneID) }
                case .failure(let error):
                    Log.error("Error deleting records: \(error)")
                }
            }
        }
        if !self.opQueue.add(op) { self.addSyncOpToLocal(op) }
    }
 
    // MARK: - Query
    
    func queryDefaultZoneRecords(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("query default zone records")
        self.ck.queryRecords(zoneID: self.ck.defaultZoneID(), recordType: RecordType.zone.rawValue, predicate: NSPredicate(format: "isSyncEnabled == %hdd", true),
                             cursor: self.getCachedDefaultZoneQueryCursor(), limit: self.defaultZoneRecordFetchLimit) { [weak self] result in
            Log.debug("query default zone records handler")
            guard let self = self else { return }
            switch result {
            case .success(let (records, cursor)):
                self.isSyncFromCloudSuccess = true
                if let cursor = cursor { self.setDefaultZoneQueryCursorToCache(cursor) }
                completion(.success(records))
            case .failure(let error):
                Log.error("Error querying default zone record: \(error)")
                self.isSyncFromCloudSuccess = false
                completion(.failure(error))
                break
            }
        }
    }
    
    /// Fetch records belonging to the given record type with id in the given zone.
    /// - Parameters:
    ///   - zoneID: The zone in which the record exists
    ///   - type: The record type
    ///   - parentId: The parent Id of the record which is used in predicate
    ///   - isContinue: Should continue from the previous cursor if exists. If set to false, the cursor will be removed from the cache.
    ///   - changeTag: The last sync time which is used to fetch records modified after that
    ///   - completion: The completion handler.
    func queryRecords(zoneID: CKRecordZone.ID, type: RecordType, parentId: String, predicate: NSPredicate? = nil, isContinue: Bool? = true, changeTag: Int? = 0, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("query records: \(zoneID), type: \(type), parentId: \(parentId) modified: \(changeTag ?? 0)")
        let changeTag = changeTag ?? 0
        let cursor: CKQueryOperation.Cursor? = self.getQueryCursor(type, zoneID: zoneID)
        let predicate: NSPredicate = {
            if predicate != nil { return predicate! }
            var pred: NSPredicate!
            switch type {
            case .workspace:
                pred = NSPredicate(format: "changeTag >= %ld", changeTag)
            case .project:
                pred = NSPredicate(format: "workspace == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .request:
                pred = NSPredicate(format: "project == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .requestBodyData:
                pred = NSPredicate(format: "request == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .requestData:
                [NSPredicate(format: "binary == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag),
                 NSPredicate(format: "form == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag),
                 NSPredicate(format: "header == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag),
                 NSPredicate(format: "image == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag),
                 NSPredicate(format: "multipart == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)].forEach { pred in
                    self.queryRecords(zoneID: zoneID, type: type, parentId: parentId, predicate: pred, isContinue: isContinue, completion: completion)
                }
                pred = NSPredicate(format: "param == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .requestMethodData:
                pred = NSPredicate(format: "project == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .file:
                pred = NSPredicate(format: "requestData == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .image:
                pred = NSPredicate(format: "requestData == %@ AND changeTag >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), changeTag)
            case .zone:
                pred = NSPredicate(format: "isSyncEnabled == %hdd AND changeTag >= %ld", true, changeTag)
            }
            return pred
        }()
        self.ck.queryRecords(zoneID: zoneID, recordType: type.rawValue, predicate: predicate,
                             cursor: cursor, limit: self.defaultZoneRecordFetchLimit) { [weak self] result in
            self?.queryRecordsHandler(zoneID: zoneID, type: type, parentId: parentId, isContinue: isContinue, result: result, completion: completion)
        }
    }
    
    func queryRecordsHandler(zoneID: CKRecordZone.ID, type: RecordType, parentId: String, isContinue: Bool? = true, result: Result<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        switch result {
        case .success(let (records, cursor)):
            if let cursor = cursor {
                self.setQueryCursor(cursor, type: type, zoneID: zoneID)
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self.queryRecords(zoneID: zoneID, type: type, parentId: parentId, isContinue: isContinue, completion: completion)
                }
            } else {
                self.removeQueryCursor(for: type, zoneID: zoneID)
            }
            completion(.success(records))
        case .failure(let error):
            Log.error("Error querying records: \(error)")
            completion(.failure(error))
            break
        }
    }
    
    // MARK: - Fetch
    
    func fetchZoneChanges(zoneIDs: [CKRecordZone.ID], isDeleteOnly: Bool? = false, isDelayedFetch: Bool? = false, completion: (() -> Void)? = nil) {
        Log.debug("fetching zone changes for zoneIDs: \(zoneIDs) - isDelayedFetch: \(isDelayedFetch ?? false)")
        if isDelayedFetch != nil, isDelayedFetch! {
            if self.fetchZoneChangesDelayTimer == nil {
                self.fetchZoneChangesDelayTimer = EARescheduler(interval: 4.0, type: .everyFn, limit: 4)
                Log.debug("Delayed fetch of zones initialised")
            }
            self.fetchZoneChangesDelayTimer.schedule(fn: EAReschedulerFn(id: "fetch-zone-changes", block: { [weak self] in
                guard let self = self else { return false }
                self.incSyncFromCloudOp()
                self.ck.fetchZoneChanges(zoneIDs: zoneIDs, completion: { result in
                    self.decSyncFromCloudOp()
                    self.zoneChangeHandler(isDeleteOnly: isDeleteOnly ?? false, result: result, completion: completion)
                })
                Log.debug("Delayed exec - fetch zones")
                return true
            }, callback: { _ in
                self.fetchZoneChangesDelayTimer = nil
                Log.debug("Delayed fetch exec - done")
            }, args: []))
        } else {
            self.incSyncFromCloudOp()
            self.ck.fetchZoneChanges(zoneIDs: zoneIDs, completion: { result in
                self.decSyncFromCloudOp()
                self.zoneChangeHandler(isDeleteOnly: isDeleteOnly ?? false, result: result, completion: completion)
            })
        }
    }
    
    func zoneChangeHandler(isDeleteOnly: Bool, result: Result<(saved: [CKRecord], deleted: [CKRecord.ID]), Error>, completion: (() -> Void)? = nil) {
        switch result {
        case .success(let (saved, deleted)):
            if !isDeleteOnly { saved.forEach { record in self.cloudRecordDidChange(record) } }
            deleted.forEach { record in self.cloudRecordDidDelete(record) }
        case .failure(let error):
            Log.error("Error getting zone changes: \(error)")
        }
        completion?()
    }
    
    /// Checks if the record is present in cache. If present, returns, else fetch from cloud, adds to the cache and returns.
    func fetchRecord(_ entity: Entity, type: RecordType, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let id = entity.getId()
        if let cached = self.getFromCache(entityId: id, type: type) as? CacheValue, let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: entity.getZoneID())
        self.ck.fetchRecords(recordIDs: [recordID]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                if let record = hm[recordID] {
                    self.addToCache(record: record, entityId: id, type: type)
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func fetchRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.ck.fetchRecords(recordIDs: recordIDs) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                let records = hm.allValues()
                records.forEach { record in self.addToCache(record: record, entityId: record.id(), type: RecordType(rawValue: record.type())!) }
                completion(.success(records))
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches workspaces from cloud and caches the result.
    func fetchWorkspaces(zoneIDs: [CKRecordZone.ID], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("fetching workspaces")
        self.ck.fetchRecords(recordIDs: self.ck.recordIDs(zoneIDs: zoneIDs)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                let records = hm.allValues()
                records.forEach { record in self.addToCache(record: record, entityId: record.id(), type: .workspace) }
                completion(.success(records))
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Save
    
    func saveToCloud(record: CKRecord, entity: Entity, completion: (() -> Void)? = nil) {
        self.saveQueue.enqueue(DeferredSaveModel(record: record, entity: entity, id: entity.getId(), completion: completion))
    }
    
    func saveToCloud(_ models: [DeferredSaveModel]) {
        self.saveQueue.enqueue(models)
    }
    
    /// Saves the given workspace to the cloud
    func saveWorkspaceToCloud(_ ws: EWorkspace) {
        if !ws.isSyncEnabled { return }
        if ws.markForDelete { self.deleteDataMarkedForDelete(ws); return }
        let wsId = ws.getId()
        let zoneID = ws.getZoneID()
        let recordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
        let record = self.ck.createRecord(recordID: recordID, recordType: RecordType.workspace.rawValue)
        ws.updateCKRecord(record)
        let wsModel = DeferredSaveModel(record: record, entity: ws, id: wsId)
        let zoneModel = self.zoneDeferredSaveModel(ws: ws)
        self.saveToCloud([wsModel, zoneModel])
    }
    
    /// Save the given project and updates the associated workspace to the cloud.
    func saveProjectToCloud(_ proj: EProject) {
        guard let ws = proj.workspace else { Log.error("Workspace is empty for project"); return }
        if !ws.isSyncEnabled { return }
        if ws.markForDelete { self.deleteDataMarkedForDelete(ws); return }
        if proj.markForDelete { self.deleteDataMakedForDelete(proj); return }
        let projId = proj.getId()
        let zoneID = proj.getZoneID()
        let recordID = self.ck.recordID(entityId: projId, zoneID: zoneID)
        let ckproj = self.ck.createRecord(recordID: recordID, recordType: RecordType.project.rawValue)
        self.fetchRecord(ws, type: .workspace) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let ckws):
                self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
            case .failure(let error):
                Log.error("Error getting workspace from cloud: \(error)")
                if let err = error as? CKError {
                    if err.isZoneNotFound() {  // => workspace is not created
                        self.ck.createZone(recordZoneId: zoneID) { result in
                            switch result {
                            case .success(_):
                                let wsId = ws.getId()
                                let ckwsID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
                                let ckws = self.ck.createRecord(recordID: ckwsID, recordType: RecordType.workspace.rawValue)
                                ws.updateCKRecord(ckws)
                                self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws, isCreateZoneRecord: true)
                                //self.saveRecords(records, completion: completion)
                            case .failure(let error):
                                Log.error("Error creating zone: \(error)")
                            }
                        }
                    } else if err.isRecordNotFound() {
                        let ckws = self.ck.createRecord(recordID: self.ck.recordID(entityId: ws.getId(), zoneID: ckproj.zoneID()), recordType: RecordType.workspace.rawValue)
                        self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
                    }
                }
            }
        }
    }
    
    /// Save the given request and updates the associated project to the cloud.
    func saveRequestToCloud(_ req: ERequest) {
        guard let proj = req.project, let ws = proj.workspace, ws.isSyncEnabled else { return }
        if proj.markForDelete { self.deleteDataMakedForDelete(proj); return }
        if req.markForDelete { self.deleteDataMarkedForDelete(req); return }
        guard let reqId = req.id else { Log.error("ERequest id is nil"); return }
        let wsId = ws.getId()
        let projId = proj.getId()
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let ckReqID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        let ckreq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
        self.fetchRecord(proj, type: .project) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let ckproj):
                self.saveRequestToCloudImp(ckreq: ckreq, req: req, ckproj: ckproj, proj: proj)
            case .failure(let error):
                Log.error("Error fetching project record: \(error)")
                if let err = error as? CKError {
                    if !err.isRecordExists() {
                        Log.error("Project record does not exist. Retrying with new record.")
                        let projID = self.ck.recordID(entityId: projId, zoneID: zoneID)
                        let ckproj = self.ck.createRecord(recordID: projID, recordType: RecordType.project.rawValue)
                        self.saveRequestToCloudImp(ckreq: ckreq, req: req, ckproj: ckproj, proj: proj)
                    }
                }
            }
        }
    }
    
    func zoneDeferredSaveModel(ws: EWorkspace) -> DeferredSaveModel {
        let wsId = ws.getId()
        let zone = Zone(id: wsId, name: ws.getName(), desc: ws.desc ?? "", isSyncEnabled: ws.isSyncEnabled, created: ws.created, modified: ws.modified, changeTag: ws.changeTag, version: ws.version)
        let recordID = self.ck.recordID(entityId: wsId, zoneID: self.ck.defaultZoneID())
        let ckzn = self.ck.createRecord(recordID: recordID, recordType: RecordType.zone.rawValue)
        zone.updateCKRecord(ckzn)
        return DeferredSaveModel(record: ckzn, id: ws.getId())
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveProjectToCloudImp(ckproj: CKRecord, proj: EProject, ckws: CKRecord, ws: EWorkspace, isCreateZoneRecord: Bool? = false) {
        proj.updateCKRecord(ckproj, workspace: ckws)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let wsModel = DeferredSaveModel(record: ckws, entity: ws, id: ws.getId())
        if let createZoneRecord = isCreateZoneRecord, createZoneRecord {
            self.saveToCloud([projModel, wsModel, self.zoneDeferredSaveModel(ws: ws)])
        } else {
            self.saveToCloud([projModel, wsModel])
        }
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveRequestToCloudImp(ckreq: CKRecord, req: ERequest, ckproj: CKRecord, proj: EProject) {
        var acc: [DeferredSaveModel] = []
        let zoneID = ckreq.zoneID()
        guard let wsId = req.project?.workspace?.getId() else { return }
        req.updateCKRecord(ckreq, project: ckproj)
        //EProject.addRequestReference(to: ckproj, request: ckreq)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let reqModel = DeferredSaveModel(record: ckreq, entity: req, id: req.getId())
        acc.append(contentsOf: [projModel, reqModel])
        if let methods = proj.requestMethods?.allObjects as? [ERequestMethodData], methods.count > 0 {
            methods.forEach { method in
                if method.markForDelete { self.deleteRequestMethodDataMarkedForDelete(req); return}
                if method.isCustom && !method.isSynced {
                    let ckmeth = self.ck.createRecord(recordID: self.ck.recordID(entityId: method.getId(), zoneID: zoneID), recordType: RecordType.requestMethodData.rawValue)
                    method.updateCKRecord(ckmeth, project: ckproj)
                    acc.append(DeferredSaveModel(record: ckmeth, id: ckmeth.id()))
                }
            }
        }
        if let set = req.headers, let xs = set.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                if !reqData.isSynced {
                    let hdrecord = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    reqData.updateCKRecord(hdrecord)
                    ERequestData.addRequestReference(ckreq, toheader: hdrecord)
                    acc.append(DeferredSaveModel(record: hdrecord, id: reqData.getId()))
                }
            }
        }
        if let set = req.params, let xs = set.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.isSynced {
                    if reqData.markForDelete {
                        self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId);
                        return
                    }
                    let paramrecord = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    reqData.updateCKRecord(paramrecord)
                    ERequestData.addRequestReference(ckreq, toParam: paramrecord)
                    acc.append(DeferredSaveModel(record: paramrecord, id: reqData.getId()))
                }
            }
        }
        if let body = req.body {
            if body.markForDelete { self.deleteRequestBodyDataMarkedForDelete(req); return }
            let ckbody = self.ck.createRecord(recordID: self.ck.recordID(entityId: body.getId(), zoneID: zoneID), recordType: RecordType.requestBodyData.rawValue)
            if !body.isSynced {
                body.updateCKRecord(ckbody, request: ckreq)
                acc.append(DeferredSaveModel(record: ckbody, id: ckbody.id()))
            }
            if let binary = body.binary {
                if binary.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                let ckbin = self.ck.createRecord(recordID: self.ck.recordID(entityId: binary.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                if let files = binary.files?.allObjects as? [EFile] {
                    var delxs: [EFile] = []
                    files.forEach { file in
                        if !file.isSynced {
                            if file.markForDelete {
                                delxs.append(file)
                            } else {
                                let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                                file.updateCKRecord(ckfile)
                                EFile.addRequestDataReference(ckfile, reqData: ckbin)
                                acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                            }
                        }
                    }
                    if delxs.count > 0 { self.deleteDataMarkedForDelete(delxs, wsId: wsId) }
                }
                if let image = binary.image, !image.isSynced {
                    if image.markForDelete { self.deleteDataMarkedForDelete(image, wsId: wsId); return }
                    let ckimage = self.ck.createRecord(recordID: self.ck.recordID(entityId: image.getId(), zoneID: zoneID), recordType: RecordType.image.rawValue)
                    image.updateCKRecord(ckimage)
                    EImage.addRequestDataReference(ckbin, image: ckimage)
                    acc.append(DeferredSaveModel(record: ckimage, id: ckimage.id()))
                }
                if !binary.isSynced {
                    binary.updateCKRecord(ckbin)
                    ERequestData.addRequestBodyDataReference(ckbody, toBinary: ckbin)
                    acc.append(DeferredSaveModel(record: ckbin, id: ckbin.id()))
                }
            }
            if let forms = body.form?.allObjects as? [ERequestData] {
                forms.forEach { reqData in
                    if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                    let ckform = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    if !reqData.isSynced {
                        reqData.updateCKRecord(ckform)
                        ERequestData.addRequestBodyDataReference(ckbody, toForm: ckform, type: .form)
                        acc.append(DeferredSaveModel(record: ckform, id: ckform.id()))
                    }
                    if let files = reqData.files?.allObjects as? [EFile] {
                        var delxs: [EFile] = []
                        files.forEach { file in
                            if file.markForDelete { delxs.append(file); return }
                            if !file.isSynced {
                                let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                                file.updateCKRecord(ckfile)
                                EFile.addRequestDataReference(ckfile, reqData: ckform)
                                acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                            }
                        }
                        if delxs.count > 0 { self.deleteDataMarkedForDelete(delxs, wsId: wsId) }
                    }
                    if let image = reqData.image, !image.isSynced {
                        if image.markForDelete { self.deleteDataMarkedForDelete(image, wsId: wsId); return }
                        let ckimage = self.ck.createRecord(recordID: self.ck.recordID(entityId: image.getId(), zoneID: zoneID), recordType: RecordType.image.rawValue)
                        image.updateCKRecord(ckimage)
                        EImage.addRequestDataReference(ckform, image: ckimage)
                        acc.append(DeferredSaveModel(record: ckimage, id: ckimage.id()))
                    }
                }
            }
            if let multipart = body.multipart?.allObjects as? [ERequestData] {
                multipart.forEach { reqData in
                    if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                    if !reqData.isSynced {
                        let ckmpart = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                        reqData.updateCKRecord(ckmpart)
                        ERequestData.addRequestBodyDataReference(ckbody, toForm: ckmpart, type: .multipart)
                        acc.append(DeferredSaveModel(record: ckmpart, id: ckmpart.id()))
                    }
                }
            }
        }
        self.saveToCloud(acc)  // we need to save this in the same request so that the deps are created and referrenced properly.
    }
}
