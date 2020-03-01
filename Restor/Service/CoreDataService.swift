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
    
    // MARK: - Type conversion
    
    func toWorkspace(_ ws: RRWorkspace?) -> Workspace? {
        return nil
    }
    
    func toRRWorkspace(_ ws: Workspace?) -> RRWorkspace? {
        return nil
    }
    
    func toProject(_ proj: RRProject?) -> Project? {
        return nil
    }
    
    func toRRProject(_ proj: Project?) -> RRProject? {
        return nil
    }
    
    func toRequest(_ req: RRRequest) -> Request? {
        return nil
    }
    
    func toRRRequest(_ req: Request) -> RRRequest? {
        return nil
    }
    
    // MARK: - Get
    
    mutating func getRRWorkspace(_ id: String) -> RRWorkspace? {
        let fr = NSFetchRequest<RRWorkspace>(entityName: "RRWorkspace")
        fr.predicate = NSPredicate(format: "id == %@", id)
        do {
            let result = try self.bgMOC.fetch(fr)
            return result.first
        } catch let error {
            Log.error("Error fetching workspace: \(error)")
        }
        return nil
    }
    
    mutating func getRRProject(_ id: String) -> RRProject? {
        let fr = NSFetchRequest<RRProject>(entityName: "RRProject")
        fr.predicate = NSPredicate(format: "id == %@", id)
        do {
            let result = try self.bgMOC.fetch(fr)
            return result.first
        } catch let error {
            Log.error("Error fetching project: \(error)")
        }
        return nil
    }

    mutating func getRRRequest(_ id: String) -> RRRequest? {
        let fr = NSFetchRequest<RRRequest>(entityName: "RRRequest")
        fr.predicate = NSPredicate(format: "id == %@", id)
        do {
            let result = try self.bgMOC.fetch(fr)
            return result.first
        } catch let error {
            Log.error("Error fetching request: \(error)")
        }
        return nil
    }
    
    // MARK: - Create
    
    func createRRWorkspace(_ ws: Workspace?) -> RRWorkspace? {
        return nil
    }
    
    func createRRProject(_ proj: Project?) -> RRProject? {
        return nil
    }
    
    func createRRRequest(_ req: Request?) -> RRRequest? {
        return nil
    }
    
    // MARK: - Update
    
    func updateRRWorkspace(rrws: inout RRWorkspace, from ws: Workspace) {
        rrws.modified = ws.modified
        rrws.version = ws.version
        rrws.name = ws.name
        rrws.desc = ws.desc
    }
    
    func updateRRProject(rrproj: inout RRProject, from proj: Project) {
        rrproj.modified = proj.modified
        rrproj.version = proj.version
        rrproj.name = proj.name
        rrproj.desc = proj.desc
        if rrproj.requestMethods == nil {
            rrproj.requestMethods = NSSet()
        }
        rrproj.requestMethods?.addingObjects(from: proj.requestMethods)
        if rrproj.requests == nil {
            rrproj.requests = NSSet()
        }
        rrproj.requests?.addingObjects(from: proj.requests)
    }
    
    func updateRRRequest(rrreq: inout RRRequest, from req: Request) {
        rrreq.modified = req.modified
        rrreq.version = req.version
        rrreq.name = req.name
        rrreq.desc = req.desc
        rrreq.url = req.url
        // method
        if rrreq.methods == nil {
            rrreq.methods = NSSet()
        }
        rrreq.methods?.addingObjects(from: req.methods)
        // header
        if rrreq.headers == nil {
            rrreq.headers = NSSet()
        }
        rrreq.headers?.addingObjects(from: req.headers)
        // params
        if rrreq.params == nil {
            rrreq.params = NSSet()
        }
        rrreq.params?.addingObjects(from: req.params)
        // body
        if rrreq.body == nil && req.body != nil {
            rrreq.body = RRRequestBodyData(context: rrreq.managedObjectContext!)
        }
        if rrreq.body != nil && req.body != nil {
            self.updateRRRequestBodyData(rrreqBody: &rrreq.body!, reqBody: req.body!)
        }
        // project
        if rrreq.project == nil && req.project != nil {
            rrreq.project = RRProject(context: rrreq.managedObjectContext!)
        }
        if rrreq.project != nil && req.project != nil {
            self.updateRRProject(rrproj: &rrreq.project!, from: req.project!)
        }
    }
    
    func updateRRRequestBodyData(rrreqBody: inout RRRequestBodyData, reqBody: RequestBodyData) {
        
    }
    
    
    // MARK: - Save
    
    mutating func saveWorkspace(_ ws: Workspace) {
        if var rrws = self.getRRWorkspace(ws.id) {  // workspace already exists
            self.updateRRWorkspace(rrws: &rrws, from: ws)
            do {
                try rrws.managedObjectContext?.save()
            } catch let error {
                Log.error("Error saving workspace: \(error)")
            }
        } else {  // create new workspace
            
        }
    }
    
    mutating func saveProject(_ proj: Project) {
        if var rrproj = self.getRRProject(proj.id) {
            self.updateRRProject(rrproj: &rrproj, from: proj)
            do {
                try rrproj.managedObjectContext?.save()
            } catch let error {
                Log.error("Error saving project: \(error)")
            }
        } else {
            
        }
    }
    
    mutating func saveRequest(_ req: Request) {
        if var rrreq = self.getRRRequest(req.id) {
            self.updateRRRequest(rrreq: &rrreq, from: req)
            do {
                try rrreq.managedObjectContext?.save()
            } catch let error {
                Log.error("Error saving request: \(error)")
            }
        } else {
            
        }
    }
    
    // MARK: - Delete
    
    func deleteWorkspace() {
        
    }
    
    func deleteProject() {
        
    }
    
    func deleteRequest() {
        
    }
}
