//
//  CoreDataService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

public enum RecordType: String, Hashable {
    case file = "File"
    case image = "Image"
    case project = "Project"
    case request = "Request"
    case requestBodyData = "RequestBodyData"
    case requestData = "RequestData"
    case requestMethodData = "RequestMethodData"
    case workspace = "Workspace"
    case history = "History"
    case env = "Env"
    case envVar = "EnvVar"
    // CloudKit specific
    case zone = "Zone"
    
    static func from(id: String) -> RecordType? {
        if id == "default" { return .workspace }
        switch id.prefix(2) {
        case "ws":
            return self.workspace
        case "pj":
            return self.project
        case "rq":
            return self.request
        case "rb":
            return self.requestBodyData
        case "rd":
            return self.requestData
        case "rm":
            return self.requestMethodData
        case "fl":
            return self.file
        case "im":
            return self.image
        case "zn":
            return self.zone
        case "hs":
            return self.history
        case "en":
            return self.env
        case "ev":
            return self.envVar
        default:
            return nil
        }
    }
    
    static func prefix(for type: RecordType) -> String {
        switch type {
        case .workspace:
            return "ws"
        case .project:
            return "pj"
        case .request:
            return "rq"
        case .requestBodyData:
            return "rb"
        case .requestData:
            return "rd"
        case .requestMethodData:
            return "rm"
        case .file:
            return "fl"
        case .image:
            return "im"
        case .zone:
            return "zn"
        case .history:
            return "hs"
        case .env:
            return "en"
        case .envVar:
            return "ev"
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
    
    static subscript(_ type: String) -> RecordType? {
        return RecordType(rawValue: type)
    }
    
    /// All data record type
    static let allCases: [RecordType] = [RecordType.workspace, RecordType.project, RecordType.request, RecordType.requestBodyData, RecordType.requestData,
                                         RecordType.requestMethodData, RecordType.file, RecordType.image, RecordType.env, RecordType.envVar]
}

class CoreDataService {
    static var shared = CoreDataService()
    private var storeType: String! = NSSQLiteStoreType
    lazy var peristentContainerTest: NSPersistentContainer = {
        let model = self.model
        return NSPersistentContainer(name: self.containerName, managedObjectModel: model)
    }()
    lazy var persistentContainer: NSPersistentContainer = {
        let model = self.model
        return NSPersistentContainer(name: self.containerName, managedObjectModel: model)
    }()
    lazy var model: NSManagedObjectModel = {
        let modelPath = Bundle(for: type(of: self)).path(forResource: "Restor", ofType: "momd")
        let url = URL(fileURLWithPath: modelPath!)
        return NSManagedObjectModel(contentsOf: url)!
    }()
    lazy var mainMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    lazy var bgMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    private let fetchBatchSize: Int = 50
    private let utils = EAUtils.shared
    var containerName = isRunningTests ? "RestorTest" : "Restor"
    let defaultWorkspaceId = "default"
    let defaultWorkspaceName = "Default workspace"
    let defaultWorkspaceDesc = "The default workspace"
    let cloudKitContainerId = "iCloud.com.estoapps.ios.restor"
    
    init() {
        self.bootstrap()
    }
    
    init(containerName: String) {
        self.containerName = containerName
        self.bootstrap()
    }
    
    func bootstrap() {
        let desc = self.persistentContainer.persistentStoreDescriptions.first
        desc?.type = self.storeType
        self.setup()
    }
    
    func setup(storeType: String = NSSQLiteStoreType, completion: (() -> Void)? = nil) {
        if (self.persistentContainer.persistentStoreCoordinator.persistentStores.firstIndex(where: { store -> Bool in store.type == storeType })) != nil {
            completion?()
        } else {
            self.storeType = storeType
            self.loadPersistentStore { completion?() }
        }
    }
    
    private func loadPersistentStore(completion: @escaping () -> Void) {
        // Handle data migration on a different thread / queue
        self.persistentContainer.loadPersistentStores { description, error  in
            guard error == nil else { fatalError("Unable to load store \(error!)") }
            self.persistentContainer.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            completion()
        }
    }
    
    private func getMainMOC(ctx: NSManagedObjectContext?) -> NSManagedObjectContext {
        if ctx != nil { return ctx! }
        return self.mainMOC
    }
    
    private func getBgMOC(ctx: NSManagedObjectContext?) -> NSManagedObjectContext {
        if ctx != nil { return ctx! }
        return self.bgMOC
    }
    
    /// Returns a child managed object context.
    func getChildMOC() -> NSManagedObjectContext {
        let moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        moc.parent = self.mainMOC
        moc.automaticallyMergesChangesFromParent = true
        moc.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return moc
    }
    
    func workspaceId() -> String {
        return "\(RecordType.prefix(for: .workspace))\(self.utils.genRandomString())"
    }
    
    func projectId() -> String {
        return "\(RecordType.prefix(for: .project))\(self.utils.genRandomString())"
    }
    
    func requestId() -> String {
        return "\(RecordType.prefix(for: .request))\(self.utils.genRandomString())"
    }
    
    func requestBodyDataId() -> String {
        return "\(RecordType.prefix(for: .requestBodyData))\(self.utils.genRandomString())"
    }
    
    func requestDataId() -> String {
        return "\(RecordType.prefix(for: .requestData))\(self.utils.genRandomString())"
    }
    
    func requestMethodDataId() -> String {
        return "\(RecordType.prefix(for: .requestMethodData))\(self.utils.genRandomString())"
    }
    
    func requestMethodDataId(_ projId: String, methodName: String) -> String {
        return "\(RecordType.prefix(for: .requestMethodData))\(projId)-\(methodName)"
    }
    
    func fileId() -> String {
        return "\(RecordType.prefix(for: .file))\(self.utils.genRandomString())"
    }
    
    func fileId(_ data: Data) -> String {
        return  "\(RecordType.prefix(for: .file))\(self.utils.md5(data: data))"
    }
    
    func imageId() -> String {
        return "\(RecordType.prefix(for: .image))\(self.utils.genRandomString())"
    }
    
    func imageId(_ data: Data) -> String {
        return "\(RecordType.prefix(for: .image))\(self.utils.md5(data: data))"
    }
    
    func historyId() -> String {
        return "\(RecordType.prefix(for: .history))\(self.utils.genRandomString())"
    }
    
    func envId() -> String {
        return "\(RecordType.prefix(for: .env))\(self.utils.genRandomString())"
    }
    
    func envVarId() -> String {
        return "\(RecordType.prefix(for: .envVar))\(self.utils.genRandomString())"
    }
    
    // MARK: - Sort
    
    /// Sort the given list of dictonaries in the order of created and update the index property.
    func sortByCreated(_ hm: inout [[String: Any]]) {
        hm.sort { (hma, hmb) -> Bool in
            if let c1 = hma["created"] as? Int64, let c2 = hmb["created"] as? Int64 { return c1 < c2 }
            return false
        }
    }
    
    /// Sort the given list of entities in the order of created and update the index property.
    func sortByCreated(_ xs: inout [Entity]) {
        xs.sort { (a, b) -> Bool in a.getCreated() < b.getCreated() }
    }
    
    func sortedByCreated(_ xs: [[String: Any]]) -> [[String: Any]] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    func sortedByCreated(_ xs: [Entity]) -> [Entity] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    // MARK: - To dictionary
    
    /// Can be used to get the initial value of the request before modification during edit.
    func requestToDictionary(_ x: ERequest) -> [String: Any] {
        let attrs = ERequest.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.headers, let xs = set.allObjects as? [ERequestData] {
            dict["headers"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let set = x.params, let xs = set.allObjects as? [ERequestData] {
            dict["params"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let body = x.body { dict["body"] = self.requestBodyDataToDictionary(body) }
        return dict
    }
    
    func requestMethodDataToDictionary(_ x: ERequestMethodData) -> [String: Any] {
        let attrs = ERequestMethodData.entity().attributesByName.map { arg -> String in arg.key }
        return x.dictionaryWithValues(forKeys: attrs)
    }
    
    func requestDataToDictionary(_ x: ERequestData) -> [String: Any] {
        let attrs = ERequestData.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.files, let xs = set.allObjects as? [EFile] {
            dict["files"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.fileToDictionary(y) })
        }
        if let image = x.image { dict["image"] = self.imageToDictionary(image) }
        return dict
    }
    
    func requestBodyDataToDictionary(_ x: ERequestBodyData) -> [String: Any] {
        let attrs = ERequestBodyData.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.form, let xs = set.allObjects as? [ERequestData] {
            dict["form"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let set = x.multipart, let xs = set.allObjects as? [ERequestData] {
            dict["multipart"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let binary = x.binary { dict["binary"] = self.requestDataToDictionary(binary) }
        return dict
    }
    
    func fileToDictionary(_ x: EFile) -> [String: Any] {
        let attrs = EFile.entity().attributesByName.compactMap { arg -> String? in
            if arg.key != "data" { return arg.key }  // The data is avoided to reduce memory footprint
            return nil
        }
        return x.dictionaryWithValues(forKeys: attrs)
    }
    
    func imageToDictionary(_ x: EImage) -> [String: Any] {
        let attrs = EImage.entity().attributesByName.compactMap { arg -> String? in
            if arg.key != "data" { return arg.key }
            return nil
        }
        let dict = x.dictionaryWithValues(forKeys: attrs)
        return dict
    }
    
    // MARK: - Get
    
    /// Get managed object with the given object Id with the given context.
    /// - Parameters:
    ///   - moId: The managed object Id of the entity.
    ///   - context: The managed object context used to access.
    /// - Returns: The managed object.
    func getManagedObject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> NSManagedObject {
        return context.object(with: moId)
    }
    
    /// Returns a fetch results controller with the given entity type.
    /// - Parameters:
    ///   - obj: The entity type.
    ///   - predicate: An optional fetch predicate.
    ///   - ctx: The managed object context.
    /// - Returns: The fetch results controller.
    func getFetchResultsController(obj: Entity.Type, predicate: NSPredicate? = nil, sortDesc: [NSSortDescriptor]? = nil, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        let moc = self.getMainMOC(ctx: ctx)
        var frc: NSFetchedResultsController<NSFetchRequestResult>!
        moc.performAndWait {
            let fr = obj.fetchRequest()
            if sortDesc != nil {
                fr.sortDescriptors = sortDesc!
            } else {
                fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            }
            if let x = predicate {
                fr.predicate = x
            } else {
                fr.predicate = NSPredicate(format: "markForDelete == %hhd AND name != %@", false, "")
            }
            fr.fetchBatchSize = self.fetchBatchSize
            frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        }
        return frc
    }
        
    /// Updates the given fetch results controller predicate.
    /// - Parameters:
    ///   - frc: The fetch results controller.
    ///   - predicate: A fetch predicate.
    ///   - ctx: The managed object context.
    /// - Returns: The fetch results controller.
    func updateFetchResultsController(_ frc: NSFetchedResultsController<NSFetchRequestResult>, predicate: NSPredicate, ctx: NSManagedObjectContext = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        ctx.performAndWait { frc.fetchRequest.predicate = predicate }
        return frc
    }
    
    func getEntity(recordType: RecordType, id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Entity? {
        let moc = self.getMainMOC(ctx: ctx)
        switch recordType {
        case .workspace:
            return self.getWorkspace(id: id, ctx: moc)
        case .project:
            return self.getProject(id: id, ctx: moc)
        case .request:
            return self.getRequest(id: id, ctx: moc)
        case .requestData:
            return self.getRequestData(id: id, ctx: moc)
        case .requestBodyData:
            return self.getRequestBodyData(id: id, ctx: moc)
        case .requestMethodData:
            return self.getRequestMethodData(id: id, ctx: moc)
        case .file:
            return self.getFileData(id: id, ctx: moc)
        case .image:
            return self.getImageData(id: id, ctx: moc)
        default:
            return nil
        }
    }
    
    // MARK: EWorkspace
    
    func getWorkspace(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EWorkspace? {
        var x: EWorkspace?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Returns workspaces list batched or as per the given offset and limit.
    /// - Parameters:
    ///   - offset: The start index to begin with
    ///   - limit: The maximum number of results to fetch
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context
    /// - Returns: A list of workspaces
    func getAllWorkspaces(offset: Int? = 0, limit: Int? = 0, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EWorkspace] {
        var xs: [EWorkspace] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            if includeMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", includeMarkForDelete!) }
            var shouldFetchInBatch = true
            if let _offset = offset { fr.fetchOffset = _offset; shouldFetchInBatch = false }
            if let _limit = limit { fr.fetchLimit = _limit; shouldFetchInBatch = false }
            if shouldFetchInBatch { fr.fetchBatchSize = self.fetchBatchSize }
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return xs
    }
    
    func getWorkspaces(offset: Int? = 0, limit: Int? = 0, includeMarkForDelete: Bool? = false, completion: @escaping (Result<[EWorkspace], Error>) -> Void, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        var xs: [EWorkspace] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.perform {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            if includeMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", includeMarkForDelete!) }
            if let _offset = offset { fr.fetchOffset = _offset }
            if let _limit = limit { fr.fetchLimit = _limit }
            do {
                xs = try moc.fetch(fr)
                completion(.success(xs))
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Returns the total count of workspaces
    /// - Parameters:
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context
    /// - Returns: The count of workspaces
    func getWorkspaceCount(includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            if includeMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", includeMarkForDelete!) }
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return x
    }
    
    /// Default entities will have the id `default`.
    func getDefaultWorkspace(with project: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EWorkspace {
        var x: EWorkspace!
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let ws = self.getWorkspace(id: self.defaultWorkspaceId) {
                x = ws
            } else {
                // We create the default workspace with active flag as false. Only if any change by the user gets made, the flag is enabled. This helps in syncing from cloud.
                let ws: EWorkspace! = self.createWorkspace(id: self.defaultWorkspaceId, name: self.defaultWorkspaceName, desc: self.defaultWorkspaceDesc, isSyncEnabled: true, isActive: false, ctx: moc)
                self.saveMainContext()
                if let isProj = project, isProj {
                    ws.projects = NSSet()
                    ws.projects!.adding(self.getDefaultProject(ctx: ctx) as Any)
                }
                x = ws
            }
        }
        return x
    }
    
    // MARK: EProject
    
    func getProject(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EProject? {
        var x: EProject?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the project at the given index in the workspace.
    /// - Parameters:
    ///   - index: The project index.
    ///   - wsId: The workspace id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The project.
    func getProject(at index: Int, wsId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EProject? {
        var x: EProject?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "workspace.id == %@", wsId) : NSPredicate(format: "workspace.id == %@ AND markForDelete == %hhd", wsId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting entities - \(error)")
            }
        }
        return x
    }
    
    /// Get project with the given managed object Id with the given context.
    /// - Parameters:
    ///   - moId: The managed object Id of the entity.
    ///   - context: The managed object context used to access.
    /// - Returns: The project.
    func getProject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> EProject? {
        return context.object(with: moId) as? EProject
    }
    
    /// Retrieves the projects belonging to the given workspace.
    /// - Parameters:
    ///   - wsId: The workspace id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of projects.
    func getProjects(wsId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "workspace.id == %@", wsId) : NSPredicate(format: "workspace.id == %@ AND markForDelete = %hhd", wsId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entities - \(error)")
            }
        }
        return xs
    }
    
    func getDefaultProject(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EProject {
        var x: EProject!
        let ctx = self.getMainMOC(ctx: ctx)
        ctx.performAndWait {
            if let proj = self.getProject(id: "default", ctx: ctx) { x = proj; return }
            x = self.createProject(id: "default", wsId: self.defaultWorkspaceId, name: "default", desc: "The default project", ctx: ctx)
        }
        return x
    }
    
    func getProjectsToSync(wsId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "isSynced == %hhd AND workspace.id == %@", false, wsId)
                : NSPredicate(format: "isSynced == %hhd AND workspace.id == %@ AND markForDelete == %hhd", false, wsId, includeMarkForDelete!)
            fr.fetchBatchSize = 4
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching projects yet to sync: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequest
    
    func getRequest(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequest? {
        var x: ERequest?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
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
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of requests.
    func getRequests(projectId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequest] {
        var xs: [ERequest] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projectId): NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
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
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request.
    func getRequest(at index: Int, projectId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequest? {
        var x: ERequest?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projectId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the total requests count in the given project
    /// - Parameters:
    ///   - projectId: The project id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of requests.
    func getRequestsCount(projectId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = includeMarkForDelete == nil ?  NSPredicate(format: "project.id == %@", projectId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, includeMarkForDelete!)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
            }
        }
        return x
    }
    
    // MARK: ERequestData
    
    func getRequestData(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestReferenceKey(_ reqDataType: RequestDataType) -> String {
        switch reqDataType {
        case .header:
            return "header.id"
        case .param:
            return "param.id"
        case .form:
            return "form.request.id"
        case .multipart:
            return "multipart.request.id"
        case .binary:
            return "binary.request.id"
        }
    }
    
    func getRequestData(at index: Int, reqId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    func getLastRequestData(type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "type == %d", _type) : NSPredicate(format: "type == %d AND markForDelete == %hhd", _type, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Get the total request data count of the given type belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - type: The request data type.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of request data entities.
    func getRequestDataCount(reqId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, includeMarkForDelete!)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve form data for the given request body.
    /// - Parameters:
    ///   - bodyDataId: The request body data id.
    ///   - type: The request data type.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request body data object.
    /// - Returns: A list of request data entities.
    func getFormRequestData(_ bodyDataId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            let relKey: String = {
                switch type {
                case .form:
                    return "form.id"
                case .multipart:
                    return "multipart.id"
                case .binary:
                    return "binary.id"
                default:
                    return "form.id"
                }
            }()
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "%K == %@ AND type == %d", relKey, bodyDataId, _type)
                : NSPredicate(format: "%K == %@ AND type == %d AND markForDelete == %hhd", relKey, bodyDataId, _type, includeMarkForDelete!)  // ERequestBodyData.id
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
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
    ///   - type: The request data type (form, multipart)
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request data entity.
    func getFormRequestData(at index: Int, bodyDataId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC)
        -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey: String = {
                if type == .form {
                    return "form.id"
                }
                return "multipart.id"
            }()
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "%K == %@ AND type == %d", typeKey, bodyDataId, _type)
                : NSPredicate(format: "%K == %@ AND type == %d AND markForDelete == %hhd", typeKey, bodyDataId, _type, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves the headers belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getHeadersRequestData(_ reqId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "header.id == %@", reqId) : NSPredicate(format: "header.id == %@ AND markForDelete == %hhd", reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching headers request data: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the params belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getParamsRequestData(_ reqId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "param.id == %@", reqId) : NSPredicate(format: "param.id == %@ AND markForDelete == %hhd", reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching params request data: \(error)")
            }
        }
        return xs
    }
    
    func getRequestData(reqId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves request data marked for delete for a request
    /// - Parameters:
    ///   - reqId: The request Id
    ///   - type: The request data type
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getRequestDataMarkedForDelete(reqId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let type = self.getRequestReferenceKey(type)
            fr.predicate = NSPredicate(format: "%K == %@ AND markForDelete == %hhd", type, reqId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequestMethodData
    
    /// Retrieve the request method data for the given id.
    /// - Parameters:
    ///   - id: The request method data id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request method data entity.
    func getRequestMethodData(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieves request method data belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request method data entities.
    func getRequestMethodData(reqId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "request.id == %@", reqId) : NSPredicate(format: "request.id == %@ AND markForDelete == %hhd", reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves request method data belonging to the given project.
    /// - Parameters:
    ///   - projId: The project id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request method data entities.
    func getRequestMethodData(projId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieve the request method data.
    /// - Parameters:
    ///   - index: The index of the method.
    ///   - projId: The project id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request method data entity.
    func getRequestMethodData(at index: Int, projId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projId): NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting request method data: \(error)")
            }
        }
        return x
    }
    
    /// Get the count for requests with the given request method data selected.
    /// - Parameters:
    ///   - projId: The project Id under which the requests belongs to.
    ///   - index: The method index which will be the selected method index in the request.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of entities.
    func getRequestsCountForRequestMethodData(projId: String, index: Int64? = Const.defaultRequestMethodsCount.toInt64(), includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "selectedMethodIndex == %ld AND project.id == %@", index!, projId)
                : NSPredicate(format: "selectedMethodIndex == %ld AND markForDelete == %hhd AND project.id == %@", index!, includeMarkForDelete!, projId)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting getting request count for the method: \(error)")
            }
        }
        return x
    }
    
    func genDefaultRequestMethods(_ proj: EProject, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestMethodData] {
        let names = ["GET", "POST", "PUT", "PATCH", "DELETE"]
        return names.enumerated().compactMap { seq -> ERequestMethodData? in
            let elem = seq.element
            let idx = seq.offset
            if let x = self.createRequestMethodData(id: self.requestMethodDataId(proj.getId(), methodName: elem), wsId: proj.getWsId(), name: elem, isCustom: false, ctx: ctx) {
                x.created = proj.getCreated() - 6 + idx.toInt64()
                x.modified = x.created
                x.changeTag = x.created
                x.project = proj
                return x
            }
            return nil
        }
    }
    
    func getRequestMethodDataMarkedForDelete(projId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequestBodyData
    
    func getRequestBodyData(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    // MARK: EFile
    
    /// Get the total number of files in the given request data.
    /// - Parameters:
    ///   - reqDataId: The request data id.
    ///   - type: The `RequestDataType` indicating whether it is a `file` or a `multipart`
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request data.
    /// - Returns: The count of files.
    func getFilesCount(_ reqDataId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            let _type = type.rawValue.toInt32()
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@ AND type == %d", reqDataId, _type)
                : NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hdd", reqDataId, _type, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
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
    ///   - type: The `RequestDataType` indicating whether it is a `file` or a `multipart`
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request data.
    /// - Returns: A list of file entities.
    func getFiles(_ reqDataId: String, type: RequestDataType, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            let _type = type.rawValue.toInt32()
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hhd", reqDataId, _type)
                : NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hhd", reqDataId, type.rawValue.toInt32(), includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
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
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The file entity.
    func getFile(at index: Int, reqDataId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EFile? {
        var x: EFile?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@", reqDataId)
                : NSPredicate(format: "requestData.id == %@ AND markForDelete == %hhd", reqDataId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve file object for the given file id.
    /// - Parameters:
    ///   - id: The file object id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The file entity.
    func getFileData(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EFile? {
        var x: EFile?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = includeMarkForDelete == nil ?  NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching file: \(error)")
            }
        }
        return x
    }
    
    func getFilesMarkedForDelete(reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData == %@ AND markForDelete == %hhd", reqDataId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: EImage
    
    /// Retrieve image object for the given image id.
    /// - Parameters:
    ///   - id: The image object id.
    ///   - includeMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The image entity.
    func getImageData(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EImage? {
        var x: EImage?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EImage>(entityName: "EImage")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching image: \(error)")
            }
        }
        return x
    }
    
    // MARK: EHistory
    
    func getHistory(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EHistory? {
        var x: EHistory?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EHistory>(entityName: "EHistory")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching history: \(error)")
            }
        }
        return x
    }
    
    func getLatestHistory(reqId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EHistory? {
        var x: EHistory?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EHistory>(entityName: "EHistory")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "requestId == %@", reqId)
                : NSPredicate(format: "requestId == %@ AND markForDelete == %hhd", reqId, includeMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching latest history: \(error)")
            }
        }
        return x
    }
    
    // MARK: EEnv
    
    func getEnv(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EEnv? {
        var x: EEnv?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching env: \(error)")
            }
        }
        return x
    }

    func getEnvs(includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EEnv] {
        var xs: [EEnv] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            if includeMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hhd", includeMarkForDelete!) }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting envs: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves envs belonging to the given workspace.
    func getEnvs(wsId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EEnv] {
        var xs: [EEnv] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            if includeMarkForDelete != nil {
                fr.predicate = NSPredicate(format: "markForDelete == %hhd AND wsId == %@", includeMarkForDelete!, wsId)
            } else {
                fr.predicate = NSPredicate(format: "wsId == %@", wsId)
            }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting envs: \(error)")
            }
        }
        return xs
    }
    
    // MARK: EEnvVar
    
    func getEnvVar(id: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnvVar>(entityName: "EEnvVar")
            fr.predicate = includeMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, includeMarkForDelete!)
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching env: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves env variables belonging to the given env.
    func getEnvVars(envId: String, includeMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> [EEnvVar] {
        var xs: [EEnvVar] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnvVar>(entityName: "EEnvVar")
            if includeMarkForDelete != nil {
                fr.predicate = NSPredicate(format: "env.id == %@ AND markForDelete == %hhd", envId, includeMarkForDelete!)
            } else {
                fr.predicate = NSPredicate(format: "env.id == %@", envId)
            }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting env vars: \(error)")
            }
        }
        return xs
    }
    
    // MARK: - Entities to sync
    
    func getWorkspacesToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<EWorkspace> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
        fr.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "isSynced == %hhd AND isActive == %hhd AND isZoneSynced == %hhd", false, true, true),
            NSPredicate(format: "isActive == %hhd AND isZoneSynced == %hhd", true, false)  // ws synced but zone did not get created
        ])
        fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getProjectsToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<EProject> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<EProject>(entityName: "EProject")
        fr.predicate = NSPredicate(format: "isSynced == %hhd AND markForDelete == %hhd", false, false)  // Deleted items will be fetched separately
        fr.sortDescriptors = [NSSortDescriptor(key: "workspace.created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: "workspace.created", cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getRequestsToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<ERequest> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
        fr.predicate = NSPredicate(format: "isSynced == %hhd AND markForDelete == %hhd", false, false)
        fr.sortDescriptors = [NSSortDescriptor(key: "project.created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: "project.created", cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getHistoriesToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<EHistory> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<EHistory>(entityName: "EHistory")
        fr.predicate = NSPredicate(format: "isSynced == %hhd AND markForDelete == %hhd", false, false)
        fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: "created", cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getEnvsToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<EEnv> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
        fr.predicate = NSPredicate(format: "isSynced == %hhd AND markForDelete == %hhd", false, false)
        fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: "created", cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getEnvVarsToSync(ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<EEnvVar> {
        let moc = self.getMainMOC(ctx: ctx)
        let fr = NSFetchRequest<EEnvVar>(entityName: "EEnvVar")
        fr.predicate = NSPredicate(format: "isSynced == %hhd AND markForDelete == %hhd", false, false)
        fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
        fr.fetchBatchSize = self.fetchBatchSize
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: "created", cacheName: nil)
        do {
            try frc.performFetch()
        } catch let error {
            Log.error("Error performing fetch: \(error)")
        }
        return frc
    }
    
    func getDataMarkedForDelete(obj: Entity.Type, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        let moc = self.getMainMOC(ctx: ctx)
        var frc: NSFetchedResultsController<NSFetchRequestResult>!
        moc.performAndWait {
            let fr = obj.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.predicate = NSPredicate(format: "markForDelete == %hhd", true)
            fr.fetchBatchSize = self.fetchBatchSize
            frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
            do {
                try frc.performFetch()
            } catch let error {
                Log.error("Error performing fetch: \(error)")
            }
        }
        return frc
    }
    
    // MARK: - Create
    
    /// Create workspace.
    /// - Parameters:
    ///   - id: The workspace id.
    ///   - name: The workspace name.
    ///   - desc: The workspace description.
    ///   - isSyncEnabled: Is syncing with iCloud enabled.
    ///   - isActive: Is the workspace active (applies to default workspace only).
    ///   - checkExists: Check whether the workspace exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A workspace.
    func createWorkspace(id: String, name: String, desc: String, isSyncEnabled: Bool, isActive: Bool? = true, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC)  -> EWorkspace? {
        var x: EWorkspace?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExist = checkExists, isExist, let ws = self.getWorkspace(id: id, ctx: ctx) { x = ws }
            let ws = x != nil ? x! : EWorkspace(context: moc)
            ws.id = id
            ws.name = name
            ws.desc = desc
            ws.isActive = isActive!
            ws.isSyncEnabled = isSyncEnabled
            if !isSyncEnabled { ws.syncDisabled =  ts }
            ws.created = x == nil ? ts : x!.created
            ws.modified = ts
            ws.changeTag = ts
            ws.version = x == nil ? 0 : x!.version
            x = ws
        }
        return x
    }
    
    func setWorkspaceActive(_ wsId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let ws = self.getWorkspace(id: wsId, ctx: ctx)
            ws?.isActive = true
            do {
                if !AppState.isRequestEdit { try moc.save() }
            } catch let error {
                Log.error("Error saving workspace with active flag set: \(error)")
            }
        }
    }
    
    func setWorkspaceSyncEnabled(_ state: Bool, ws: EWorkspace, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        let ts = Date().currentTimeNanos()
        moc.performAndWait {
            if !state { ws.syncDisabled = ts }
            ws.modified = ts
            ws.changeTag = ts
            ws.isSyncEnabled = state
            do {
                if !AppState.isRequestEdit {  try moc.save() }
            } catch let error {
                Log.error("Error saving workspace with active flag set: \(error)")
            }
        }
    }
    
    /// Create project.
    /// - Parameters:
    ///   - id: The project id.
    ///   - wsId: The workspace id.
    ///   - name: The project name.
    ///   - desc: The project description.
    ///   - ws: The workspace to which the project belongs.
    ///   - checkExists: Check if the given project exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A project.
    func createProject(id: String, wsId: String, name: String, desc: String, ws: EWorkspace? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EProject? {
        var x: EProject?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExist = checkExists, isExist, let proj = self.getProject(id: id, ctx: ctx) { x = proj }
            let proj = x != nil ? x! : EProject(context: moc)
            proj.id = id
            proj.wsId = wsId
            proj.name = name
            proj.desc = desc
            proj.created = x == nil ? ts : x!.created
            proj.modified = ts
            proj.changeTag = ts
            proj.version = x == nil ? 0 : x!.version
            _ = self.genDefaultRequestMethods(proj, ctx: moc)
            ws?.addToProjects(proj)
            ws?.isActive = true
            x = proj
        }
        return x
    }
    
    /// Create a request
    /// - Parameters:
    ///   - id: The request Id.
    ///   - wsId: The workspace Id.
    ///   - name: The name of the request.
    ///   - project: The project to which the request belongs to.
    ///   - checkExists: Check if the request exists before creating one.
    ///   - ctx: The managed object context.
    /// - Returns: A request.
    func createRequest(id: String, wsId: String, name: String, project: EProject? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequest? {
        var x: ERequest?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let req = self.getRequest(id: id, ctx: ctx) { x = req }
            let req = x != nil ? x! : ERequest(context: moc)
            req.id = id
            req.wsId = wsId
            req.name = name
            req.created = x == nil ? ts : x!.created
            req.modified = ts
            req.changeTag = ts
            req.version = x == nil ? 0 : x!.version
            project?.addToRequests(req)
            x = req
        }
        return x
    }
        
    /// Create request data.
    /// - Parameters:
    ///   - id: The request data Id.
    ///   - wsId: The workspace Id.
    ///   - type: The request data type.
    ///   - fieldFormat: The request body form field format.
    ///   - checkExists: Check for existing request data object.
    ///   - ctx: The managed object context.
    /// - Returns: A request data.
    func createRequestData(id: String, wsId: String, type: RequestDataType, fieldFormat: RequestBodyFormFieldFormatType, checkExists: Bool? = true,
                           ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestData? {
        var x: ERequestData?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestData(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            data.fieldFormat = fieldFormat.rawValue.toInt64()
            data.type = type.rawValue.toInt64()
            x = data
            Log.debug("RequestData \(x == nil ? "created" : "updated"): \(x!)")
        }
        return x
    }
    
    /// Create request method data.
    /// - Parameters:
    ///   - id: The request method data Id.
    ///   - wsId: The workspace Id.
    ///   - name: The name of the request method data.
    ///   - isCustom: If the request method is user created.
    ///   - checkExists: Check if the request method data exists.
    ///   - ctx: The managed object context.
    /// - Returns: A request method data.
    func createRequestMethodData(id: String, wsId: String, name: String, isCustom: Bool? = true, checkExists: Bool? = true,
                                 ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestMethodData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestMethodData(context: moc)
            data.id = id
            data.wsId = wsId
            data.isCustom = isCustom ?? true
            data.name = name
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    /// Create request body data.
    /// - Parameters:
    ///   - id: The request body data Id.
    ///   - wsId: The workspace Id.
    ///   - checkExists: Check if the request body data exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A request body data.
    func createRequestBodyData(id: String, wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestBodyData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestBodyData(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    /// Create an image object with the given image data.
    /// - Parameters:
    ///   - data: The image data.
    ///   - wsId: The workspace Id.
    ///   - name: The image name.
    ///   - type: The image type (png, jpg, etc.).
    ///   - checkExists: Check if the image exists already before creating.
    ///   - ctx: The managed object context.
    /// - Returns: An image entity.
    func createImage(imageId: String? = CoreDataService.shared.imageId(), data: Data, wsId: String, name: String, type: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EImage? {
        var x: EImage?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getImageData(id: imageId!, ctx: ctx) { x = data }
            let image = x != nil ? x! : EImage(context: moc)
            image.id = imageId!
            image.wsId = wsId
            image.data = data
            image.name = name
            image.type = type
            image.created = x == nil ? ts : x!.created
            image.modified = ts
            image.changeTag = ts
            image.version = x == nil ? 0 : x!.version
            x = image
        }
        return x
    }
    
    func createFile(data: Data, wsId: String, name: String, path: URL, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EFile? {
        return self.createFile(data: data, wsId: wsId, name: name, path: path, type: .form, checkExists: checkExists, ctx: ctx)
    }
    
    func createFile(fileId: String? = CoreDataService.shared.fileId(), data: Data, wsId: String, name: String, path: URL, type: RequestDataType, checkExists: Bool? = true,
                    ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EFile? {
        var x: EFile?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getFileData(id: fileId!, ctx: ctx) { x = data }
            let file = x != nil ? x! : EFile(context: moc)
            file.id = fileId!
            file.wsId = wsId
            file.data = data
            file.created = x == nil ? ts : x!.created
            file.modified = ts
            file.changeTag = ts
            file.name = name
            file.path = path
            file.type = type.rawValue.toInt64()
            file.version = x == nil ? 0 : x!.version
            x = file
        }
        return x
    }
    
    func createHistory(id: String, requestId: String, wsId: String, request: String, responseData: Data?, responseHeaders: Data?, statusCode: Int64, elapsed: Int64,
                       responseBodyBytes: Int64, url: String, method: String, isSecure: Bool, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EHistory? {
        var x: EHistory?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getHistory(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : EHistory(context: moc)
            data.id = id
            data.wsId = wsId
            data.requestId = requestId
            data.request = request
            data.responseData = responseData
            data.responseHeaders = responseHeaders
            data.statusCode = statusCode
            data.elapsed = elapsed
            data.responseBodyBytes = responseBodyBytes
            data.url = url
            data.method = method
            data.isSecure = isSecure
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    func createHistory(id: String, wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EHistory? {
        var x: EHistory?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getHistory(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : EHistory(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    func createEnv(name: String, envId: String? = CoreDataService.shared.envId(), wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EEnv? {
        var x: EEnv?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getEnv(id: envId!, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnv(context: moc)
            data.id = envId
            data.wsId = wsId
            data.name = name
            data.created = x == nil ? ts: x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }

    func createEnvVar(name: String, value: String, id: String? = CoreDataService.shared.envVarId(), checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let envVarId = id == nil ? self.envVarId() : id!
            if let isExists = checkExists, isExists, let data = self.getEnvVar(id: envVarId, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnvVar(context: moc)
            data.id = envVarId
            data.name = name
            data.value = value as NSString
            data.created = x == nil ? ts: x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    func createEnvVar(id: String? = CoreDataService.shared.envVarId(), checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let ts = Date().currentTimeNanos()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let envVarId = id == nil ? self.envVarId() : id!
            if let isExists = checkExists, isExists, let data = self.getEnvVar(id: envVarId, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnvVar(context: moc)
            data.id = envVarId
            data.created = x == nil ? ts: x!.created
            data.modified = ts
            data.changeTag = ts
            data.version = x == nil ? 0 : x!.version
            x = data
        }
        return x
    }
    
    // MARK: - Save
    
    func saveMainContext(_ callback: ((Bool) -> Void)? = nil) {
        Log.debug("save main context")
        if AppState.isRequestEdit { Log.debug("Edit request in progress. Skipping main context save."); callback?(false); return }
        self.mainMOC.perform {
            do {
                if !self.mainMOC.hasChanges { Log.debug("main context does not have changes"); callback?(true); return }
                Log.debug("main context has changes")
                try self.mainMOC.save()
                self.mainMOC.processPendingChanges()
                Log.debug("main context saved")
                callback?(true)
            } catch {
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(false)
                return
            }
        }
    }
    
    /// Save the managed object context associated with the given entity and remove it from the cache.
    func saveBackgroundContext(isForce: Bool? = false, callback: ((Bool) -> Void)? = nil) {
        Log.debug("save bg context")
        var status = true
        let isForceSave = isForce ?? false
        let fn: () -> Void = {
            do {
                Log.debug("bg context has changes")
                try self.bgMOC.save()
                self.bgMOC.processPendingChanges()
                callback?(true)
            } catch {
                status = false
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(status)
                return
            }
        }
        isForceSave ? self.bgMOC.performAndWait { fn() } : self.bgMOC.perform { fn() }
    }
    
    func saveChildContext(_ ctx: NSManagedObjectContext) {
        ctx.performAndWait {
            do {
                try ctx.save()
                self.saveBackgroundContext(isForce: true)
            } catch let error { Log.error("Error saving child context: \(error)") }
        }
    }
        
    // MARK: - Delete
    
    func markEntityForDelete(_ entity: Entity?, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        guard let entity = entity else { return }
        entity.setMarkedForDelete(true)
        if entity.getChangeTag() > AppState.editRequestSaveTs { self.deleteEntity(entity); return }
        let ts = Date().currentTimeNanos()
        entity.setModified(ts)
        entity.setChangeTag(ts)
    }
    
    /// Resets the context to its base state if there are any changes.
    func discardChanges(in context: NSManagedObjectContext) {
        if context.hasChanges { context.performAndWait { context.rollback() } }
    }
    
    /// Discard changes to the given entity in the managed object context.
    /// - Parameters:
    ///   - entity: The managed object
    ///   - context: The managed object context.
    func discardChanges(for entity: NSManagedObject, inContext context: NSManagedObjectContext) {
        context.performAndWait { context.refresh(entity, mergeChanges: false) }
    }
    
    func discardChanges(for ids: Set<EditRequestInfo>, inContext context: NSManagedObjectContext) {
        Log.debug("Discard changes for: \(ids)")
        context.performAndWait {
            ids.toArray().forEach { info in
                let elem = self.getManagedObject(moId: info.moID, withContext: context)
                Log.debug("discard changes in obj: \(elem)")
                self.discardChanges(for: elem, inContext: context)
            }
        }
    }
    
    func deleteEntity(_ entity: NSManagedObject?, ctx: NSManagedObjectContext? = nil) {
        if let x = entity, let moc = ctx != nil ? ctx! : x.managedObjectContext {
            moc.performAndWait { moc.delete(x) }
        }
    }
    
    func deleteWorkspace(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getWorkspace(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteProject(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getProject(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteRequest(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getRequest(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteRequestBodyData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getRequestBodyData(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteRequestData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getRequestData(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteRequestMethodData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getRequestMethodData(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteFileData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getFileData(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteImageData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getImageData(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteHistory(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getHistory(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteEnv(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getEnv(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    func deleteEnvVar(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        self.deleteEntity(self.getEnvVar(id: id, includeMarkForDelete: nil, ctx: moc))
    }
    
    /// Delete the entity with the given id.
    /// - Parameters:
    ///   - dataId: The entity id. If the entity could be `RequestData` or `RequestBodyData`.
    ///   - req: The request to which the entity belongs.
    ///   - type: The entity type.
    ///   - ctx: The managed object context.
    func deleteRequestData(dataId: String, req: ERequest, type: RequestCellType, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            var x: Entity?
            switch type {
            case .header:
                x = self.getRequestData(id: dataId, includeMarkForDelete: nil, ctx: moc)
                if let y = x as? ERequestData { req.removeFromHeaders(y) }
            case .param:
                x = self.getRequestData(id: dataId, includeMarkForDelete: nil, ctx: ctx)
                if let y = x as? ERequestData { req.removeFromParams(y) }
            case .body:
                x = self.getRequestBodyData(id: dataId, includeMarkForDelete: nil, ctx: moc)
                if x != nil { req.body = nil }
            default:
                break
            }
            if let y = x { moc.delete(y) }
            Log.debug("Deleted data id: \(dataId)")
        }
    }
}
