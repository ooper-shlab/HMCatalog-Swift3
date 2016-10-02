/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `HomeKitObjectCollection` is a model object for the `HomeViewController`.
                It manages arrays of HomeKit objects.
*/

import HomeKit

/// Represents the all different types of HomeKit objects.
enum HomeKitObjectSection: Int {
    case accessory, room, zone, user, actionSet, trigger, serviceGroup
    
    static let count = 7
}

/**
    Manages internal lists of HomeKit objects to allow for
    save insertion into a table view.
*/
class HomeKitObjectCollection {
    // MARK: Properties
    
    var accessories = [HMAccessory]()
    var rooms = [HMRoom]()
    var zones = [HMZone]()
    var actionSets = [HMActionSet]()
    var triggers = [HMTrigger]()
    var serviceGroups = [HMServiceGroup]()
    
    /**
        Adds an object to the collection by finding its corresponding 
        array and appending the object to it.
    
        - parameter object: The HomeKit object to append.
    */
    func append(_ object: AnyObject) {
        switch object {
            case let actionSet as HMActionSet:
                actionSets.append(actionSet)
                actionSets = actionSets.sortByTypeAndLocalizedName()
                
            case let accessory as HMAccessory:
                accessories.append(accessory)
                accessories = accessories.sortByLocalizedName()
                
            case let room as HMRoom:
                rooms.append(room)
                rooms = rooms.sortByLocalizedName()
                
            case let zone as HMZone:
                zones.append(zone)
                zones = zones.sortByLocalizedName()
                
            case let trigger as HMTrigger:
                triggers.append(trigger)
                triggers = triggers.sortByLocalizedName()
                
            case let serviceGroup as HMServiceGroup:
                serviceGroups.append(serviceGroup)
                serviceGroups = serviceGroups.sortByLocalizedName()
                
            default:
                break
        }
    }
    
    /**
        Creates an `NSIndexPath` representing the location of the
        HomeKit object in the table view.
    
        - parameter object: The HomeKit object to find.
    
        - returns:  The `NSIndexPath` representing the location of
                    the HomeKit object in the table view.
    */
    func indexPathOfObject(_ object: AnyObject) -> IndexPath? {
        switch object {
            case let actionSet as HMActionSet:
                if let index = actionSets.index(of: actionSet) {
                    return IndexPath(row: index, section: HomeKitObjectSection.actionSet.rawValue)
                }
                
            case let accessory as HMAccessory:
                if let index = accessories.index(of: accessory) {
                    return IndexPath(row: index, section: HomeKitObjectSection.accessory.rawValue)
                }
                
            case let room as HMRoom:
                if let index = rooms.index(of: room) {
                    return IndexPath(row: index, section: HomeKitObjectSection.room.rawValue)
                }
                
            case let zone as HMZone:
                if let index = zones.index(of: zone) {
                    return IndexPath(row: index, section: HomeKitObjectSection.zone.rawValue)
                }
                
            case let trigger as HMTrigger:
                if let index = triggers.index(of: trigger) {
                    return IndexPath(row: index, section: HomeKitObjectSection.trigger.rawValue)
                }
                
            case let serviceGroup as HMServiceGroup:
                if let index = serviceGroups.index(of: serviceGroup) {
                    return IndexPath(row: index, section: HomeKitObjectSection.serviceGroup.rawValue)
                }
                
            default: break
        }

        return nil
    }
    
    /**
        Removes a HomeKit object from the collection.
    
        - parameter object: The HomeKit object to remove.
    */
    func remove(_ object: AnyObject) {
        switch object {
            case let actionSet as HMActionSet:
                if let index = actionSets.index(of: actionSet) {
                    actionSets.remove(at: index)
                }
                
            case let accessory as HMAccessory:
                if let index = accessories.index(of: accessory) {
                    accessories.remove(at: index)
                }
                
            case let room as HMRoom:
                if let index = rooms.index(of: room) {
                    rooms.remove(at: index)
                }
                
            case let zone as HMZone:
                if let index = zones.index(of: zone) {
                    zones.remove(at: index)
                }
                
            case let trigger as HMTrigger:
                if let index = triggers.index(of: trigger) {
                    triggers.remove(at: index)
                }
                
            case let serviceGroup as HMServiceGroup:
                if let index = serviceGroups.index(of: serviceGroup) {
                    serviceGroups.remove(at: index)
                }
                
            default:
                break
        }
    }
    
    /**
        Provides the array of `NSObject`s corresponding to the provided section.
    
        - parameter section: A `HomeKitObjectSection`.
    
        - returns:  An array of `NSObject`s corresponding to the provided section.
    */
    func objectsForSection(_ section: HomeKitObjectSection) -> [NSObject] {
        switch section {
            case .actionSet:
                return actionSets
                
            case .accessory:
                return accessories
                
            case .room:
                return rooms
                
            case .zone:
                return zones
                
            case .trigger:
                return triggers
                
            case .serviceGroup:
                return serviceGroups
                
            default:
                return []
        }
    }
    
    /**
        Provides an `HomeKitObjectSection` for a given object.
    
        - parameter object: A HomeKit object.
    
        - returns:  The corrosponding `HomeKitObjectSection`
    */
    class func sectionForObject(_ object: AnyObject?) -> HomeKitObjectSection? {
        switch object {
            case is HMActionSet:
                return .actionSet
                
            case is HMAccessory:
                return .accessory
                
            case is HMZone:
                return .zone
                
            case is HMRoom:
                return .room
                
            case is HMTrigger:
                return .trigger
                
            case is HMServiceGroup:
                return .serviceGroup
                
            default:
                return nil
        }
    }
    
    /**
        Reloads all internal structures based on the provided home.
        
        - parameter home: The `HMHome` with which to reset the collection.
    */
    func resetWithHome(_ home: HMHome) {
        accessories = home.accessories.sortByLocalizedName()
        rooms = home.allRooms
        zones = home.zones.sortByLocalizedName()
        actionSets = home.actionSets.sortByTypeAndLocalizedName()
        triggers = home.triggers.sortByLocalizedName()
        serviceGroups = home.serviceGroups.sortByLocalizedName()
    }
}
