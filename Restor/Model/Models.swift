//
//  Models.swift
//  Restor
//
//  Created by jsloop on 03/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

protocol Entity: NSManagedObject {
    func getId() -> String?
    func getIndex() -> Int
    func getName() -> String?
    func getCreated() -> Int64
    func getModified() -> Int64
    func getVersion() -> Int64
    func setIndex(_ i: Int)
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
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
    
    func setIndex(_ i: Int) {
        self.index = i.toInt64()
    }
}
