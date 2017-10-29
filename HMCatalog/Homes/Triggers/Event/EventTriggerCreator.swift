/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `EventTriggerCreator` is a superclass that creates Characteristic and Location triggers.
*/

import HomeKit

/**
    A superclass for event trigger creators.

    These classes manage the state for characteristic trigger conditions.
*/
class EventTriggerCreator: TriggerCreator, CharacteristicCellDelegate {
    // MARK: Properties
    
    /// A mapping of `HMCharacteristic`s to their values.
    private let conditionValueMap = NSMapTable<HMCharacteristic, CellValueType>.strongToStrongObjects()
    
    private var eventTrigger: HMEventTrigger? {
        return trigger as? HMEventTrigger
    }
    
    /**
        An array of top-level `NSPredicate` objects.
        
        Currently, HMCatalog only supports top-level `NSPredicate`s
        which have type `AndPredicateType`.
    */
    var originalConditions: [NSPredicate] {
        if let compoundPredicate = eventTrigger?.predicate as? NSCompoundPredicate,
            let subpredicates = compoundPredicate.subpredicates as? [NSPredicate] {
                return subpredicates
        }

        return []
    }
    
    /// An array of new conditions which will be written when the trigger is saved.
    lazy var conditions: [NSPredicate] = self.originalConditions
    
    /**
        Adds a predicate to the pending conditions.
        
        - parameter predicate: The new `NSPredicate` to add.
    */
    func addCondition(_ predicate: NSPredicate) {
        conditions.append(predicate)
    }
    
    /**
        Removes a predicate from the pending conditions.
        
        - parameter predicate: The `NSPredicate` to remove.
    */
    func removeCondition(_ predicate: NSPredicate) {
        if let index = conditions.index(of: predicate) {
            conditions.remove(at: index)
        }
    }
    
    /**
        - returns:  The new `NSCompoundPredicate`, generated from
                    the pending conditions.
    */
    func newPredicate() -> NSPredicate {
        return NSCompoundPredicate(type: .and, subpredicates: conditions)
    }
    
    /// Handles the value update and stores the value in the condition map.
    func characteristicCell(_ cell: CharacteristicCell, didUpdateValue value: CellValueType, forCharacteristic characteristic: HMCharacteristic, immediate: Bool) {
        conditionValueMap.setObject(value, forKey: characteristic)
    }
    
    /**
        Tries to use the value from the condition-value map, but falls back
        to reading the characteristic's value from HomeKit.
    */
    func characteristicCell(_ cell: CharacteristicCell, readInitialValueForCharacteristic characteristic: HMCharacteristic, completion: @escaping (CellValueType?, Error?) -> Void) {
        if let value = conditionValueMap.object(forKey: characteristic) {
            completion(value, nil)
            return
        }
        
        characteristic.readValue { error in
            /*
                The user may have updated the cell value while the
                read was happening. We check the map one more time.
            */
            if let value = self.conditionValueMap.object(forKey: characteristic) {
                completion(value, nil)
            }
            else {
                completion(characteristic.value as? CellValueType, error)
            }
        }
    }
    
    // MARK: Helper Methods
    
    /**
        Updates the predicates and saves the new, generated
        predicate to the event trigger.
    */
    func savePredicate() {
        updatePredicates()
        saveTriggerGroup.enter()
        eventTrigger?.updatePredicate(newPredicate()) { error in
            if let error = error {
                self.errors.append(error)
            }
            self.saveTriggerGroup.leave()
        }
    }
    
    /// Generates predicates from the characteristic-value map and adds them to the pending conditions.
    func updatePredicates() {
        for (characteristic, value) in pairsFromMapTable(conditionValueMap) {
            let predicate = HMEventTrigger.predicateForEvaluatingTrigger(characteristic, relatedBy: .equalTo, toValue: value)
            addCondition(predicate)
        }

        conditionValueMap.removeAllObjects()
    }
    
    /**
        - parameter table: The `NSMapTable` from which to generate the pairs.
        
        - returns:  Tuples representing `HMCharacteristic`s and their associated return trigger values.
    */
    func pairsFromMapTable<Key, ValueType>(_ table: NSMapTable<Key, ValueType>) -> [(Key, ValueType)] {
        return table.keyEnumerator().allObjects.map { object in
            let characteristic = object as! Key
            let triggerValue = table.object(forKey: characteristic)
            return (characteristic, triggerValue!)
        }
    }
}
