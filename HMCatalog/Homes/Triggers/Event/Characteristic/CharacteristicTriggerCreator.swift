/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `CharacteristicTriggerCreator` creates characteristic triggers.
*/

import UIKit
import HomeKit

/// Represents modes for a `CharacteristicTriggerCreator`.
enum CharacteristicTriggerCreatorMode: Int {
    case event, condition
}

/**
    An `EventTriggerCreator` subclass which allows for the creation
    of characteristic triggers.
*/
class CharacteristicTriggerCreator: EventTriggerCreator {
    // MARK: Properties
    
    var eventTrigger: HMEventTrigger? {
        return self.trigger as? HMEventTrigger
    }
    
    /**
        This object will be a characteristic cell delegate and will therefore
        be receiving updates when UI elements change value. However, this object
        can construct both characteristic events and characteristic triggers.
        Setting the `mode` determines how this trigger creator will handle 
        cell delegate callbacks.
    */
    var mode: CharacteristicTriggerCreatorMode = .event
    
    /**
        Contains the new pending mapping of `HMCharacteristic`s to their trigger (`NSCopying`) values.
        When `saveTriggerWithName(name:completion:)` is called, all of these mappings will be converted
        into `HMCharacteristicEvent`s and added to the `HMEventTrigger`.
    */
    private let targetValueMap = NSMapTable<HMCharacteristic, CellValueType>.strongToStrongObjects()
    
    /// `HMCharacteristicEvent`s that should be removed if `saveTriggerWithName(name:completion:)` is called.
    private var removalCharacteristicEvents = [HMCharacteristicEvent<NSCopying>]()
    
    // MARK: Trigger Creator Methods
    
    /// Syncs the stored event trigger using internal values.
    override func updateTrigger() {
        guard let eventTrigger = eventTrigger else { return }
        matchEventsFromTriggerIfNecessary()
        removePendingEventsFromTrigger()
        for (characteristic, triggerValue) in pairsFromMapTable(targetValueMap) {
            let newEvent = HMCharacteristicEvent(characteristic: characteristic, triggerValue: triggerValue)
            self.saveTriggerGroup.enter()
            eventTrigger.addEvent(newEvent) { error in
                if let error = error {
                    self.errors.append(error)
                }
                self.saveTriggerGroup.leave()
            }
        }
        savePredicate()
    }
    
    /**
        - returns:  A new `HMEventTrigger` with the pending
                    characteristic events and constructed predicate.
    */
    override func newTrigger() -> HMTrigger? {
        return HMEventTrigger(name: name, events: pendingCharacteristicEvents, predicate: newPredicate())
    }
    
    /**
        Remove all objects from the map so they don't show up
        in the `events` computed array.
    */
    override func cleanUp() {
        targetValueMap.removeAllObjects()
    }
    
    /**
        Removes an event from the map table if it's a new event and
        queues it for removal if it already existed in the event trigger.
        
        - parameter event: `HMCharacteristicEvent` to be removed.
    */
    func removeEvent(_ event: HMCharacteristicEvent<CellValueType>) {
        if targetValueMap.object(forKey: event.characteristic) != nil {
            // Remove the characteristic from the target value map.
            targetValueMap.removeObject(forKey: event.characteristic)
        }
        
        if let characteristicEvents = eventTrigger?.characteristicEvents , characteristicEvents.contains(event)  {
            // If the given event is in the event array, queue it for removal.
            removalCharacteristicEvents.append(event)
        }
    }
    
    // MARK: Helper Methods
    
    /**
        Any characteristic events in the map table that have not yet been
        added to the trigger.
    */
    var pendingCharacteristicEvents: [HMCharacteristicEvent<CellValueType>] {
        let pairs = pairsFromMapTable(targetValueMap)
        return pairs.map { (characteristic, triggerValue) -> HMCharacteristicEvent<CellValueType> in
            return HMCharacteristicEvent(characteristic: characteristic, triggerValue: triggerValue)
        }
    }
    
    /**
        Loops through the characteristic events in the trigger.
        If any characteristics in our map table are also in the event,
        replace the value with the one we have stored and remove that entry from
        our map table.
    */
    private func matchEventsFromTriggerIfNecessary() {
        guard let eventTrigger = eventTrigger else { return }
        for event in eventTrigger.characteristicEvents {
            // Find events who's characteristic is in our map table.
            if let triggerValue = targetValueMap.object(forKey: event.characteristic) {
                self.saveTriggerGroup.enter()
                event.updateTriggerValue(triggerValue) { error in
                    if let error = error {
                        self.errors.append(error)
                    }
                    self.saveTriggerGroup.leave()
                }
            }
        }
    }
    
    /**
        Removes all `HMCharacteristicEvent`s from the `removalCharacteristicEvents`
        array and stores any errors that accumulate.
    */
    private func removePendingEventsFromTrigger() {
        guard let eventTrigger = eventTrigger else { return }
        for event in removalCharacteristicEvents {
            saveTriggerGroup.enter()
            eventTrigger.removeEvent(event) { error in
                if let error = error {
                    self.errors.append(error)
                }
                self.saveTriggerGroup.leave()
            }
        }
        removalCharacteristicEvents.removeAll()
    }
    
    
    
    /// All `HMCharacteristic`s in the `targetValueMap`.
    private var allCharacteristics: [HMCharacteristic] {
        var characteristics = Set<HMCharacteristic>()
        for characteristic in targetValueMap.keyEnumerator().allObjects as! [HMCharacteristic] {
            characteristics.insert(characteristic)
        }
        return Array(characteristics)
    }
    
    /**
        Saves a characteristic and value into the pending map
        of characteristic events.
        
        - parameter value: The value of the characteristic.
        - parameter characteristic: The `HMCharacteristic` that has been updated.
    */
    private func updateEventValue(_ value: NSCopying, forCharacteristic characteristic: HMCharacteristic) {
        for (index, event) in removalCharacteristicEvents.enumerated() {
            if event.characteristic == characteristic {
                /*
                    We have this event pending for deletion,
                    but we are going to want to update it.
                    remove it from the removal array.
                */
                removalCharacteristicEvents.remove(at: index)
                break
            }
        }
        targetValueMap.setObject(value, forKey: characteristic)
    }
    
    /**
        The current, sorted collection of `HMCharacteristicEvent`s accumulated by
        filtering out the events pending removal from the original trigger events and
        then adding new pending events.
    */
    var events: [HMCharacteristicEvent<CellValueType>] {
        let characteristicEvents = eventTrigger?.characteristicEvents ?? []
        
        let originalEvents = characteristicEvents.filter {
            return !removalCharacteristicEvents.contains($0)
        }
        
        let allEvents = originalEvents + pendingCharacteristicEvents
        
        return allEvents.sorted { (event1: HMCharacteristicEvent, event2: HMCharacteristicEvent) in
            let type1 = event1.characteristic.localizedCharacteristicType
            let type2 = event2.characteristic.localizedCharacteristicType
            return type1.localizedCompare(type2) == .orderedAscending
        }
    }
    
    // MARK: CharacteristicCellDelegate Methods
    
    /**
        If the mode is event, update the event value.
        Otherwise, default to super implementation
    */
    override func characteristicCell(_ cell: CharacteristicCell, didUpdateValue value: CellValueType, forCharacteristic characteristic: HMCharacteristic, immediate: Bool) {
        switch mode {
            case .event:
                updateEventValue(value, forCharacteristic: characteristic)
            
            default:
                super.characteristicCell(cell, didUpdateValue: value, forCharacteristic: characteristic, immediate: immediate)
        }
    }
    
    /**
        Tries to find the characteristic in either the event map or the
        condition map (based on the current mode). Then calls read value.
        When the value comes back, we check the selected map for the value
    */
    override func characteristicCell(_ cell: CharacteristicCell, readInitialValueForCharacteristic characteristic: HMCharacteristic, completion: @escaping (CellValueType?, Error?) -> Void) {
        if mode == .condition {
            // This is a condition, fall back to the `EventTriggerCreator` read.
            super.characteristicCell(cell, readInitialValueForCharacteristic: characteristic, completion: completion)
            return
        }
        
        if let value = targetValueMap.object(forKey: characteristic) {
            completion(value, nil)
            return
        }
        
        characteristic.readValue { error in
            /*
                The user may have updated the cell value while the
                read was happening. We check the map one more time.
            */
            if let value = self.targetValueMap.object(forKey: characteristic) {
                completion(value, nil)
            }
            else {
                completion(characteristic.value as? CellValueType, error)
            }
        }
    }
    
}
