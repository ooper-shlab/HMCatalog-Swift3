/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ActionSetCreator` builds `HMActionSet`s.
*/

import HomeKit

/// A `CharacteristicCellDelegate` that builds an `HMActionSet` when it receives delegate callbacks.
class ActionSetCreator: CharacteristicCellDelegate {

    // MARK: Properties
    
    var actionSet: HMActionSet?
    var home: HMHome

    var saveError: Error?
    
    /// The structure we're going to use to hold the target values.
    let targetValueMap = NSMapTable<HMCharacteristic, CellValueType>.strongToStrongObjects()
    
    /// A dispatch group to wait for all of the individual components of the saving process.
    let saveActionSetGroup = DispatchGroup()
    
    required init(actionSet: HMActionSet?, home: HMHome) {
        self.actionSet = actionSet
        self.home = home
    }

    /**
        If there is an action set, saves the action set and then updates its name.
        Otherwise creates a new action set and adds all actions to it.
        
        - parameter name:              The new name for the action set.
        - parameter completionHandler: A closure to call once the action set has been completely saved.
    */
    func saveActionSetWithName(_ name: String, completionHandler: @escaping (_ error: Error?) -> Void) {
        if let actionSet = actionSet {
            saveActionSet(actionSet)
            updateNameIfNecessary(name)
        }
        else {
            createActionSetWithName(name)
        }
        saveActionSetGroup.notify(queue: DispatchQueue.main) {
            completionHandler(self.saveError)
            self.saveError = nil
        }
    }

    /**
        Adds all of the actions that have been requested to the Action Set, then runs a completion block.
        
        - parameter completion: A closure to be called when all of the actions have been added.
    */
    func saveActionSet(_ actionSet: HMActionSet) {
        let actions = actionsFromMapTable(targetValueMap)
        for action in actions {
            saveActionSetGroup.enter()
            addAction(action, toActionSet: actionSet) { error in
                if let error = error {
                    print("HomeKit: Error adding action: \(error.localizedDescription)")
                    self.saveError = error
                }
                self.saveActionSetGroup.leave()
            }
        }
    }
    
    /**
        Sets the name of an existing action set.
        
        - parameter name: The new name for the action set.
    */
    func updateNameIfNecessary(_ name: String) {
        if actionSet?.name == name {
            return
        }
        saveActionSetGroup.enter()
        actionSet?.updateName(name) { error in
            if let error = error {
                print("HomeKit: Error updating name: \(error.localizedDescription)")
                self.saveError = error
            }
            self.saveActionSetGroup.leave()
        }
    }
    
    /**
        Creates and saves an action set with the provided name.
        
        - parameter name: The name for the new action set.
    */
    func createActionSetWithName(_ name: String) {
        saveActionSetGroup.enter()
        home.addActionSet(withName: name) { actionSet, error in
            if let error = error {
                print("HomeKit: Error creating action set: \(error.localizedDescription)")
                self.saveError = error
            }
            else {
                // There is no error, so the action set has a value.
                self.saveActionSet(actionSet!)
            }
            self.saveActionSetGroup.leave()
        }
    }
    
    /**
        Checks to see if an action already exists to modify the same characteristic 
        as the action passed in. If such an action exists, the method tells the 
        existing action to update its target value. Otherwise, the new action is
        simply added to the action set.
        
        - parameter action:     The action to add or update.
        - parameter actionSet:  The action set to which to add the action.
        - parameter completion: A closure to call when the addition has finished.
    */
    func addAction(_ action: HMCharacteristicWriteAction<NSCopying>, toActionSet actionSet: HMActionSet, completion: @escaping (Error?) -> Void) {
        if let existingAction = existingActionInActionSetMatchingAction(action) {
            existingAction.updateTargetValue(action.targetValue, completionHandler: completion)
        }
        else {
            actionSet.addAction(action, completionHandler: completion)
        }
    }
    
    /**
        Checks to see if there is already an HMCharacteristicWriteAction in
        the action set that matches the provided action.
        
        - parameter action: The action in question.
        
        - returns: The existing action that matches the characteristic or nil if
                   there is no existing action.
    */
    func existingActionInActionSetMatchingAction(_ action: HMCharacteristicWriteAction<CellValueType>) -> HMCharacteristicWriteAction<CellValueType>? {
        if let actionSet = actionSet {
            for case let existingAction as HMCharacteristicWriteAction<CellValueType> in actionSet.actions {
                if action.characteristic == existingAction.characteristic {
                    return existingAction
                }
            }
        }
        return nil
    }
    
    /**
        Iterates over a map table of HMCharacteristic -> id objects and creates
        an array of HMCharacteristicWriteActions based on those targets.
        
        - parameter table: An NSMapTable mapping HMCharacteristics to id's.
        
        - returns:  An array of HMCharacteristicWriteActions.
    */
    func actionsFromMapTable(_ table: NSMapTable<HMCharacteristic, CellValueType>) -> [HMCharacteristicWriteAction<CellValueType>] {
        return targetValueMap.keyEnumerator().allObjects.map { key in
            let characteristic = key as! HMCharacteristic
            let targetValue =  targetValueMap.object(forKey: characteristic)!
            return HMCharacteristicWriteAction(characteristic: characteristic, targetValue: targetValue)
        }
    }
    
    /**
        - returns:  `true` if the characteristic count is greater than zero;
                    `false` otherwise.
    */
    var containsActions: Bool {
        return !allCharacteristics.isEmpty
    }
    
    /**
        All existing characteristics within `HMCharacteristiWriteActions`
        and target values in the target value map.
    */
    var allCharacteristics: [HMCharacteristic] {
        var characteristics = Set<HMCharacteristic>()
        
        if let actions = actionSet?.actions {
            let actionSetCharacteristics = actions.flatMap { action in
                return (action as? HMCharacteristicWriteAction<CellValueType>)?.characteristic
            }
            characteristics.formUnion(actionSetCharacteristics)
        }
        
        characteristics.formUnion(targetValueMap.keyEnumerator().allObjects as! [HMCharacteristic])

        return Array(characteristics)
    }

    /**
        Searches through the target value map and existing `HMCharacteristicWriteActions`
        to find the target value for the characteristic in question.
        
        - parameter characteristic: The characteristic in question.
        
        - returns:  The target value for this characteristic, or nil if there is no target.
    */
    func targetValueForCharacteristic(_ characteristic: HMCharacteristic) -> CellValueType? {
        if let value = targetValueMap.object(forKey: characteristic) {
            return value
        }
        else if let actions = actionSet?.actions {
            for case let writeAction as HMCharacteristicWriteAction<CellValueType> in actions {
                if writeAction.characteristic == characteristic {
                    return writeAction.targetValue
                }
            }
        }

        return nil
    }

    /**
        First removes the characteristic from the `targetValueMap`.
        Then removes any `HMCharacteristicWriteAction`s from the action set
        which set the specified characteristic.
        
        - parameter characteristic: The `HMCharacteristic` to remove.
        - parameter completion: The closure to invoke when the characteristic has been removed.
    */
    func removeTargetValueForCharacteristic(_ characteristic: HMCharacteristic, completion: @escaping () -> Void) {
        /*
            We need to create a dispatch group here, because in many cases
            there will be one characteristic saved in the Action Set, and one
            in the target value map. We want to run the completion closure only one time,
            to ensure we've removed both.
        */
        let group = DispatchGroup()
        if targetValueMap.object(forKey: characteristic) != nil {
            // Remove the characteristic from the target value map.
            DispatchQueue.main.async(group: group) {
                self.targetValueMap.removeObject(forKey: characteristic)
            }
        }
        if let actions = actionSet?.actions {
            for case let action as HMCharacteristicWriteAction<CellValueType> in actions {
                if action.characteristic == characteristic {
                    /*
                        Also remove the action, and only relinquish the dispatch group
                        once the action set has finished.
                    */
                    group.enter()
                    actionSet?.removeAction(action) { error in
                        if let error = error {
                            print(error.localizedDescription)
                        }
                        group.leave()
                    }
                }
            }
        }
        // Once we're positive both have finished, run the completion closure on the main queue.
        group.notify(queue: DispatchQueue.main, execute: completion)
    }
 
    // MARK: Characteristic Cell Delegate

    /**
        Receives a callback from a `CharacteristicCell` with a value change.
        Adds this value change into the targetValueMap, overwriting other value changes.
    */
    func characteristicCell(_ cell: CharacteristicCell, didUpdateValue newValue: CellValueType, forCharacteristic characteristic: HMCharacteristic, immediate: Bool) {
        targetValueMap.setObject(newValue, forKey: characteristic)
    }
    
    /**
        Receives a callback from a `CharacteristicCell`, requesting an initial value for
        a given characteristic.
        
        It checks to see if we have an action in this Action Set that matches the characteristic.
        If so, calls the completion closure with the target value.
    */
    func characteristicCell(_ cell: CharacteristicCell, readInitialValueForCharacteristic characteristic: HMCharacteristic, completion: @escaping (CellValueType?, Error?) -> Void) {
        if let value = targetValueForCharacteristic(characteristic) {
            completion(value, nil)
            return
        }
        
        characteristic.readValue { error in
            /*
                The user may have updated the cell value while the
                read was happening. We check the map one more time.
            */
            if let value = self.targetValueForCharacteristic(characteristic) {
                completion(value, nil)
            }
            else {
                completion(characteristic.value as? CellValueType, error)
            }
        }
    }
}
