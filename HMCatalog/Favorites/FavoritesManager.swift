/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `FavoritesManager` stores and saves characteristics that have been pinned by the user.
*/

import HomeKit

/// Handles interactions with `NSUserDefault`s to save the user's favorite accessories.
class FavoritesManager {
    // MARK: Types
    
    static let accessoryToCharacteristicIdentifierMappingKey = "FavoritesManager.accessoryToCharacteristicIdentifierMappingKey"

    static let accessoryIdentifiersKey = "FavoritesManager.accessoryIdentifiersKey"
    
    // MARK: Properties

    /// A shared, singleton manager.
    static let sharedManager = FavoritesManager()

    var home: HMHome? {
        return HomeStore.sharedStore.home
    }
    
    /**
        An internal mapping of accessory unique identifiers to an array of their 
        favorite characteristic's unique identifiers.
    */
    private var accessoryToCharacteristicIdentifiers = [UUID: [UUID]]()
    
    /// An internal array of all favorite accessory unique identifiers.
    private var accessoryIdentifiers = [UUID]()
    
    /**
        Loads the unique identifier map and array data from `NSUserDefaults`
        into internal variables.
    */
    init() {
        let userDefaults = UserDefaults.standard

        if let mapData = userDefaults.object(forKey: FavoritesManager.accessoryToCharacteristicIdentifierMappingKey) as? Data,
            let arrayData = userDefaults.object(forKey: FavoritesManager.accessoryIdentifiersKey) as? Data {
        
            accessoryToCharacteristicIdentifiers = NSKeyedUnarchiver.unarchiveObject(with: mapData) as? [UUID: [UUID]] ?? [:]
            
            accessoryIdentifiers = NSKeyedUnarchiver.unarchiveObject(with: arrayData) as? [UUID] ?? []
        }
    }
    
    /**
        - returns:  An array of all favorite characteristics.
                    The array is sorted by localized type.
    */
    var favoriteCharacteristics: [HMCharacteristic] {
        // Find all of the favorite characteristics.
        let favoriteCharacteristics = HomeStore.sharedStore.homeManager.homes.map { home in
            return home.allCharacteristics.filter { $0.isFavorite }
        }
        
        // Need to flatten an [[HMCharacteristic]] to an [HMCharacteristic].
        return favoriteCharacteristics.reduce([], +)
                                      .sorted(by: characteristicOrderedBefore)
    }
    
    /**
        - returns:  An array of all favorite accessories.
                    The array is sorted by localized name.
    */
    var favoriteAccessories: [HMAccessory] {
        // Find all of the favorite accessories.
        let newAccessories = accessoryIdentifiers.map { accessoryIdentifier in
            return HomeStore.sharedStore.homeManager.homes.map { home in
                return home.accessories.filter { accessory in
                    return accessory.uniqueIdentifier == accessoryIdentifier
                }
            }
        }
        
        // Need to flatten [[[HMAccessory]]] to [HMAccessory].
        return newAccessories.reduce([], +)
                             .reduce([], +)
                             .sortByLocalizedName()
    }
    
    
    /**
        - returns:  An array of tuples representing accessories and
                    all favorite characteristics they contain.
                    The array is sorted by localized type.
    */
    var favoriteGroups:[(accessory: HMAccessory, characteristics: [HMCharacteristic])] {
        return favoriteAccessories.map { accessory in
            let favoriteCharacteristics = favoriteCharacteristicsForAccessory(accessory)

            return (accessory: accessory, characteristics: favoriteCharacteristics)
        }
    }
    
    
    /**
        Evaluates whether or not an `HMCharacteristic` is a favorite.
        
        - parameter characteristic: The `HMCharacteristic` to evaluate.
        
        - returns:  A `Bool`, whether or not the characteristic is a favorite.
    */
    func characteristicIsFavorite(_ characteristic: HMCharacteristic) -> Bool {
        guard let accessoryIdentifier = characteristic.service?.accessory?.uniqueIdentifier else {
            return false
        }
        
        guard let characteristicIdentifiers = accessoryToCharacteristicIdentifiers[accessoryIdentifier] else {
            return false
        }

        return characteristicIdentifiers.contains(characteristic.uniqueIdentifier)
    }
    
    /**
        Favorites a characteristic.
        
        - parameter characteristic: The `HMCharacteristic` to favorite.
    */
    func favoriteCharacteristic(_ characteristic: HMCharacteristic) {
        if characteristicIsFavorite(characteristic) {
            return
        }

        if let accessoryIdentifier = characteristic.service?.accessory?.uniqueIdentifier , accessoryToCharacteristicIdentifiers[accessoryIdentifier] != nil {
            // Accessory is already favorite, add the characteristic.
            accessoryToCharacteristicIdentifiers[accessoryIdentifier]?.append(characteristic.uniqueIdentifier)
            save()
        }
        else if let accessory = characteristic.service?.accessory {
            // New accessory, make a new entry.
            accessoryIdentifiers.append(accessory.uniqueIdentifier)
            accessoryToCharacteristicIdentifiers[accessory.uniqueIdentifier] = [characteristic.uniqueIdentifier]
            save()
        }
    }
    
    /**
        Provides an array of favorite `HMCharacteristic`s within a given accessory.
        
        - parameter accessory: The `HMAccessory` to query.
        
        - returns: An array of `HMCharacteristic`s which are favorites for the provided accessory.
    */
    func favoriteCharacteristicsForAccessory(_ accessory: HMAccessory) -> [HMCharacteristic] {
        let characteristics = accessory.services.map { service in
            return service.characteristics.filter { characteristic in
                return characteristic.isFavorite
            }
        }
        return characteristics.reduce([], +)
                              .sorted(by: characteristicOrderedBefore)
    }
    
    
    /**
        Unfavorites a characteristic.
        
        - parameter characteristic: The `HMCharacteristic` to unfavorite.
    */
    func unfavoriteCharacteristic(_ characteristic: HMCharacteristic) {
        guard let accessoryIdentifier = characteristic.service?.accessory?.uniqueIdentifier else { return }

        guard let characteristicIdentifiers = accessoryToCharacteristicIdentifiers[accessoryIdentifier] else { return }
        
        guard let indexOfCharacteristic = characteristicIdentifiers.index(of: characteristic.uniqueIdentifier) else { return }
        
        // Remove the characteristic from the mapped collection.
        accessoryToCharacteristicIdentifiers[accessoryIdentifier]?.remove(at: indexOfCharacteristic)
        if let indexOfAccessory = accessoryIdentifiers.index(of: accessoryIdentifier),
               let isEmpty = accessoryToCharacteristicIdentifiers[accessoryIdentifier]?.isEmpty
               , isEmpty {
            /*
                If that was the last characteristic for that accessory, remove
                the accessory from the internal array.
            */
            accessoryIdentifiers.remove(at: indexOfAccessory)
            accessoryToCharacteristicIdentifiers.removeValue(forKey: accessoryIdentifier)
        }

        save()
    }
    
    // MARK: Helper Methods
    
    /**
        First, cleans out the internal identifier structures, then saves
        the `accessoryToCharacteristicIdentifiers` map and `accessoryIdentifiers`
        array into `NSUserDefaults`.
        
        This method should be called whenever a change is made to the internal structures.
    */
    private func save() {
        removeUnusedIdentifiers()
        
        let userDefaults = UserDefaults.standard
        
        let mapData = NSKeyedArchiver.archivedData(withRootObject: accessoryToCharacteristicIdentifiers)
        let arrayData = NSKeyedArchiver.archivedData(withRootObject: accessoryIdentifiers)
        
        userDefaults.set(mapData, forKey: FavoritesManager.accessoryToCharacteristicIdentifierMappingKey)
        userDefaults.set(arrayData, forKey: FavoritesManager.accessoryIdentifiersKey)
    }
    
    /**
        Filters out any accessories or characteristic which are not longer
        valid in HomeKit.
    */
    private func removeUnusedIdentifiers() {
        accessoryIdentifiers = accessoryIdentifiers.filter { identifier in
            return accessoryIdentifierExists(identifier)
        }
        
        let filteredPairs = accessoryToCharacteristicIdentifiers.filter { accessoryId, _ in
            return accessoryIdentifierExists(accessoryId)
        }
        
        accessoryToCharacteristicIdentifiers.removeAll()
        
        for (accessoryId, characteristicIds) in filteredPairs {
            accessoryToCharacteristicIdentifiers[accessoryId] = characteristicIds
        }
        
        for accessoryIdentifier in accessoryToCharacteristicIdentifiers.keys {
            let filteredCharacteristics = accessoryToCharacteristicIdentifiers[accessoryIdentifier]?.filter { characteristicId in
                return characteristicIdentifierExists(characteristicId)
            }

            accessoryToCharacteristicIdentifiers[accessoryIdentifier] = filteredCharacteristics
        }
    }
    
    /**
        - returns:  `true` if there exists an accessory in HomeKit with the given
                    identifier; `false` otherwise.
    */
    private func accessoryIdentifierExists(_ identifier: UUID) -> Bool {
        return HomeStore.sharedStore.homeManager.homes.contains { home in
            return home.accessories.contains { accessory in
                return accessory.uniqueIdentifier == identifier
            }
        }
    }
    
    /**
        - returns:  `true` if there exists a characteristic in HomeKit with the given
                    identifier; `false` otherwise.
    */
    private func characteristicIdentifierExists(_ identifier: UUID) -> Bool {
        return HomeStore.sharedStore.homeManager.homes.contains { home in
            return home.accessories.contains { accessory in
                return accessory.services.contains { service in
                    return service.characteristics.contains { characteristic in
                        return characteristic.uniqueIdentifier == identifier
                    }
                }
            }
        }
    }
    
    /**
        Evaluates two `HMCharacteristic` objects to determine if the first is ordered before the second.
        
        - parameter characteristic1: The first `HMCharacteristic` to evaluate.
        - parameter characteristic2: The second `HMCharacteristic` to evaluate.
        
        - returns:  `true` if the characteristics are localized ordered ascending, `false` otherwise.
    */
    private func characteristicOrderedBefore(_ characteristic1: HMCharacteristic, characteristic2: HMCharacteristic) -> Bool {
        let type1 = characteristic1.localizedCharacteristicType
        let type2 = characteristic2.localizedCharacteristicType

        return type1.localizedCompare(type2) == .orderedAscending
    }
}

extension HMCharacteristic {
    /// A convenience property to favorite, unfavorite, and query the status of a characteristic.
    var isFavorite: Bool {
        get {
            return FavoritesManager.sharedManager.characteristicIsFavorite(self)
        }

        set {
            if newValue {
                FavoritesManager.sharedManager.favoriteCharacteristic(self)
            }
            else {
                FavoritesManager.sharedManager.unfavoriteCharacteristic(self)
            }
        }
    }
}
