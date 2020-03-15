//
//  PersistenceService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

struct PersistenceService {
    static let shared = PersistenceService()
    private lazy var db = { return CoreDataService.shared }()
    
    mutating func initDefaultWorkspace() throws -> EWorkspace? {
        if !isRunningTests {
            return try self.db.getDefaultWorkspace()
        }
        return nil
    }
}
