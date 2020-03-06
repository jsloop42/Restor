//
//  Models.swift
//  Restor
//
//  Created by jsloop on 03/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

protocol Entity {
    func getId() -> String?
    func getIndex() -> Int
    func getName() -> String?
    func getCreated() -> Int64
    func getModified() -> Int64
    func getVersion() -> Int64
}

class EFile: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class EImage: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class EProject: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class ERequest: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class ERequestBodyData: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.id
    }
    
    func getCreated() -> Int64 {
        return created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class ERequestData: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.id
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class ERequestMethodData: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class ETag: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}

class EWorkspace: NSManagedObject, Entity {
    func getId() -> String? {
        return self.id
    }
    
    func getIndex() -> Int {
        return self.index.toInt()
    }
    
    func getName() -> String? {
        return self.name
    }
    
    func getCreated() -> Int64 {
        return self.created
    }
    
    func getModified() -> Int64 {
        return self.modified
    }
    
    func getVersion() -> Int64 {
        return self.version
    }
}
