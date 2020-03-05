//
//  CoreDataService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

class CoreDataService {
    static var shared = CoreDataService()
    private var storeType: String!
    lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: "Restor")
        let desc = persistentContainer.persistentStoreDescriptions.first
        desc?.type = self.storeType
        return persistentContainer
    }()
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
    
    func setup(storeType: String = NSSQLiteStoreType, completion: (() -> Void)?) {
        self.storeType = storeType
        self.loadPersistentStore {
            completion?()
        }
    }
    
    private func loadPersistentStore(completion: @escaping () -> Void) {
        // Handle data migration on a different thread/queue here
        self.persistentContainer.loadPersistentStores { description, error  in
            guard error == nil else {
                fatalError("Unable to load store \(error!)")
            }
            self.persistentContainer.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            completion()
        }
    }
    
    func saveContext(_ callback: ((Bool) -> Void)? = nil) {
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
    
    // MARK: Workspace
    
    func getWorkspace(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EWorkspace? {
        var x: EWorkspace?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
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
            }
        }
        return x
    }
    
    /// Default entities will have the id "default"
    func getDefaultWorkspace(with project: Bool? = false) -> EWorkspace {
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
    
    // MARK: Project
    
    func getProject(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
        var x: EProject?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getProjects(in ws: EWorkspace, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        guard let id = ws.id else { return xs }
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "workspace.id == %@", id)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entities - \(error)")
            }
        }
        return xs
    }
    
    func getDefaultProject() -> EProject {
        var x: EProject!
        self.bgMOC.performAndWait {
            if let proj = self.getProject(id: "default") { x = proj; return }
            let proj: EProject! = self.createProject(id: "default", name: "default")
            proj.desc = "The default project"
            x = proj
        }
        return x
    }
    
    // MARK: Request
    
    func getRequest(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestMethodData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestBodyData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    // MARK: - Create
    
    /// Create workspace.
    /// - Parameters:
    ///   - id: The workspace id.
    ///   - name: The workspace name.
    ///   - checkExists: Check whether the workspace exists before creating.
    func createWorkspace(id: String, name: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EWorkspace? {
        var x: EWorkspace?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExist = checkExists, isExist, let ws = self.getWorkspace(id: id, ctx: ctx) { x = ws; return }
            let ws = NSEntityDescription.insertNewObject(forEntityName: "EWorkspace", into: self.bgMOC) as! EWorkspace
            ws.id = id
            ws.name = name
            ws.created = ts
            ws.modified = ts
            ws.version = 0
            x = ws
        }
        return x
    }
    
    /// Create project.
    /// - Parameters:
    ///   - id: The project id.
    ///   - name: The project name.
    ///   - ws: The workspace to which the project belongs.
    ///   - checkExists: Check if the given project exists before creating.
    func createProject(id: String, name: String, ws: EWorkspace? = nil, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
        var x: EProject?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExist = checkExists, isExist, let proj = self.getProject(id: id, ctx: ctx) { x = proj; return }
            let proj = NSEntityDescription.insertNewObject(forEntityName: "EProject", into: self.bgMOC) as! EProject
            proj.id = id
            proj.name = name
            proj.created = ts
            proj.modified = ts
            proj.version = 0
            ws?.addToProjects(proj)
            x = proj
        }
        return x
    }
    
    func createRequest(id: String, name: String, project: EProject? = nil, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let req = self.getRequest(id: id, ctx: ctx) { x = req; return }
            let req = NSEntityDescription.insertNewObject(forEntityName: "ERequest", into: self.bgMOC) as! ERequest
            req.id = id
            req.name = name
            req.created = ts
            req.modified = ts
            req.version = 0
            req.project = project
            x = req
        }
        return x
    }
    
    func createRequestData(id: String, type: RequestHeaderInfo, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestData(id: id, ctx: ctx) { x = data; return }
            let data = NSEntityDescription.insertNewObject(forEntityName: "ERequestData", into: self.bgMOC) as! ERequestData
            data.id = id
            data.created = ts
            data.modified = ts
            data.version = 0
            data.type = type.rawValue.toInt32()
            x = data
        }
        return x
    }
    
    func createRequestMethodData(id: String, name: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestMethodData(id: id, ctx: ctx) { x = data; return }
            let data = NSEntityDescription.insertNewObject(forEntityName: "ERequestMethodData", into: self.bgMOC) as! ERequestMethodData
            data.id = id
            data.name = name
            data.created = ts
            data.modified = ts
            data.version = 0
            x = data
        }
        return x
    }
    
    func createRequestBodyData(id: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestBodyData(id: id, ctx: ctx) { x = data; return }
            let data = NSEntityDescription.insertNewObject(forEntityName: "ERequestBodyData", into: self.bgMOC) as! ERequestBodyData
            data.id = id
            data.created = ts
            data.modified = ts
            data.version = 0
            x = data
        }
        return x
    }
    
    // MARK: - Save
    
    func saveContext(_ entity: NSManagedObject) {
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
