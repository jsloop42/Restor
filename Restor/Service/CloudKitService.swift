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
        let zoneIDData = NSKeyedArchiver.archivedData(withRootObject: self.zoneID)
        coder.encode(zoneIDData, forKey: CodingKeys.zoneID.rawValue)
        if let token = self.serverChangeToken {
            let tokenData = NSKeyedArchiver.archivedData(withRootObject: token)
            coder.encode(tokenData, forKey: CodingKeys.serverChangeToken.rawValue)
        }
    }
    
    required init?(coder: NSCoder) {
        let zoneIDData = coder.decodeObject(forKey: CodingKeys.zoneID.rawValue) as! Data
        self.zoneID = NSKeyedUnarchiver.unarchiveObject(with: zoneIDData) as! CKRecordZone.ID
        if let tokenData = coder.decodeObject(forKey: CodingKeys.serverChangeToken.rawValue) as? Data {
            self.serverChangeToken = NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
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
    let subscriptionsKey = "ck-subscriptions"
    /// A dictionary of all zones [String: Data]  // [zone-name: zone-info]
    let zonesKey = "zones-key"
    
    enum PropKey: String {
        case isZoneCreated
        case serverChangeToken
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    init() {
        self.loadSubscriptions()
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
        Log.debug("kv store did change")
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
    
    func addServerChangeTokenToCache(_ token: CKServerChangeToken, zoneID: CKRecordZone.ID) {
        var zones = self.getCachedZones()
        let key = zoneID.zoneName
        if let data = zones[key], let info = ZoneInfo.decode(data) {
            info.serverChangeToken = token
            zones[key] = info.encode()
            self.setCachedZones(zones)
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
    func handleNotification(zoneID: CKRecordZone.ID) {
        var changeToken: CKServerChangeToken? = nil
        if let changeTokenData = self.store.data(forKey: PropKey.serverChangeToken.rawValue) {
            changeToken = NSKeyedUnarchiver.unarchiveObject(with: changeTokenData) as? CKServerChangeToken
        }
        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = changeToken
        let optionsMap = [zoneID: options]
        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], optionsByRecordZoneID: optionsMap)
        op.fetchAllChanges = true
        op.qualityOfService = .utility
        op.recordChangedBlock = { record in
            Log.debug("record changed: \(record)")
            PersistenceService.shared.cloudRecordDidChange(record)
        }
        op.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, data in
            guard let changeToken = changeToken else { return }
            Log.debug("record zone change tokens updated")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            self.store.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.recordZoneFetchCompletionBlock = { zoneID, changeToken, data, more, error in
            guard error == nil else { return }
            guard let changeToken = changeToken else { return }
            Log.debug("record zone fetch completion")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            self.store.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.fetchRecordZoneChangesCompletionBlock = { error in
            guard error == nil else { return }
            Log.debug("fetch record zone changes completion")
        }
        self.privateDatabase().add(op)
    }
    
    /// Fetches all subscriptions from cloud and updates user defaults.
    func loadSubscriptions() {
        self.fetchSubscriptions { result in
            switch result {
            case .success(let xs):
                let subIds: [CKSubscription.ID] = xs.map { $0.subscriptionID }
                self.addToCachedSubscriptions(subIds)
            case .failure(let err):
                Log.error("Error fetching subscriptions: \(err)")
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
        Log.debug("fetching all zones")
        self.privateDatabase().fetchAllRecordZones { zones, error in
            if let err = error { completion(.failure(err)); return }
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
                Log.debug("fetched zone: \(hm.count)")
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
        let op = CKFetchRecordZonesOperation(recordZoneIDs: recordZoneIDs)
        op.qualityOfService = .utility
        op.fetchRecordZonesCompletionBlock = { res, error in
            if let err = error { completion(.failure(err)); return }
            if let hm = res { completion(.success(hm)) }
        }
        self.privateDatabase().add(op)
    }
    
    func fetchZoneChanges(zoneIDs: [CKRecordZone.ID], completion: @escaping (Result<(saved: [CKRecord], deleted: [CKRecord.ID]), Error>) -> Void) {
        var zoneOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] = [:]
        var savedRecords: [CKRecord] = []
        var deletedRecords: [CKRecord.ID] = []
        zoneIDs.forEach { zID in
            let token: CKServerChangeToken? = self.getCachedServerChangeToken(zID)
            let opt = CKFetchRecordZoneChangesOperation.ZoneOptions()
            opt.previousServerChangeToken = token
            zoneOptions[zID] = opt
        }
        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: zoneOptions)
        op.recordChangedBlock = { record in
            savedRecords.append(record)
        }
        op.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecords.append(recordID)
        }
        op.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, _ in
            if let token = changeToken { self.addServerChangeTokenToCache(token, zoneID: zoneID) }
        }
        op.fetchRecordZoneChangesCompletionBlock = { error in
            if let err = error { Log.error("Error fetching zone changes: \(err)"); completion(.failure(err)); return }
            completion(.success((savedRecords, deletedRecords)))
        }
    }
    
    /// Fetch the given zones.
    func fetchRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord.ID: CKRecord], Error>) -> Void) {
        let op = CKFetchRecordsOperation(recordIDs: recordIDs)
        op.qualityOfService = .utility
        op.fetchRecordsCompletionBlock = { res, error in
            if let err = error { completion(.failure(err)); return }
            if let hm = res { completion(.success(hm)) }
        }
        self.privateDatabase().add(op)
    }
    
    func fetchSubscriptions(completion: @escaping (Result<[CKSubscription], Error>) -> Void) {
        self.privateDatabase().fetchAllSubscriptions { subscriptions, error in
            if let err = error { completion(.failure(err)); return }
            completion(.success(subscriptions ?? []))
        }
    }
    
    // MARK: - Create
    
    /// Create zone with the given zone Id.
    func createZone(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone.ID, Error>) -> Void) {
        let z = CKRecordZone(zoneID: recordZoneId)
        if self.containsCachedZoneID(recordZoneId) { completion(.success(recordZoneId)); return }
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [z], recordZoneIDsToDelete: [])
        op.modifyRecordZonesCompletionBlock = { zones, _, error in
            if let err = error {
                Log.error("Error saving zone: \(err)")
                completion(.failure(err))
                return
            }
            if let x = zones?.first {
                Log.debug("Zone created successfully: \(x.zoneID.zoneName)")
                self.addToCachedZones(x)
                completion(.success(recordZoneId))
            } else {
                Log.error("Error creating zone. Zone is empty.")
                completion(.failure(AppError.create))
            }
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    /// Create zone if not created already.
    func createZoneIfNotExist(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone.ID, Error>) -> Void) {
        self.fetchZone(recordZoneIDs: [recordZoneId], completion: { result in
            switch result {
            case .success(let hm):
                if let zone = hm[recordZoneId] {
                    self.addToCachedZones(zone)
                    completion(.success(zone.zoneID))
                } else {
                    completion(.failure(AppError.error))
                }
            case .failure(let error):
                if let err = error as? CKError, err.isZoneNotFound() {
                    self.createZone(recordZoneId: recordZoneId) { result in
                        switch result {
                        case .success(let zoneID):
                            completion(.success(zoneID))
                        case .failure(let err):
                            completion(.failure(err))
                        }
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
        guard !records.isEmpty else { completion(.success([])); return }
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        var saved: [CKRecord] = []
        let lock = NSLock()
        op.qualityOfService = .utility
        if isForce! { op.savePolicy = .changedKeys }
        op.perRecordCompletionBlock = { record, error in
            guard error == nil else { return }
            lock.lock()
            saved.append(record)
            lock.unlock()
        }
        op.modifyRecordsCompletionBlock = { _, _, error in
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
                    Log.error("Error saving record. Record already exists.")
                    if count! >= 2 { completion(.failure(ckerror)); return }  // Tried three time.
                    // Merge in the changes, save the new record
                    let (local, server) = ckerror.getMergeRecords()
                    if let merged = PersistenceService.shared.mergeRecords(local: local, server: server, recordType: local?.recordType ?? "") {
                        self.saveRecords([merged], count: count! + 1, isForce: true, completion: completion)
                    } else {
                        completion(.failure(ckerror))
                    }
                }
                return
            }
            Log.debug("Records saved successfully: \(records.map { r -> String in r.recordID.recordName })")
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
        if isSubscribed(to: subId) { return }
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subId,
                                               options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion,
                                                         CKQuerySubscription.Options.firesOnRecordUpdate])
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        //notifInfo.alertBody = "Yay!"
        subscription.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            self.addToCachedSubscriptions(subId)
            Log.debug("Subscribed to events successfully: \(recordType) with ID: \(subscription.subscriptionID.description)")
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    func subscribeToDBChanges(subId: String) {
        if isSubscribed(to: subId) { return }
        let sub = CKDatabaseSubscription(subscriptionID: subId)
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        sub.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            self.addToCachedSubscriptions(subId)
            Log.debug("Subscribed to database change event: \(subId)")
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    // MARK: - Delete
    
    /// Delete zone with the given zone ID.
    func deleteZone(recordZoneIds: [CKRecordZone.ID], completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [], recordZoneIDsToDelete: recordZoneIds)
        op.modifyRecordZonesCompletionBlock = { _, _, error in
            if let err = error {
                Log.error("Error deleting zone: \(err)")
                completion(.failure(err))
                return
            }
            Log.debug("Zone deleted successfully: \(recordZoneIds.map { r -> String in r.zoneName })")
            self.removeFromCachesZones(recordZoneIds)
            completion(.success(true))
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    /// Delete records with the given record IDs.
    func deleteRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: recordIDs)
        op.qualityOfService = .utility
        op.modifyRecordsCompletionBlock = { _, _, error in
            if let err = error { completion(.failure(err)); return }
            Log.debug("Records deleted successfully: \(recordIDs.map { r -> String in r.recordName })")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
    }
    
    /// Delete subscription with the given subscription ID.
    func deleteSubscriptions(subscriptionIDs: [CKSubscription.ID], completion: @escaping (Result<[CKSubscription.ID], Error>) -> Void) {
        let op = CKModifySubscriptionsOperation.init(subscriptionsToSave: [], subscriptionIDsToDelete: subscriptionIDs)
        op.qualityOfService = .utility
        op.modifySubscriptionsCompletionBlock = { _, ids, error in
            if let err = error { completion(.failure(err)); return }
            guard let xs = ids else { completion(.failure(AppError.delete)); return }
            Log.debug("Subscriptions deleted successfully: \(xs)")
            completion(.success(xs))
        }
        self.privateDatabase().add(op)
    }
    
    func deleteAllSubscriptions() {
        self.fetchSubscriptions { result in
            switch result {
            case .success(let subs):
                self.deleteSubscriptions(subscriptionIDs: subs.map { $0.subscriptionID }) { result in
                    switch result {
                    case .success(let ids):
                        let xs = UserDefaults.standard.array(forKey: self.subscriptionsKey) as? [CKSubscription.ID] ?? []
                        let diff = Utils.shared.subtract(lxs: xs, rxs: ids)  // not deleted subscriptions
                        UserDefaults.standard.set(diff, forKey: self.subscriptionsKey)
                    case .failure(let err):
                        Log.error("Error deleting subscriptions: \(err)")
                    }
                }
            case .failure(let err):
                Log.error("Error fetching subscriptions: \(err)")
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
    
    func index() -> Int64 {
        return self["index"] ?? 0
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
