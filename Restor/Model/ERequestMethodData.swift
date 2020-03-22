//
//  ERequestMethodData.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestMethodData: NSManagedObject, Entity {
    public func getId() -> String? {
        return self.id
    }
    
    public func getIndex() -> Int {
        return self.index.toInt()
    }
    
    public func getName() -> String? {
        return self.name
    }
    
    public func getCreated() -> Int64 {
        return self.created
    }
    
    public func getModified() -> Int64 {
        return self.modified
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIndex(_ i: Int) {
        self.index = i.toInt64()
    }
}
