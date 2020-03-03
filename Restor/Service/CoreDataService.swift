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
    private var storeType: String!
    lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: "Restor")
        let desc = persistentContainer.persistentStoreDescriptions.first
        desc?.type = self.storeType
        return persistentContainer
    }()
//    lazy var persistentContainer: NSPersistentContainer = {
//        let container = NSPersistentContainer(name: "Restor")
//        container.loadPersistentStores(completionHandler: { storeDescription, error in
//            if let error = error {
//                fatalError("Unresolved error \(error)")
//            }
//            container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
//            container.viewContext.automaticallyMergesChangesFromParent = true
//        })
//        return container
//    }()
    lazy var mainMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    lazy var bgMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return ctx
    }()
    lazy var childMOC: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: self.bgMOC.concurrencyType)
        moc.parent = self.bgMOC
        return moc
    }()
    
    mutating func setup(storeType: String = NSSQLiteStoreType, completion: (() -> Void)?) {
        self.storeType = storeType
        self.loadPersistentStore {
            completion?()
        }
    }
    
    private mutating func loadPersistentStore(completion: @escaping () -> Void) {
        // Handle data migration on a different thread/queue here
        persistentContainer.loadPersistentStores { description, error in
            guard error == nil else {
                fatalError("Unable to load store \(error!)")
            }
            completion()
        }
    }
    
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
    
    mutating func getWorkspace(id: String, context: NSManagedObjectContext? = nil) -> EWorkspace? {
        var x: EWorkspace?
        let moc: NSManagedObjectContext = {
            if context != nil { return context! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
                //throw AppError.entityGet
            }
        }
        return x
    }
    
    mutating func getProject(id: String, context: NSManagedObjectContext? = nil) -> EProject? {
        var x: EProject?
        let moc: NSManagedObjectContext = {
            if context != nil { return context! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EWorkspace")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
                // throw AppError.entityGet
            }
        }
        return x
    }
    
    /// Default entities will have the id "default"
    mutating func getDefaultWorkspace(with project: Bool? = false) -> EWorkspace {
        var x: EWorkspace!
        self.bgMOC.performAndWait {
            if let ws = self.getWorkspace(id: "default") { x = ws; return }
            let ws: EWorkspace! = self.createWorkspace(id: "default", name: "Default workspace")
            ws.desc = "The default workspace"
            if let isProj = project, isProj {
                ws.projects = NSSet()
                ws.projects!.adding(self.getDefaultProject() as Any)
            }
            x = ws
        }
        return x
    }
    
    mutating func getDefaultProject() -> EProject {
        var x: EProject!
        self.bgMOC.performAndWait {
            if let proj = self.getProject(id: "default") { x = proj; return }
            let proj: EProject! = self.createProject(id: "default", name: "default")
            proj.desc = "The default project"
            x = proj
        }
        return x
    }
    
    // MARK: - Create
    
    mutating func createWorkspace(id: String, name: String) -> EWorkspace? {
        var x: EWorkspace?
        self.bgMOC.performAndWait {
            if let ws = self.getWorkspace(id: id) { x = ws; return }
            let ws = NSEntityDescription.insertNewObject(forEntityName: "EWorkspace", into: self.bgMOC) as! EWorkspace
            ws.id = id
            ws.name = name
            ws.created = Date().currentTimeMillis()
            ws.modified = ws.created
            ws.version = 0
            x = ws
        }
        return x
    }
    
    mutating func createProject(id: String, name: String, ws: EWorkspace? = nil) -> EProject? {
        var x: EProject?
        self.bgMOC.performAndWait {
            if let proj = self.getProject(id: id) { x = proj; return }
            let proj = NSEntityDescription.insertNewObject(forEntityName: "EProject", into: self.bgMOC) as! EProject
            proj.id = id
            proj.name = name
            proj.created = Date().currentTimeMillis()
            proj.modified = proj.created
            proj.version = 0
            ws?.addToProjects(proj)
            x = proj
        }
        return x
    }
    
    // MARK: - Save
    
    mutating func saveContext(_ entity: NSManagedObject) {
        if let moc = entity.managedObjectContext {
            moc.performAndWait {
                do {
                    try moc.save()
                } catch let error {
                    Log.error("Error saving entity: \(error)")
                }
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteEntity(_ entity: NSManagedObject?) {
        Log.debug("delete entity: \(String(describing: entity))")
        if let x = entity, let moc = x.managedObjectContext {
            moc.performAndWait {
                moc.delete(x)
            }
        }
    }
}

//extension NSManagedObject {
//    static func get<T: NSManagedObject>(with kv: (String, CVarArg), in context: NSManagedObjectContext) throws -> T? {
//        guard let name = self.entity().name else { return nil }
//        guard T.entity().propertiesByName[kv.0] != nil else {
//            Log.error("\(name) does not have the property \(kv.0)")
//            return nil
//        }
//        let fr = NSFetchRequest<T>(entityName: name)
//        fr.predicate = NSPredicate(format: "\(kv.0) == %@", kv.1)
//        do {
//            let xs = try context.fetch(fr)
//            return xs.first
//        } catch let error {
//            Log.error("Error getting entity: \(name) - \(error)")
//            throw AppError.entityGet
//        }
//    }
//
//    static func create<T: NSManagedObject>(id: String, in context: NSManagedObjectContext) -> T? {
//        guard let name = self.entity().name else { return nil }
//        guard T.entity().propertiesByName["id"] != nil else {
//            Log.error("\(name) does not have the property id")
//            return nil
//        }
//        return T.init(context: context)
//    }
//
//    static func delete<T: NSManagedObject>(with kv: (String, CVarArg), in context: NSManagedObjectContext) throws -> T? {
//        guard let name = self.entity().name else { return nil }
//        guard T.entity().propertiesByName[kv.0] != nil else {
//            Log.error("\(name) does not have the property \(kv.0)")
//            return nil
//        }
//        let fr = NSFetchRequest<T>(entityName: name)
//        fr.predicate = NSPredicate(format: "\(kv.0) == %@", kv.1)
//        do {
//            let xs = try context.fetch(fr)
//            if let first = xs.first {
//                context.delete(first)
//            }
//            return nil
//        } catch let error {
//            Log.error("Error getting entity: \(name) - \(error)")
//            throw AppError.entityGet
//        }
//    }
//}
