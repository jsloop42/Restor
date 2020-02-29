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
    
    func saveWorkspace() {
        
    }
    
    func saveProject() {
        
    }
    
    func saveRequest() {
        
    }
    
    // MARK: - Delete
    
    func deleteWorkspace() {
        
    }
    
    func deleteProject() {
        
    }
    
    func deleteRequest() {
        
    }
}
