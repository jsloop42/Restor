//
//  CloudKitService.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitDelegate: class {
}

class CloudKitService {
    static let shared = CloudKitService()
    let cloudKitContainerId = "iCloud.com.estoapps.ios.restor8"
    private var _privateDatabase: CKDatabase!
    private var _container: CKContainer!
    var zoneIDs: Set<CKRecordZone.ID> = Set()
    var zones: Set<CKRecordZone> = Set()
    var subscriptions: Set<CKSubscription> = Set()
    var zoneSubscriptions: [CKSubscription.ID: CKRecordZone.ID] = [:]
    private let nc = NotificationCenter.default
    private let kvstore = NSUbiquitousKeyValueStore.default
    weak var delegate: CloudKitDelegate?
    
    enum PropKey: String {
        case isZoneCreated
        case serverChangeToken
    }
    
    deinit {
        self.nc.removeObserver(self)
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
        return CKRecordZone.ID(zoneName: "ws-\(workspaceId)", ownerName: self.currentUsername())
    }
    
    /// Returns the record ID for the given entity id.
    func recordID(entityId: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        return CKRecord.ID(recordName: "\(entityId).\(zoneID.zoneName)", zoneID: zoneID)
    }
    
    /// Returns the entity id for the given record ID.
    func entityID(recordID: CKRecord.ID) -> String {
        return recordID.recordName.components(separatedBy: ".").first ?? ""
    }
    
    /// Handles remote iCloud notifications
    func handleNotification(zoneID: CKRecordZone.ID) {
        var changeToken: CKServerChangeToken? = nil
        if let changeTokenData = UserDefaults.standard.data(forKey: PropKey.serverChangeToken.rawValue) {
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
        }
        op.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, data in
            guard let changeToken = changeToken else { return }
            Log.debug("record zone change tokens updated")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            UserDefaults.standard.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.recordZoneFetchCompletionBlock = { zoneID, changeToken, data, more, error in
            guard error == nil else { return }
            guard let changeToken = changeToken else { return }
            Log.debug("record zone fetch completion")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            UserDefaults.standard.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.fetchRecordZoneChangesCompletionBlock = { error in
            guard error == nil else { return }
            Log.debug("fetch record zone changes completion")
        }
        self.privateDatabase().add(op)
    }
    
    // MARK: - Create
    
    /// Create zone with the given zone Id.
    func createZone(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        let z = CKRecordZone(zoneID: recordZoneId)
        if !self.zones.contains(z) {
            let op = CKModifyRecordZonesOperation(recordZonesToSave: [z], recordZoneIDsToDelete: [])
            op.modifyRecordZonesCompletionBlock = { _, _, error in
                if let err = error {
                    Log.error("Error saving zone: \(err)")
                    completion(.failure(err))
                    return
                }
                Log.debug("Zone created successfully: \(recordZoneId.zoneName)")
                self.zones.insert(z)
                completion(.success(z))
            }
            op.qualityOfService = .utility
            self.privateDatabase().add(op)
        } else {
            completion(.success(z))
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
    
    /// Create zone if not created already.
    func createZoneIfNotExist(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        self.fetchZone(recordZoneIDs: [recordZoneId], completion: { result in
            switch result {
            case .success(let hm):
                if let zone = hm[recordZoneId] {
                    self.zones.insert(zone)
                    completion(.success(zone))
                } else {
                    completion(.failure(AppError.error))
                }
            case .failure(let error):
                if let err = error as? CKError, err.isZoneNotFound() {
                    self.createZone(recordZoneId: recordZoneId) { result in
                        switch result {
                        case .success(let zone):
                            completion(.success(zone))
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
    func saveRecords(_ records: [CKRecord], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !records.isEmpty else { completion(.success(false)); return }
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        op.qualityOfService = .utility
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
                    // TODO: merge in the changes, save the new record
                    completion(.failure(ckerror)); return
                }
                return
            }
            // Create subscription on the first record write, which will only subscribe if not done already.
            //self.saveSubscription(recordType: recordType)
            Log.debug("Records saved successfully: \(records.map { r -> String in r.recordID.recordName })")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
    }
    
    /// Returns zone name from the given subscription ID.
    func getZoneNameFromSubscriptionID(_ subID: CKSubscription.ID) -> String {
        let name = subID.description
        let xs = name.components(separatedBy: ".")
        return xs.last ?? ""
    }
    
    /// Save subscription will be made only once for the given type.
    func saveSubscription(_ subId: String, recordType: String, zoneID: CKRecordZone.ID) {
        let subSavedKey = "\(recordType)-subscription-saved.\(zoneID.zoneName)"
        let isSaved = UserDefaults.standard.bool(forKey: subSavedKey)
        guard !isSaved else { return }
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subId,
                                               options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion,
                                                         CKQuerySubscription.Options.firesOnRecordUpdate])
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            UserDefaults.standard.set(true, forKey: subSavedKey)
            self.subscriptions.insert(subscription)
            self.zoneSubscriptions[subscription.subscriptionID] = zoneID
            Log.debug("Subscribed to events successfully: \(recordType) with ID: \(subscription.subscriptionID.description)")
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
            recordZoneIds.forEach { zoneID in
                self.zoneIDs.remove(zoneID)
                if let idx = (self.zones.firstIndex(where: { zone -> Bool in zone.zoneID == zoneID })) {
                    self.zones.remove(at: idx)
                }
            }
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
    func deleteSubscription(subscriptionID: CKSubscription.ID, completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifySubscriptionsOperation.init(subscriptionsToSave: [], subscriptionIDsToDelete: [subscriptionID])
        op.qualityOfService = .utility
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            if let err = error { completion(.failure(err)); return }
            self.zoneSubscriptions.removeValue(forKey: subscriptionID)
            Log.debug("Subscription deleted successfully: \(subscriptionID.description)")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
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
