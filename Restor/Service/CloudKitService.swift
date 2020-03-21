//
//  CloudKitService.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitService {
    static let shared = CloudKitService()
    let cloudKitContainerId = "iCloud.com.estoapps.ios.restor8"
    let zoneName = "restor-icloud"
    private var _privateDatabase: CKDatabase!
    private var _container: CKContainer!
    private var _zoneID: CKRecordZone.ID!
    private var zone: CKRecordZone?
    private let nc = NotificationCenter.default
    private let kvstore = NSUbiquitousKeyValueStore.default
    
    enum PropKey: String {
        case isZoneCreated
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
    
    func currentUsername() -> String {
        return CKCurrentUserDefaultName
    }
    
    func container() -> CKContainer {
        if self._container == nil { self._container = CKContainer(identifier: self.cloudKitContainerId) }
        return self._container
    }
    
    func privateDatabase() -> CKDatabase {
        if self._privateDatabase == nil { self._privateDatabase = self.container().privateCloudDatabase }
        return self._privateDatabase
    }
    
    // MARK: - Helper methods
    
    func accountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        CKContainer.default().accountStatus { status, error in
            if let err = error { completion(.failure(err)); return }
            completion(.success(status))
        }
    }
    
    func isZoneCreated() -> Bool {
        return self.kvstore.bool(forKey: PropKey.isZoneCreated.rawValue)
    }
    
    func setZoneCreated() {
        self.kvstore.set(true, forKey: PropKey.isZoneCreated.rawValue)
    }
    
    func zoneID() -> CKRecordZone.ID {
        if self._zoneID == nil { self._zoneID = CKRecordZone.ID(zoneName: self.zoneName, ownerName: self.currentUsername()) }
        return self._zoneID
    }
    
    // MARK: - Create
    
    func createZone(completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        if self.zone != nil { completion(.success(self.zone!)); return }
        let _z = CKRecordZone(zoneID: self.zoneID())
        self.privateDatabase().save(_z) { zone, error in
            if let err = error {
                Log.error("Error saving zone: \(err)")
                completion(.failure(err))
                return
            }
            if let z = zone {
                Log.info("Zone created: \(String(describing: self.zone))")
                self.zone = z
                completion(.success(z))
            }
        }
    }
    
    func fetchZone(completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        self.privateDatabase().fetch(withRecordZoneID: self.zoneID()) { zone, error in
            if let err = error { completion(.failure(err)) }
            if let xzone = zone { completion(.success(xzone)) }
        }
    }
    
    // TODO: Add CloudKitError enum
}
