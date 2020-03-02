//
//  CoreDataService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

struct CoreDataService {
    static var shared = CoreDataService()
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Restor")
        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
            container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            container.viewContext.automaticallyMergesChangesFromParent = true
        })
        return container
    }()
    lazy var bgMOC: NSManagedObjectContext = {
        return self.persistentContainer.newBackgroundContext()
    }()
    lazy var childMOC: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: self.bgMOC.concurrencyType)
        moc.parent = self.bgMOC
        return moc
    }()
    
    mutating func saveContext(_ callback: ((Bool) -> Void)? = nil) {
        let context = self.persistentContainer.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                if let cb = callback { cb(false) }
                return
            }
            if let cb = callback { cb(true) }
        }
    }
    
    
    // MARK: - Get
    
    /// Default entities will have the id "default"
    mutating func getDefaultWorkspace(with project: Bool? = false) throws -> EWorkspace {
        if let ws = try EWorkspace.get(with: ("id", "default"), in: self.bgMOC) as? EWorkspace {
            return ws
        }
        let ws = EWorkspace(context: self.bgMOC)
        ws.created = Date().currentTimeMillis()
        ws.modified = ws.created
        ws.version = 0
        ws.id = "default"
        ws.name = "Default workspace"
        ws.desc = "The default workspace"
        if let isProj = project, isProj {
            ws.projects = NSSet()
            ws.projects!.adding(try self.getDefaultProject() as Any)
        }
        return ws
    }
    
    mutating func getDefaultProject() throws -> EProject {
        if let proj = try EProject.get(with: ("id", "default"), in: self.bgMOC) as? EProject {
            return proj
        }
        let proj = EProject(context: self.bgMOC)
        proj.created = Date().currentTimeMillis()
        proj.modified = proj.created
        proj.version = 0
        proj.id = "default"
        proj.name = "Default project"
        proj.desc = "The default project"
        return proj
    }
    
    // MARK: - Save
    
    mutating func saveContext(_ entity: NSManagedObject) throws {
        if let moc = entity.managedObjectContext {
            do {
                try moc.save()
            } catch let error {
                Log.error("Error saving entity: \(error)")
                throw AppError.entityUpdate
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteEntity(_ entity: NSManagedObject) {
        if let moc = entity.managedObjectContext {
            moc.delete(entity)
        }
    }
}

extension NSManagedObject {
    static func get<T: NSManagedObject>(with kv: (String, CVarArg), in context: NSManagedObjectContext) throws -> T? {
        guard let name = self.entity().name else { return nil }
        guard T.entity().propertiesByName[kv.0] != nil else {
            Log.error("\(name) does not have the property \(kv.0)")
            return nil
        }
        let fr = NSFetchRequest<T>(entityName: name)
        fr.predicate = NSPredicate(format: "\(kv.0) == %@", kv.1)
        do {
            let xs = try context.fetch(fr)
            return xs.first
        } catch let error {
            Log.error("Error getting entity: \(name) - \(error)")
            throw AppError.entityGet
        }
    }
    
    static func create<T: NSManagedObject>(id: String, in context: NSManagedObjectContext) -> T? {
        guard let name = self.entity().name else { return nil }
        guard T.entity().propertiesByName["id"] != nil else {
            Log.error("\(name) does not have the property id")
            return nil
        }
        return T.init(context: context)
    }
}
