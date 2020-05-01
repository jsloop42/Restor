//
//  CloudKitService.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

class ZoneInfo: NSObject, NSCoding {
    var zoneID: CKRecordZone.ID
    var serverChangeToken: CKServerChangeToken? = nil
    
    enum CodingKeys: String, CodingKey {
        case zoneID
        case serverChangeToken
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(zoneID.encode(), forKey: CodingKeys.zoneID.rawValue)
        coder.encode(serverChangeToken?.encode(), forKey: CodingKeys.serverChangeToken.rawValue)
    }
    
    required init?(coder: NSCoder) {
        self.zoneID = CKRecordZone.ID.decode(coder.decodeObject(forKey: CodingKeys.zoneID.rawValue) as! Data)!
        if let tokenData = coder.decodeObject(forKey: CodingKeys.serverChangeToken.rawValue) as? Data {
            self.serverChangeToken = CKServerChangeToken.decode(tokenData)
        }
    }
    
    init(zone: CKRecordZone, serverChangeToken: CKServerChangeToken? = nil) {
        self.zoneID = zone.zoneID
        self.serverChangeToken = serverChangeToken
    }
    
    init(zoneID: CKRecordZone.ID, serverChangeToken: CKServerChangeToken? = nil) {
        self.zoneID = zoneID
        self.serverChangeToken = serverChangeToken
    }

    static func decode(_ data: Data) -> ZoneInfo? {
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? ZoneInfo
    }
    
    func encode() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}

class CloudKitService {
    static let shared = CloudKitService()
    let cloudKitContainerId = "iCloud.com.estoapps.ios.restor8"
    private var _privateDatabase: CKDatabase!
    private var _container: CKContainer!
    private let nc = NotificationCenter.default
    private let kvstore = NSUbiquitousKeyValueStore.default
    private let store = UserDefaults.standard
    /// Cloudkit user defaults subscriptions key
    private let subscriptionsKey = "ck-subscriptions"
    /// A dictionary of all zones [String: Data]  // [zone-name: zone-info]
    private let zonesKey = "zones-key"
    private let dbChangeTokenKey = "db-change-token"
    private let defaultZoneName = "_defaultZone"
    private var _defaultZoneID: CKRecordZone.ID!
    /// Number of retry operations currently active. This is used for circuit breaking.
    private var networkRetryOpsCount = 0
    /// Maximum number of retry operations before which circuit breaker trips.
    private var maxRetryOpsCount = 3
    // Retry timers
    struct RetryTimer {
        static var fetchAllZones: EARepeatTimer!
        static var fetchZone: EARepeatTimer!
        static var fetchDatabaseChanges: EARepeatTimer!
        static var fetchZoneChanges: EARepeatTimer!
        static var fetchRecords: EARepeatTimer!
        static var fetchSubscriptions: EARepeatTimer!
        static var queryRecords: EARepeatTimer!
        static var createZone: EARepeatTimer!
        static var createZoneIfNotExist: EARepeatTimer!
        static var createRecord: EARepeatTimer!
        static var saveRecords: EARepeatTimer!
        static var subscribe: EARepeatTimer!
        static var subscribeToDBChanges: EARepeatTimer!
        static var deleteZone: EARepeatTimer!
        static var deleteRecords: EARepeatTimer!
        static var deleteSubscriptions: EARepeatTimer!
        static var deleteAllSubscriptions: EARepeatTimer!
        static let limit = 3
        static let interval = 4.0
    }
    /// Keeps the current server change token for the zone until the changes have synced locally, after which it's persisted in User Defaults.
    private var zoneChangeTokens: [CKRecordZone.ID: [CKServerChangeToken]] = [:]
    private let zoneTokenLock = NSLock()
    struct NotificationKey {
        static let zoneChangesDidSave = Notification.Name("zone-changes-did-save")
        static let zoneIDKey = "zoneID"  // used in notification on save success
    }
    // There could be records fetched, but the zone change completion has not occured yet. If there is an in-activity or of the record count reaches a
    // limit, we call the handler with the partial result.
    private let zoneFetchChangesTimer: DispatchSourceTimer = DispatchSource.makeTimerSource()
    private var zoneFetchChangesTimerState: EATimerState = .undefined
    private let zoneFetchChangesLock = NSLock()
    
    enum PropKey: String {
        case isZoneCreated
        case serverChangeToken
    }
    
    deinit {
        self.nc.removeObserver(self)
        if !self.zoneFetchChangesTimer.isCancelled {
            if self.zoneFetchChangesTimerState == .suspended { self.zoneFetchChangesTimer.resume() }
            self.zoneFetchChangesTimer.cancel()
            self.zoneFetchChangesTimer.setEventHandler(handler: {})
        }
    }
    
    init() {
        if isRunningTests { return }
        self.loadSubscriptions()
        self.nc.addObserver(self, selector: #selector(self.zoneChangesDidSave(_:)), name: NotificationKey.zoneChangesDidSave, object: nil)
        self.zoneFetchChangesTimer.schedule(deadline: .now() + 5, repeating: 8)
    }

    // MARK: - KV Store
    
    func getValue(key: String) -> Any? {
        return self.kvstore.object(forKey: key)
    }
    
    func saveValue(key: String, value: Any) {
        self.kvstore.set(value, forKey: key)
    }
    
    func removeValue(key: String) {
        self.kvstore.removeObject(forKey: key)
    }
    
    func addKVChangeObserver() {
        self.nc.addObserver(self, selector: #selector(self.kvStoreDidChange(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: self.kvstore)
    }
    
    @objc func kvStoreDidChange(_ notif: Notification) {
        Log.debug("CK: kv store did change")
    }
    
    // MARK: - CloudKit setup
    
    /// Return the current iCloud user's full name.
    func currentUsername() -> String {
        return CKCurrentUserDefaultName
    }
    
    /// Returns the custom iCloud container.
    func container() -> CKContainer {
        if self._container == nil { self._container = CKContainer(identifier: self.cloudKitContainerId) }
        return self._container
    }
    
    /// Return user's private iCloud database.
    func privateDatabase() -> CKDatabase {
        if self._privateDatabase == nil { self._privateDatabase = self.container().privateCloudDatabase }
        return self._privateDatabase
    }
    
    // MARK: - Helper methods
    
    /// Invokes the given callback with the iCloud account status.
    func accountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        CKContainer.default().accountStatus { status, error in
            if let err = error { completion(.failure(err)); return }
            completion(.success(status))
        }
    }
    
    /// Returns whether the zone has been created for the given zone ID.
    func isZoneCreated(_ zoneID: CKRecordZone.ID) -> Bool {
        let key = "\(zoneID.zoneName)-created"
        return self.kvstore.bool(forKey: key)
    }
    
    /// Set zone created flag in kv store for the given zone ID.
    func setZoneCreated(_ zoneID: CKRecordZone.ID) {
        let key = "\(zoneID.zoneName)-created"
        self.kvstore.set(true, forKey: key)
    }
    
    /// Removes the zone created flag from kv store for the given zone ID.
    func removeZoneCreated(_ zoneID: CKRecordZone.ID) {
        let key = "\(zoneID.zoneName)-created"
        self.kvstore.removeObject(forKey: key)
    }
    
    /// Returns a zone ID with the given name.
    func zoneID(with name: String) -> CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: name, ownerName: self.currentUsername())
    }
    
    /// Returns a zone ID for the given workspace id.
    func zoneID(workspaceId: String) -> CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: "\(workspaceId)", ownerName: self.currentUsername())
    }
    
    /// Returns zone ID from the given subscription ID.
    func zoneID(subscriptionID: CKSubscription.ID) -> CKRecordZone.ID {
        return self.zoneID(with: subscriptionID.components(separatedBy: ".").last ?? "")
    }
    
    func defaultZoneID() -> CKRecordZone.ID {
        if self._defaultZoneID == nil { self._defaultZoneID = CKRecordZone.ID(zoneName: self.defaultZoneName, ownerName: self.currentUsername()) }
        return self._defaultZoneID
    }
    
    /// Returns the record ID for the given entity id.
    func recordID(entityId: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        return CKRecord.ID(recordName: "\(entityId).\(zoneID.zoneName)", zoneID: zoneID)
    }
    
    /// Returns record IDs from the give zone IDs. Used only for top level objects where zoneID and record matches.
    func recordIDs(zones: [CKRecordZone]) -> [CKRecord.ID] {
        return zones.map { self.recordID(entityId: self.entityID(zoneID: $0.zoneID), zoneID: $0.zoneID) }
    }
    
    func recordIDs(zoneIDs: [CKRecordZone.ID]) -> [CKRecord.ID] {
        return zoneIDs.map { self.recordID(entityId: self.entityID(zoneID: $0), zoneID: $0) }
    }
    
    /// Returns the entity id for the given record ID.
    func entityID(recordID: CKRecord.ID) -> String {
        return recordID.recordName.components(separatedBy: ".").first ?? ""
    }
    
    /// Returns the entity id for the given zone ID.
    func entityID(zoneID: CKRecordZone.ID) -> String {
        return zoneID.zoneName.components(separatedBy: ".").first ?? ""
    }
    
    func entityIDs(zoneIDs: [CKRecordZone.ID]) -> [String] {
        return zoneIDs.map { self.entityID(zoneID: $0) }
    }
    
    func subscriptionID(_ id: String, zoneID: CKRecordZone.ID) -> CKSubscription.ID {
        return CKSubscription.ID(format: "%@.%@", id, zoneID.zoneName)
    }
    
    /// Should retry the operation in case of network failure.
    func canRetry() -> Bool {
        return self.networkRetryOpsCount < self.maxRetryOpsCount
    }
    
    // MARK: - Database change token cache
    
    func getDBChangeToken() -> CKServerChangeToken? {
        guard let data = self.store.data(forKey: self.dbChangeTokenKey) else { return nil }
        return CKServerChangeToken.decode(data)
    }
    
    func setDBChangeToken(_ token: CKServerChangeToken?) {
        guard let token = token else { self.removeDBChangeToken(); return }
        if let data = token.encode() { self.store.set(data, forKey: self.dbChangeTokenKey) }
    }
    
    func removeDBChangeToken() {
        self.store.removeObject(forKey: self.dbChangeTokenKey)
    }
    
    // MARK: - Local Zone Records
    
    func getCachedZones() -> [String: Data] {
        return self.store.dictionary(forKey: self.zonesKey) as? [String: Data] ?? [:]
    }
    
    func setCachedZones(_ hm: [String: Data]) {
        self.store.set(hm, forKey: self.zonesKey)
    }
    
    func addToCachedZones(_ zone: CKRecordZone) {
        var zones = self.getCachedZones()
        let key = zone.zoneID.zoneName
        if zones[key] == nil {
            zones[key] = ZoneInfo(zone: zone).encode()
            self.setCachedZones(zones)
        }
    }
    
    func addServerChangeTokenToCache(_ token: CKServerChangeToken, zoneID: CKRecordZone.ID, persist: Bool? = false) {
        if persist == nil || persist! {
            var zones = self.getCachedZones()
            let key = zoneID.zoneName
            let data = zones[key]
            let info: ZoneInfo = (data != nil ? ZoneInfo.decode(data!) : ZoneInfo(zoneID: zoneID)) ?? ZoneInfo(zoneID: zoneID)
            info.serverChangeToken = token
            zones[key] = info.encode()
            self.setCachedZones(zones)
        } else {  // keep in mem
            self.zoneTokenLock.lock()
            var xs = self.zoneChangeTokens[zoneID] ?? []
            if xs.isEmpty || !xs.contains(token) {
                xs.append(token)
                self.zoneChangeTokens[zoneID] = xs
                Log.debug("change token count: \(zoneID.zoneName) - \(xs.count)")
            }
            self.zoneTokenLock.unlock()
        }
    }
    
    @objc func zoneChangesDidSave(_ notif: Notification) {
        Log.debug("CK: zone changes did save notif.")
        EACommon.backgroundQueue.async {
            self.zoneTokenLock.lock()
            if let info = notif.userInfo, let zoneID = info[NotificationKey.zoneIDKey] as? CKRecordZone.ID, var tokens = self.zoneChangeTokens[zoneID] {
                if tokens.isEmpty { self.zoneChangeTokens.removeValue(forKey: zoneID); return }
                let token = tokens.remove(at: 0)
                self.addServerChangeTokenToCache(token, zoneID: zoneID, persist: true)
                Log.debug("CK: zone change token persisted: \(zoneID.zoneName) - \(token)")
            }
            self.zoneTokenLock.unlock()
        }
    }
    
    func containsCachedZoneID(_ zoneID: CKRecordZone.ID) -> Bool {
        return self.getCachedZones()[zoneID.zoneName] != nil
    }
    
    func getCachedServerChangeToken(_ zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        let zones = self.getCachedZones()
        if let data = zones[zoneID.zoneName], let zinfo = ZoneInfo.decode(data) { return zinfo.serverChangeToken }
        return nil
    }
    
    func getZonesIDNotInLocal(_ remote: [String: ZoneInfo]) -> [CKRecordZone.ID] {
        let zones = self.getCachedZones()
        var acc: [CKRecordZone.ID] = []
        remote.forEach { kv in
            if zones[kv.key] == nil { acc.append(kv.value.zoneID) }
        }
        return acc
    }
    
    func removeFromCachedZones(_ zoneID: CKRecordZone.ID) {
        var zones = self.getCachedZones()
        zones.removeValue(forKey: zoneID.zoneName)
        self.setCachedZones(zones)
    }
    
    func removeFromCachesZones(_ zoneIDs: [CKRecordZone.ID]) {
        var zones = self.getCachedZones()
        zoneIDs.forEach { zID in zones.removeValue(forKey: zID.zoneName) }
        self.setCachedZones(zones)
    }
    
    // MARK: - Subscription Local Cache
    
    func getCachedSubscriptions() -> [CKSubscription.ID] {
        return self.store.array(forKey: self.subscriptionsKey) as? [CKSubscription.ID] ?? []
    }
    
    func containsCachedSubscription(_ subID: CKSubscription.ID) -> Bool {
        let xs = self.getCachedSubscriptions()
        return xs.contains(subID)
    }
    
    func addToCachedSubscriptions(_ subID: CKSubscription.ID) {
        var xs = self.getCachedSubscriptions()
        if !xs.contains(subID) {
            xs.append(subID)
            self.setCachedSubscriptions(xs)
        }
    }
    
    func addToCachedSubscriptions(_ subIDs: [CKSubscription.ID]) {
        var xs = self.getCachedSubscriptions()
        let count = xs.count
        subIDs.forEach { subID in
            if !xs.contains(subID) { xs.append(subID) }
        }
        if xs.count > count { self.setCachedSubscriptions(xs) }
    }
    
    func setCachedSubscriptions(_ xs: [CKSubscription.ID]) {
        self.store.set(xs, forKey: self.subscriptionsKey)
    }
    
    func removeCachedSubscription(_ subID: CKSubscription.ID) {
        var xs = self.getCachedSubscriptions()
        if let idx = xs.firstIndex(of: subID) {
            xs.remove(at: idx)
            self.setCachedSubscriptions(xs)
        }
    }
    
    /// Handles remote iCloud notifications
//    func handleNotification(zoneID: CKRecordZone.ID) {
//        Log.debug("CK: handle notification: \(zoneID)")
//        var changeToken: CKServerChangeToken? = nil
//        if let changeTokenData = self.store.data(forKey: PropKey.serverChangeToken.rawValue) {
//            changeToken = NSKeyedUnarchiver.unarchiveObject(with: changeTokenData) as? CKServerChangeToken
//        }
//        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
//        options.previousServerChangeToken = changeToken
//        let optionsMap = [zoneID: options]
//        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], optionsByRecordZoneID: optionsMap)
//        op.fetchAllChanges = true
//        op.qualityOfService = .utility
//        op.recordChangedBlock = { record in
//            Log.debug("CK: record changed: \(record)")
//            PersistenceService.shared.cloudRecordDidChange(record)
//        }
//        op.recordZoneChangeTokensUpdatedBlock = { [unowned self] zoneID, changeToken, data in
//            guard let changeToken = changeToken else { return }
//            Log.debug("CK: record zone change tokens updated")
//            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
//            self.store.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
//        }
//        op.recordZoneFetchCompletionBlock = { [unowned self] zoneID, changeToken, data, more, error in
//            guard error == nil else { return }
//            guard let changeToken = changeToken else { return }
//            Log.debug("CK: record zone fetch completion")
//            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
//            self.store.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
//        }
//        op.fetchRecordZoneChangesCompletionBlock = {error in
//            guard error == nil else { return }
//            Log.debug("CK: fetch record zone changes completion")
//        }
//        self.privateDatabase().add(op)
//    }
    
    /// Fetches all subscriptions from cloud and updates user defaults.
    func loadSubscriptions() {
        self.fetchSubscriptions { [unowned self] result in
            switch result {
            case .success(let xs):
                let subIds: [CKSubscription.ID] = xs.map { $0.subscriptionID }
                self.addToCachedSubscriptions(subIds)
            case .failure(let err):
                Log.error("CK: Error fetching subscriptions: \(err)")
                break
            }
        }
    }
    
    /// Returns if a subscription had been made for the given subscription id.
    func isSubscribed(to subId: CKSubscription.ID) -> Bool {
        return self.containsCachedSubscription(subId)
    }
    
    // MARK: - Fetch
    
    func fetchAllZones(completion: @escaping (Result<(all: [CKRecordZone], new: [CKRecordZone.ID]), Error>) -> Void) {
        Log.debug("CK: fetch all zones")
        self.privateDatabase().fetchAllRecordZones { [unowned self] zones, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.fetchAllZones == nil && self.canRetry() {
                        RetryTimer.fetchAllZones = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchAllZones(completion: completion)
                                RetryTimer.fetchAllZones.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchAllZones.resume()
                        RetryTimer.fetchAllZones.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.fetchAllZones.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            if RetryTimer.fetchAllZones != nil { RetryTimer.fetchAllZones.stop(); RetryTimer.fetchAllZones = nil }
            if let xs = zones {
                var hm: [String: ZoneInfo] = [:]
                var hme: [String: Data] = [:]
                xs.forEach { zone in
                    if zone.zoneID.zoneName != "_defaultZone" {
                        let zinfo = ZoneInfo(zone: zone)
                        let key = zone.zoneID.zoneName
                        hm[key] = zinfo
                        hme[key] = zinfo.encode()
                    }
                }
                Log.debug("CK: fetched zone: \(hm.count)")
                if hm.count > 0 {
                    let new = self.getZonesIDNotInLocal(hm)
                    self.setCachedZones(hme)
                    completion(.success((all: xs, new: new)))
                    return
                }
            }
            self.setCachedZones([:])
            completion(.success((all: [], new: [])))
        }
    }
    
    /// Fetch the given zones.
    func fetchZone(recordZoneIDs: [CKRecordZone.ID], completion: @escaping (Result<[CKRecordZone.ID: CKRecordZone], Error>) -> Void) {
        Log.debug("CK: fetch zone: \(recordZoneIDs)")
        let op = CKFetchRecordZonesOperation(recordZoneIDs: recordZoneIDs)
        op.qualityOfService = .utility
        op.fetchRecordZonesCompletionBlock = { res, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.fetchZone == nil && self.canRetry() {
                        RetryTimer.fetchZone = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchZone(recordZoneIDs: recordZoneIDs, completion: completion)
                                RetryTimer.fetchZone.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchZone.resume()
                        RetryTimer.fetchZone.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.fetchZone.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            if let hm = res { completion(.success(hm)) }
        }
        self.privateDatabase().add(op)
    }
    
    func fetchDatabaseChanges() {
        Log.debug("CK: fetch database changes")
        var zonesChanged: [CKRecordZone.ID] = []
        var zonesDeleted: [CKRecordZone.ID] = []
        let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.getDBChangeToken())
        op.changeTokenUpdatedBlock = { token in
            self.setDBChangeToken(token)
        }
        op.recordZoneWithIDChangedBlock = { zoneID in
            zonesChanged.append(zoneID)
        }
        op.recordZoneWithIDWasPurgedBlock = { zoneID in
            zonesDeleted.append(zoneID)
        }
        op.recordZoneWithIDWasDeletedBlock = { zoneID in
            zonesDeleted.append(zoneID)
        }
        op.fetchDatabaseChangesCompletionBlock = { [unowned self] token, moreComing, error in
            if let err = error as? CKError {
                Log.error("CK: Error fetching database changes: \(err)")
                if err.isNetworkFailure() {
                    if RetryTimer.fetchDatabaseChanges == nil && self.canRetry() {
                        RetryTimer.fetchDatabaseChanges = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchDatabaseChanges()
                                RetryTimer.fetchAllZones.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchDatabaseChanges.resume()
                        RetryTimer.fetchDatabaseChanges.done = {
                            Log.error("CK: Error reaching CloudKit server")
                        }
                    } else {
                        RetryTimer.fetchDatabaseChanges.resume()
                    }
                }
                return
            }
            self.setDBChangeToken(token)
            if moreComing { self.fetchDatabaseChanges() }
        }
        self.privateDatabase().add(op)
    }
    
    struct ZoneChangeResult {
        var zoneID: CKRecordZone.ID!
        var saved: [CKRecord] = []
        var deleted: [CKRecord.ID] = []
        var isBatched: Bool = true
        
        init(zoneID: CKRecordZone.ID) {
            self.zoneID = zoneID
        }
        
        init() {}
    }
    
    func fetchZoneChanges(zoneIDs: [CKRecordZone.ID], handler: ((Result<(ZoneChangeResult, Bool), Error>) -> Void)? = nil) {
        Log.debug("CK: fetch zone changes: \(zoneIDs.map(\.zoneName))")
        var moreZones: [CKRecordZone.ID] = []
        var zoneChangeResults: [CKRecordZone.ID: ZoneChangeResult] = [:]
        var count = zoneIDs.count
        var isHandlerInvoked = false
        let handleError: (Error) -> Void = { error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.fetchZoneChanges == nil && self.canRetry() {
                        RetryTimer.fetchZoneChanges = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchZoneChanges(zoneIDs: zoneIDs, handler: handler)
                                RetryTimer.fetchZoneChanges.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchZoneChanges.resume()
                        RetryTimer.fetchZoneChanges.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            handler?(.failure(err))
                            return
                        }
                    } else {
                        RetryTimer.fetchZoneChanges.resume()
                    }
                } else {
                    handler?(.failure(err)); return
                }
            }
        }
        let op: CKFetchRecordZoneChangesOperation!
        if #available(iOS 12.0, *) {
            var zoneOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] = [:]
            zoneIDs.forEach { zID in
                let token: CKServerChangeToken? = self.getCachedServerChangeToken(zID)
                Log.debug("CK: zone change token for zone: \(zID.zoneName) - \(String(describing: token))")
                let opt = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                opt.previousServerChangeToken = token
                zoneOptions[zID] = opt
            }
            op = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: zoneOptions)
        } else {
            var zoneOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] = [:]
            zoneIDs.forEach { zID in
                let token: CKServerChangeToken? = self.getCachedServerChangeToken(zID)
                Log.debug("CK: zone change token for zone: \(zID.zoneName) - \(String(describing: token))")
                let opt = CKFetchRecordZoneChangesOperation.ZoneOptions()
                opt.previousServerChangeToken = token
                zoneOptions[zID] = opt
            }
            op = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: zoneOptions)
        }
        op.recordZoneIDs = zoneIDs
        op.qualityOfService = .utility
        let destroyTimer: () -> Void = {
            Log.debug("remaining zone fetches count: \(count)")
            if count <= 0 && zoneChangeResults.isEmpty && self.zoneFetchChangesTimerState != .suspended {
                Log.debug("zone change timer suspended")
                self.zoneFetchChangesTimer.suspend()
                self.zoneFetchChangesTimerState = .suspended
            }
        }
        let process: () -> Void = {
            self.zoneFetchChangesLock.lock()
            if isHandlerInvoked && count <= 0 && zoneChangeResults.isEmpty { return }
            let xs = zoneChangeResults.allValues()
            if xs.isEmpty {
                handler?(.success((ZoneChangeResult(), true)))
                isHandlerInvoked = true
            } else {
                xs.forEach { result in
                    if !result.saved.isEmpty || !result.deleted.isEmpty {
                        handler?(.success((result, count <= 0)))
                        isHandlerInvoked = true
                        zoneChangeResults.removeValue(forKey: result.zoneID)
                    }
                }
            }
            self.zoneFetchChangesLock.unlock()
            destroyTimer()
        }
        let initTimer: () -> Void = {
            if self.zoneFetchChangesTimerState == .undefined {
                self.zoneFetchChangesTimer.setEventHandler(handler: { process() })
                self.zoneFetchChangesTimerState = .suspended
            }
            if self.zoneFetchChangesTimerState == .suspended && count > 0 {
                self.zoneFetchChangesTimer.resume()
                self.zoneFetchChangesTimerState = .resumed
            }
        }
        initTimer()
        op.recordChangedBlock = { record in
            Log.debug("CK: zone change: record obtained: \(record)")
            self.zoneFetchChangesLock.lock()
            let zoneID = record.zoneID()
            var result = zoneChangeResults[zoneID] ?? ZoneChangeResult(zoneID: zoneID)
            result.saved.append(record)
            zoneChangeResults[zoneID] = result
            self.zoneFetchChangesLock.unlock()
            initTimer()
        }
        op.recordWithIDWasDeletedBlock = { recordID, _ in
            Log.debug("CK: zone change: record ID deleted: \(recordID)")
            self.zoneFetchChangesLock.lock()
            let zoneID = recordID.zoneID
            var result = zoneChangeResults[zoneID] ?? ZoneChangeResult(zoneID: zoneID)
            result.deleted.append(recordID)
            zoneChangeResults[zoneID] = result
            self.zoneFetchChangesLock.unlock()
            initTimer()
        }
        op.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, _ in
            Log.debug("CK: zone change token update for: \(zoneID) - \(String(describing: changeToken))")
            if let token = changeToken { self.addServerChangeTokenToCache(token, zoneID: zoneID) }
        }
        op.recordZoneFetchCompletionBlock = { [unowned self] zoneID, changeToken, _, moreComing, error in
            Log.debug("CK: zone fetch complete: \(zoneID.zoneName)")
            if let err = error {
                Log.error("CK: Error fetching changes for zone: \(err)")
                handleError(err)
                return;
            }
            if let token = changeToken { self.addServerChangeTokenToCache(token, zoneID: zoneID) }
            if moreComing { moreZones.append(zoneID) }
            process()
        }
        op.fetchRecordZoneChangesCompletionBlock = { [unowned self] error in
            Log.debug("CK: all zone changes fetch complete")
            if let err = error {
                Log.error("CK: Error fetching zone changes: \(err)");
                handleError(err)
                return;
            }
            Log.debug("CK: Fetch zone changes complete")
            count -= 1
            if moreZones.count > 0 { self.fetchZoneChanges(zoneIDs: moreZones, handler: handler) }
        }
        self.privateDatabase().add(op)
    }
    
    /// Fetch the given records.
    func fetchRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord.ID: CKRecord], Error>) -> Void) {
        Log.debug("CK: fetch records: \(recordIDs)")
        let op = CKFetchRecordsOperation(recordIDs: recordIDs)
        op.qualityOfService = .utility
        op.fetchRecordsCompletionBlock = { res, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.fetchRecords == nil && self.canRetry() {
                        RetryTimer.fetchRecords = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchRecords(recordIDs: recordIDs, completion: completion)
                                RetryTimer.fetchRecords.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchRecords.resume()
                        RetryTimer.fetchRecords.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.fetchRecords.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            if let hm = res { completion(.success(hm)) }
        }
        self.privateDatabase().add(op)
    }
    
    func fetchSubscriptions(completion: @escaping (Result<[CKSubscription], Error>) -> Void) {
        Log.debug("CK: fetch subscriptions")
        self.privateDatabase().fetchAllSubscriptions { subscriptions, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.fetchSubscriptions == nil && self.canRetry() {
                        RetryTimer.fetchSubscriptions = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.fetchSubscriptions(completion: completion)
                                RetryTimer.fetchSubscriptions.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchSubscriptions.resume()
                        RetryTimer.fetchSubscriptions.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.fetchSubscriptions.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            completion(.success(subscriptions ?? []))
        }
    }
    
    // MARK: - Query
    
    func queryRecords(zoneID: CKRecordZone.ID, recordType: String, predicate: NSPredicate, cursor: CKQueryOperation.Cursor? = nil, limit: Int? = nil,
                      completion: @escaping (Result<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>) -> Void) {
        Log.debug("CK: Query records: zoneID: \(zoneID), recordType: \(recordType)")
        var records: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let op = CKQueryOperation(query: query)
        op.cursor = cursor
        if let x = limit, x > 0 { op.resultsLimit = x }
        op.zoneID = zoneID
        op.recordFetchedBlock = { record in
            records.append(record)
        }
        op.queryCompletionBlock = { cursor, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if self.canRetry() {
                        if RetryTimer.queryRecords == nil {
                            RetryTimer.queryRecords = EARepeatTimer(block: {
                                if Reachability.isConnectedToNetwork() {
                                    self.queryRecords(zoneID: zoneID, recordType: recordType, predicate: predicate, cursor: cursor, limit: limit, completion: completion)
                                    RetryTimer.queryRecords.suspend()
                                }
                            }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                            RetryTimer.queryRecords.done = {
                                Log.error("CK: Error reaching CloudKit server")
                                completion(.failure(err)); return
                            }
                            RetryTimer.queryRecords.resume()
                            return
                        }
                        RetryTimer.queryRecords.resume()
                        return
                    }
                }
                completion(.failure(err)); return
            }
            completion(.success((records: records, cursor: cursor)))
        }
        self.privateDatabase().add(op)
    }
    
    // MARK: - Create
    
    /// Create zone with the given zone Id.
    func createZone(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone.ID, Error>) -> Void) {
        Log.debug("CK: create zone: \(recordZoneId)")
        let z = CKRecordZone(zoneID: recordZoneId)
        if self.containsCachedZoneID(recordZoneId) { completion(.success(recordZoneId)); return }
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [z], recordZoneIDsToDelete: [])
        op.modifyRecordZonesCompletionBlock = { [unowned self] zones, _, error in
            if let err = error as? CKError {
                Log.error("CK: Error saving zone: \(err)")
                if err.isNetworkFailure() {
                    if RetryTimer.createZone == nil && self.canRetry() {
                        RetryTimer.createZone = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.createZone(recordZoneId: recordZoneId, completion: completion)
                                RetryTimer.createZone.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.createZone.resume()
                        RetryTimer.createZone.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.createZone.resume()
                    }
                } else {
                    completion(.failure(err)); return
                }
            }
            if let x = zones?.first {
                Log.debug("CK: Zone created successfully: \(x.zoneID.zoneName)")
                self.addToCachedZones(x)
                completion(.success(recordZoneId))
            } else {
                Log.error("CK: Error creating zone. Zone is empty.")
                completion(.failure(AppError.create))
            }
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    /// Create zone if not created already.
    func createZoneIfNotExist(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone.ID, Error>) -> Void) {
        Log.debug("CK: create zone if not exist: \(recordZoneId)")
        self.fetchZone(recordZoneIDs: [recordZoneId], completion: { [unowned self] result in
            switch result {
            case .success(let hm):
                if let zone = hm[recordZoneId] {
                    self.addToCachedZones(zone)
                    completion(.success(zone.zoneID))
                } else {
                    completion(.failure(AppError.error))
                }
            case .failure(let error):
                if let err = error as? CKError {
                    if err.isZoneNotFound() {
                        self.createZone(recordZoneId: recordZoneId) { result in
                            switch result {
                            case .success(let zoneID):
                                completion(.success(zoneID))
                            case .failure(let err):
                                completion(.failure(err))
                            }
                        }
                    } else if err.isNetworkFailure() {
                        if RetryTimer.createZoneIfNotExist == nil && self.canRetry() {
                            RetryTimer.createZoneIfNotExist = EARepeatTimer(block: {
                                if Reachability.isConnectedToNetwork() {
                                    self.createZoneIfNotExist(recordZoneId: recordZoneId, completion: completion)
                                    RetryTimer.fetchZone.suspend()
                                }
                            }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                            RetryTimer.createZoneIfNotExist.resume()
                            RetryTimer.createZoneIfNotExist.done = {
                                Log.error("CK: Error reaching CloudKit server")
                                completion(.failure(err)); return
                            }
                        } else {
                            RetryTimer.createZoneIfNotExist.resume()
                        }
                    } else {
                        completion(.failure(err)); return
                    }
                }
            }
        })
    }
    
    /// Creates a record with the given ID and type
    func createRecord(recordID: CKRecord.ID, recordType: String) -> CKRecord {
        return CKRecord(recordType: recordType, recordID: recordID)
    }
    
    // MARK - Save
    
    /// Saves the given record. If the record does not exists, then creates a new one, else updates the existing one after conflict resolution.
    func saveRecords(_ records: [CKRecord], count: Int? = 0, isForce: Bool? = false, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("CK: Save records: \(records.map{ $0.recordID.recordName })")
        guard !records.isEmpty else { completion(.success([])); return }
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        var saved: [CKRecord] = []
        let lock = NSLock()
        op.qualityOfService = .utility
        if isForce! { op.savePolicy = .changedKeys }
        let handleError: (Error?) -> Void = { error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.saveRecords == nil && self.canRetry() {
                        RetryTimer.saveRecords = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.saveRecords(records, count: count, isForce: isForce, completion: completion)
                                RetryTimer.saveRecords.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.saveRecords.resume()
                        RetryTimer.saveRecords.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.saveRecords.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
        }
        op.perRecordCompletionBlock = { record, error in
            handleError(error)
            lock.lock()
            saved.append(record)
            lock.unlock()
        }
        op.modifyRecordsCompletionBlock = { [unowned self] _, _, error in
            guard error == nil else {
                guard let ckerror = error as? CKError else { completion(.failure(error!)); return }
                if ckerror.isZoneNotFound() {  // Zone not found, create one
                    self.createZone(recordZoneId: records.first!.recordID.zoneID) { result in
                        switch result {
                        case .success(_):
                            self.saveRecords(records, completion: completion)
                        case .failure(let error):
                            completion(.failure(error)); return
                        }
                    }
                } else if ckerror.isRecordExists() {
                    Log.error("CK: Error saving record. Record already exists.")
                    if count! >= 2 { completion(.failure(ckerror)); return }  // Tried three time.
                    // Merge in the changes, save the new record
                    let (local, server) = ckerror.getMergeRecords()
                    if let merged = PersistenceService.shared.mergeRecords(local: local, server: server, recordType: local?.recordType ?? "") {
                        var xs: [CKRecord] = records.filter { record -> Bool in record.recordID != merged.recordID }
                        xs.append(merged)
                        self.saveRecords(xs, count: count! + 1, isForce: true, completion: completion)
                    } else {
                        completion(.failure(ckerror))
                    }
                } else {
                    handleError(ckerror)
                }
                return
            }
            Log.debug("CK: Records saved successfully: \(records.map { r -> String in r.recordID.recordName })")
            completion(.success(saved))
        }
        self.privateDatabase().add(op)
    }
    
    /// Returns zone name from the given subscription ID.
    func getZoneNameFromSubscriptionID(_ subID: CKSubscription.ID) -> String {
        let name = subID.description
        let xs = name.components(separatedBy: ".")
        return xs.last ?? ""
    }
    
    /// Subscribe to an record change event if not already subscribed.
    /// - Parameters:
    ///   - subId: A subscription key to identify the subscription, which includes the zone ID as well.
    ///   - recordType: The record type.
    ///   - zoneID: The zone ID of the record.
    func subscribe(_ subId: String, recordType: String, zoneID: CKRecordZone.ID) {
        Log.debug("CK: Subscribe: \(subId), recordType: \(recordType), zoneID: \(zoneID)")
        if isSubscribed(to: subId) { return }
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subId,
                                               options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion,
                                                         CKQuerySubscription.Options.firesOnRecordUpdate])
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { [unowned self] _, _, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.subscribe == nil && self.canRetry() {
                        RetryTimer.subscribe = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.subscribe(subId, recordType: recordType, zoneID: zoneID)
                                RetryTimer.fetchAllZones.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.fetchAllZones.resume()
                        RetryTimer.fetchAllZones.done = {
                            Log.error("CK: Error reaching CloudKit server")
                        }
                    } else {
                        RetryTimer.fetchAllZones.resume()
                    }
                }
                return
            }
            self.addToCachedSubscriptions(subId)
            Log.debug("CK: Subscribed to events successfully: \(recordType) with ID: \(subscription.subscriptionID.description)")
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    func subscribeToDBChanges(subId: String) {
        Log.debug("CK: Subscribe to DB changes: \(subId)")
        if isSubscribed(to: subId) { return }
        let sub = CKDatabaseSubscription(subscriptionID: subId)
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        sub.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { [unowned self] _, _, error in
            if let err = error as? CKError {
                if err.isNetworkFailure() {
                    if RetryTimer.subscribeToDBChanges == nil && self.canRetry() {
                        RetryTimer.subscribeToDBChanges = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.subscribeToDBChanges(subId: subId)
                                RetryTimer.subscribeToDBChanges.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.subscribeToDBChanges.resume()
                        RetryTimer.subscribeToDBChanges.done = {
                            Log.error("CK: Error reaching CloudKit server")
                        }
                    } else {
                        RetryTimer.subscribeToDBChanges.resume()
                    }
                    return
                }
                return
            }
            self.addToCachedSubscriptions(subId)
            Log.debug("CK: Subscribed to database change event: \(subId)")
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    // MARK: - Delete
    
    /// Delete zone with the given zone ID.
    func deleteZone(recordZoneIds: [CKRecordZone.ID], completion: @escaping (Result<Bool, Error>) -> Void) {
        Log.debug("CK: Delete zone: \(recordZoneIds)")
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [], recordZoneIDsToDelete: recordZoneIds)
        op.modifyRecordZonesCompletionBlock = { [unowned self] _, _, error in
            if let err = error as? CKError {
                Log.error("Error deleting zone: \(err)")
                if err.isNetworkFailure() {
                    if RetryTimer.deleteZone == nil && self.canRetry() {
                        RetryTimer.deleteZone = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.deleteZone(recordZoneIds: recordZoneIds, completion: completion)
                                RetryTimer.deleteZone.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.deleteZone.resume()
                        RetryTimer.deleteZone.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.deleteZone.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            Log.debug("CK: Zone deleted successfully: \(recordZoneIds.map { r -> String in r.zoneName })")
            self.removeFromCachesZones(recordZoneIds)
            completion(.success(true))
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    /// Delete records with the given record IDs. Invokes the callback with the deleted record IDs.
    func deleteRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord.ID], Error>) -> Void) {
        Log.debug("CK: Delete records: \(recordIDs)")
        let op = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: recordIDs)
        op.qualityOfService = .utility
        op.modifyRecordsCompletionBlock = { _, deleted, error in
            if let err = error as? CKError {
                Log.error("CK: Error deleteing records: \(err)")
                if err.isNetworkFailure() {
                    if RetryTimer.deleteRecords == nil && self.canRetry() {
                        RetryTimer.deleteRecords = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.deleteRecords(recordIDs: recordIDs, completion: completion)
                                RetryTimer.deleteRecords.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.deleteRecords.resume()
                        RetryTimer.deleteRecords.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.deleteRecords.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            Log.debug("CK: Records deleted successfully: \(recordIDs.map { r -> String in r.recordName })")
            completion(.success(deleted ?? []))
        }
        self.privateDatabase().add(op)
    }
    
    /// Delete subscription with the given subscription ID.
    func deleteSubscriptions(subscriptionIDs: [CKSubscription.ID], completion: @escaping (Result<[CKSubscription.ID], Error>) -> Void) {
        Log.debug("CK: Delete subscriptions: \(subscriptionIDs)")
        let op = CKModifySubscriptionsOperation.init(subscriptionsToSave: [], subscriptionIDsToDelete: subscriptionIDs)
        op.qualityOfService = .utility
        op.modifySubscriptionsCompletionBlock = { _, ids, error in
            if let err = error as? CKError {
                Log.error("CK: Error deleting subscriptions: \(err)")
                if err.isNetworkFailure() {
                    if RetryTimer.deleteSubscriptions == nil && self.canRetry() {
                        RetryTimer.deleteSubscriptions = EARepeatTimer(block: {
                            if Reachability.isConnectedToNetwork() {
                                self.deleteSubscriptions(subscriptionIDs: subscriptionIDs, completion: completion)
                                RetryTimer.deleteSubscriptions.suspend()
                            }
                        }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                        RetryTimer.deleteSubscriptions.resume()
                        RetryTimer.deleteSubscriptions.done = {
                            Log.error("CK: Error reaching CloudKit server")
                            completion(.failure(err)); return
                        }
                    } else {
                        RetryTimer.deleteSubscriptions.resume()
                    }
                    return
                } else {
                    completion(.failure(err)); return
                }
            }
            guard let xs = ids else { completion(.failure(AppError.delete)); return }
            Log.debug("CK: Subscriptions deleted successfully: \(xs)")
            completion(.success(xs))
        }
        self.privateDatabase().add(op)
    }
    
    func deleteAllSubscriptions() {
        Log.debug("CK: Delete all subscriptions")
        self.fetchSubscriptions { result in
            switch result {
            case .success(let subs):
                self.deleteSubscriptions(subscriptionIDs: subs.map { $0.subscriptionID }) { result in
                    switch result {
                    case .success(let ids):
                        let xs = UserDefaults.standard.array(forKey: self.subscriptionsKey) as? [CKSubscription.ID] ?? []
                        let diff = EAUtils.shared.subtract(lxs: xs, rxs: ids)  // not deleted subscriptions
                        UserDefaults.standard.set(diff, forKey: self.subscriptionsKey)
                    case .failure(let error):
                        Log.error("CK: Error deleting subscriptions: \(error)")
                        if let err = error as? CKError {
                            if err.isNetworkFailure() {
                                if RetryTimer.deleteAllSubscriptions == nil && self.canRetry() {
                                    RetryTimer.deleteAllSubscriptions = EARepeatTimer(block: {
                                        if Reachability.isConnectedToNetwork() {
                                            self.deleteAllSubscriptions()
                                            RetryTimer.fetchAllZones.suspend()
                                        }
                                    }, interval: RetryTimer.interval, limit: RetryTimer.limit)
                                    RetryTimer.deleteAllSubscriptions.resume()
                                    RetryTimer.deleteAllSubscriptions.done = {
                                        Log.error("CK: Error reaching CloudKit server")
                                    }
                                } else {
                                    RetryTimer.deleteAllSubscriptions.resume()
                                }
                                return
                            }
                        }
                    }
                }
            case .failure(let err):
                Log.error("CK: Error fetching subscriptions: \(err)")
                break
            }
        }
    }
}

extension CKError {
    public func isRecordNotFound() -> Bool {
        return self.isZoneNotFound() || self.isUnknownItem()
    }
    
    /// If a record already exists or a newer version of the record already exists.
    public func isRecordExists() -> Bool {
        return self.isSpecificErrorCode(code: .serverRecordChanged)
    }
    
    public func isZoneNotFound() -> Bool {
        return self.isSpecificErrorCode(code: .zoneNotFound)
    }
    
    public func isUnknownItem() -> Bool {
        return self.isSpecificErrorCode(code: .unknownItem)
    }
    
    public func isConflict() -> Bool {
        return self.isSpecificErrorCode(code: .serverRecordChanged)
    }
    
    public func isNetworkFailure() -> Bool {
        return self.isSpecificErrorCode(code: .networkFailure) || self.isSpecificErrorCode(code: .networkUnavailable)
    }
    
    public func isQuotaExceeded() -> Bool {
        return self.isSpecificErrorCode(code: .quotaExceeded)
    }
    
    public func isSameRecord() -> Bool {
        return self.isSpecificErrorCode(code: .invalidArguments)
    }
    
    public func isSpecificErrorCode(code: CKError.Code) -> Bool {
        var match = false
        if self.code == code {
            match = true
        } else if self.code == .partialFailure {
            // Error contains multiple issues. Check the underlying array of errors.
            guard let errors = self.partialErrorsByItemID else { return false }
            for (_, error) in errors {
                if let cke = error as? CKError {
                    if cke.code == code {
                        match = true
                        break
                    }
                }
            }
        }
        return match
    }
    
    public func getMergeRecords() -> (CKRecord?, CKRecord?) {
        if self.code == .serverRecordChanged { return (self.clientRecord, self.serverRecord) }
        guard self.code == .partialFailure else { return (nil, nil) }
        guard let errors = self.partialErrorsByItemID else { return (nil, nil) }
        for (_, error) in errors {
            if let cke = error as? CKError {
                if cke.code ==  .serverRecordChanged {
                    // Server record error within a partial failure error
                    return cke.getMergeRecords()
                }
            }
        }
        return (nil, nil)
    }
}

extension CKRecord {
    var changeTag: Int64 { return self["changeTag"] ?? 0 }
    
    func id() -> String {
        return self["id"] ?? ""
    }
    
    func created() -> Int64 {
        return self["created"] ?? 0
    }
    
    func modified() -> Int64 {
        return self["modified"] ?? 0
    }
    
    func version() -> Int64 {
        return self["version"] ?? 0
    }
    
    func isSyncEnabled() -> Bool {
        return self["isSyncEnabled"] ?? false
    }
    
    func name() -> String {
        return self["name"] ?? ""
    }
    
    func desc() -> String {
        return self["desc"] ?? ""
    }
    
    func type() -> String {
        return self.recordType
    }
    
    func zoneID() -> CKRecordZone.ID {
        self.recordID.zoneID
    }
}

extension CKQueryOperation.Cursor {
    static func encode(_ cursor: CKQueryOperation.Cursor) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: cursor, requiringSecureCoding: true)
    }
    
    func encode() -> Data? {
        return CKQueryOperation.Cursor.encode(self)
    }
    
    static func decode(_ data: Data) -> CKQueryOperation.Cursor? {
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKQueryOperation.Cursor.self, from: data)
    }
}

extension CKServerChangeToken {
    static func encode(_ token: CKServerChangeToken) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    
    func encode() -> Data? {
        return CKServerChangeToken.encode(self)
    }
    
    static func decode(_ data: Data) -> CKServerChangeToken? {
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }
}

extension CKRecordZone.ID {
    static func encode(_ id: CKRecordZone.ID) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: id, requiringSecureCoding: true)
    }
    
    func encode() -> Data? {
        return CKRecordZone.ID.encode(self)
    }
    
    static func decode(_ data: Data) -> CKRecordZone.ID? {
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecordZone.ID.self, from: data)
    }
}
