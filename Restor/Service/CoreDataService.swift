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
    private let fetchBatchSize: Int = 50
    
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
    
    func getAllWorkspaces(ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EWorkspace] {
        var xs: [EWorkspace] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return xs
    }
    
    /// Default entities will have the id "default"
    func getDefaultWorkspace(with project: Bool? = false) -> EWorkspace {
        var x: EWorkspace!
        self.bgMOC.performAndWait {
            if let ws = self.getWorkspace(id: "default") { x = ws; return }
            let ws: EWorkspace! = self.createWorkspace(id: "default", index: 0, name: "Default workspace")
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
    
    /// Retrieves the projects belonging to the given workspace.
    /// - Parameters:
    ///   - wsId: The workspace id.
    ///   - ctx: The managed object context.
    func getProjects(wsId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "workspace.id == %@", wsId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
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
            let proj: EProject! = self.createProject(id: "default", index: 0, name: "default")
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
    
    /// Retrieve the requests in the given project.
    /// - Parameters:
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequests(projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequest] {
        var xs: [ERequest] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieve request at the given index for the project.
    /// - Parameters:
    ///   - index: The order index.
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequest(at index: Int, projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the total requests count in the given project
    /// - Parameters:
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequestsCount(projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
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
                x = try moc.fetch(fr).first
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
                x = try moc.fetch(fr).first
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
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieve form data for the given request body.
    /// - Parameters:
    ///   - bodyDataId: The request body data id.
    ///   - ctx: The managed object context of the request body data object.
    func getFormRequestData(_ bodyDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestBodyData] {
        var xs: [ERequestBodyData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = NSPredicate(format: "form.id == %@", bodyDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching form request data: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the form at the given index.
    /// - Parameters:
    ///   - index: The index of the form.
    ///   - bodyDataId: The request body data id.
    ///   - ctx: The managed object context.
    func getFormRequestData(at index: Int, bodyDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = NSPredicate(format: "form.id == %@ AND index == %ld", bodyDataId, index.toInt64())
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    func getMultipartRequestData(_ bodyDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestBodyData] {
        var xs: [ERequestBodyData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = NSPredicate(format: "multipart.id == %@", bodyDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching form request data: \(error)")
            }
        }
        return xs
    }
    
    func getHeadersRequestData(_ bodyDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "headers.id == %@", bodyDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching headers request data: \(error)")
            }
        }
        return xs
    }
    
    func getParamsRequestData(_ bodyDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "params.id == %@", bodyDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching params request data: \(error)")
            }
        }
        return xs
    }
    
    /// Get the total number of files in the given request data.
    /// - Parameters:
    ///   - reqDataId: The request data id.
    ///   - ctx: The managed object context of the request data.
    func getFilesCount(_ reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@", reqDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting files count: \(error)")
            }
        }
        return x
    }
    
    /// Get files for the given request data.
    /// - Parameters:
    ///   - reqDataId: The request data id.
    ///   - ctx: The managed object context of the request data.
    func getFiles(_ reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@", reqDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting files: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the file at the given index.
    /// - Parameters:
    ///   - index: The index of the file in the request data list.
    ///   - reqDataId: The request data id.
    ///   - ctx: The managed object context.
    func getFile(at index: Int, reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EFile? {
        var x: EFile?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@ AND index == %ld", reqDataId, index.toInt64())
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    // MARK: - Create
    
    /// Create workspace.
    /// - Parameters:
    ///   - id: The workspace id.
    ///   - index: The order of the workspace.
    ///   - name: The workspace name.
    ///   - checkExists: Check whether the workspace exists before creating.
    func createWorkspace(id: String, index: Int, name: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EWorkspace? {
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
            ws.index = index.toInt64()
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
    ///   - index: The order of the project.
    ///   - name: The project name.
    ///   - ws: The workspace to which the project belongs.
    ///   - checkExists: Check if the given project exists before creating.
    func createProject(id: String, index: Int, name: String, ws: EWorkspace? = nil, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
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
            proj.index = index.toInt64()
            proj.name = name
            proj.created = ts
            proj.modified = ts
            proj.version = 0
            ws?.addToProjects(proj)
            x = proj
        }
        return x
    }
    
    
    /// Create a request
    /// - Parameters:
    ///   - id: The request id.
    ///   - name: The name of the request.
    ///   - project: The project to which the request belongs to.
    ///   - checkExists: Check if the request exists before creating one.
    ///   - ctx: The managed object context
    func createRequest(id: String, index: Int, name: String, project: EProject? = nil, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
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
            req.index = index.toInt64()
            req.name = name
            req.created = ts
            req.modified = ts
            req.version = 0
            req.project = project
            x = req
        }
        return x
    }
        
    /// Create request data.
    /// - Parameters:
    ///   - id: The request data id.
    ///   - index: The index of the request data.
    ///   - type: The request data type.
    ///   - checkExists: Check for existing request data object.
    ///   - ctx: The managed object context.
    func createRequestData(id: String, index: Int, type: RequestHeaderInfo, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
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
            data.index = index.toInt64()
            data.created = ts
            data.modified = ts
            data.version = 0
            data.type = type.rawValue.toInt32()
            x = data
        }
        return x
    }
    
    /// Crate request method data
    /// - Parameters:
    ///   - id: The request method data id.
    ///   - index: The order of the request method data.
    ///   - name: The name of the request method data.
    ///   - checkExists: Check if the request method data exists
    ///   - ctx: The managed object context
    func createRequestMethodData(id: String, index: Int, name: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
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
            data.index = index.toInt64()
            data.name = name
            data.created = ts
            data.modified = ts
            data.version = 0
            x = data
        }
        return x
    }
    
    /// Create request body data.
    /// - Parameters:
    ///   - id: The request body data id.
    ///   - index: The order of the request body data.
    ///   - checkExists: Check if the request body data exists before creating.
    ///   - ctx: The managed object context.
    func createRequestBodyData(id: String, index: Int, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
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
            data.index = index.toInt64()
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
