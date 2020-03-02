//
//  ERequest.swift
//  Restor
//
//  Created by jsloop on 03/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

class EFile: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class EImage: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class EProject: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class ERequest: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class ERequestBodyData: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class ERequestData: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class ERequestMethodData: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class ETag: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}

class EWorkspace: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        entity.properties.forEach { elem in
            if let prop = elem as? NSFetchedPropertyDescription {
                if let fr = prop.fetchRequest, let desc = fr.entity {
                    if desc.propertiesByName.keys.contains("created") {
                        let sortDesc = NSSortDescriptor(key: "created", ascending: true)  // so that elements are ordered as inserted
                        fr.sortDescriptors = [sortDesc]
                    }
                }
            }
        }
        super.init(entity: entity, insertInto: context)
    }
}
