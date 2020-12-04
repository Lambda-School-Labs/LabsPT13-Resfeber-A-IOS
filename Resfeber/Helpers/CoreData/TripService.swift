//
//  TripService.swift
//  Resfeber
//
//  Created by Joshua Rutkowski on 12/4/20.
//  Copyright © 2020 Spencer Curtis. All rights reserved.
//

import Foundation
import CoreData

public final class TripService {
    // MARK: - Properties
    let managedObjectContext: NSManagedObjectContext
    let coreDataStack: CoreDataStack
    
    // MARK: - Initializers
    public init(managedObjectContext: NSManagedObjectContext, coreDataStack: CoreDataStack) {
        self.managedObjectContext = managedObjectContext
        self.coreDataStack = coreDataStack
    }
}

// MARK: - Public
extension TripService {
    @discardableResult
    public func add( name: String, image: Data?, startDate: Date?, endDate: Date? ) -> Trip {
        let trip = Trip(context: managedObjectContext)
        trip.name = name
        trip.image = image
        trip.startDate = startDate
        trip.endDate = endDate
        
        coreDataStack.saveContext(managedObjectContext)
        return trip
    }
    
    public func getTrips() -> [Trip]? {
        let tripFetch: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let results = try managedObjectContext.fetch(tripFetch)
            return results
        } catch let error as NSError {
            print("Fetch error: \(error) description: \(error.userInfo)")
        }
        return nil
    }
}
