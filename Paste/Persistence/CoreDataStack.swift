//
//  CoreDataStack.swift
//  Paste
//
//  CoreData stack management
//

import CoreData

class CoreDataStack {
    
    static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Persistent Container
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "PasteTool")
        
        // Configure store options.
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        // Enable remote change notifications & history for CloudKit sync.
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        if AppSettings.iCloudSyncEnabled {
            description?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Constants.iCloudContainerIdentifier
            )
        } else {
            description?.cloudKitContainerOptions = nil
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Unsigned/ad-hoc builds carry no iCloud entitlement, so a
                // CloudKit-configured store cannot load. Fall back to a local
                // store instead of taking the app down.
                if storeDescription.cloudKitContainerOptions != nil {
                    NSLog("CloudKit store load failed (\(error)); retrying without iCloud sync")
                    storeDescription.cloudKitContainerOptions = nil
                    container.loadPersistentStores { _, retryError in
                        if let retryError = retryError as NSError? {
                            fatalError("CoreData failed to load: \(retryError), \(retryError.userInfo)")
                        }
                    }
                } else {
                    fatalError("CoreData failed to load: \(error), \(error.userInfo)")
                }
            }
        }
        
        // Automatically merge changes from the persistent store.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Context
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Creates a private-queue background context.
    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Save
    
    func save() {
        let context = viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("CoreData save failed: \(error)")
        }
    }
    
    /// Performs a save on a background context.
    func saveInBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("CoreData background save failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Sync helpers
    
    /// Best-effort: trigger a save and let CloudKit container schedule pushes.
    /// - Parameter completion: Called on main queue with nil on success or the save error.
    func requestSyncNow(completion: ((Error?) -> Void)? = nil) {
        let context = viewContext
        context.perform {
            var saveError: Error?
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("CoreData syncNow save failed: \(error)")
                saveError = error
            }
            if let completion {
                DispatchQueue.main.async { completion(saveError) }
            }
        }
    }
}
