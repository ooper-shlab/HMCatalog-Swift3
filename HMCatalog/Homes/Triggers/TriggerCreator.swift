/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `TriggerCreator` is a superclass that builds triggers.
*/

import HomeKit

/**
    A superclass for all trigger creators.

    These classes manage the temporary state of the trigger
    and unify some of the saving processes.
*/
class TriggerCreator {
    // MARK: Properties
    
    internal var home: HMHome
    internal var trigger: HMTrigger?
    internal var name = ""
    internal let saveTriggerGroup = DispatchGroup()
    internal var errors = [Error]()
    
    /**
        Initializes a trigger creator from an existing trigger (if it exists),
        and the current home.
    
        - parameter trigger: An `HMTrigger` or `nil`, if creation is desired.
        - parameter home: The `HMHome` into which this trigger will go.
    */
    required init(trigger: HMTrigger?, home: HMHome) {
        self.home = home
        self.trigger = trigger
    }
    
    /**
        Completes one of two actions based on the current status of the `trigger` object:
        
        1. Updates the existing trigger.
        2. Creates a new trigger.
        
        - parameter name: The name to set for the new or updated trigger.
        - parameter actionSets: The new list of action sets to set for the trigger
        - parameter completion: The closure to call when all configurations have been completed.
    */
    func saveTriggerWithName(_ name: String, actionSets: [HMActionSet], completion: @escaping (HMTrigger?, [Error]) -> Void) {
        self.name = name
        if trigger != nil {
            // Let the subclass update the trigger.
            updateTrigger()
            updateNameIfNecessary()
            configureWithActionSets(actionSets)
        }
        else {
            self.trigger = newTrigger()
            saveTriggerGroup.enter()
            home.addTrigger(trigger!) { error in
                if let error = error {
                    self.errors.append(error)
                }
                else {
                    self.configureWithActionSets(actionSets)
                }
                self.saveTriggerGroup.leave()
            }
        }
        
        /*
            Call the completion block with our event trigger and any accumulated errors
            from the saving process.
        */
        saveTriggerGroup.notify(queue: DispatchQueue.main) {
            self.cleanUp()
            completion(self.trigger, self.errors)
        }
    }
    
    /**
        Updates the trigger's internals.
        Action sets and the trigger name need not be configured.
        
        Implemented by subclasses.
    */
    internal func updateTrigger() { }
    
    /**
        Creates a new trigger to be added to the home.
        Action sets and the trigger name need not be configured.
        
        Implemented by subclasses.
        
        - returns: A new, generated `HMTrigger`.
    */
    internal func newTrigger() -> HMTrigger? {
        return nil
    }
    
    /**
        Cleans up an internal structures after the trigger has been saved.
        
        Implemented by subclasses.
    */
    internal func cleanUp() {}
    
    
    // MARK: Helper Methods
    
    /**
        Syncs the trigger's action sets with the specified array of action sets.
        
        - parameter actionSets: Array of `HMActionSet`s to match.
    */
    private func configureWithActionSets(_ actionSets: [HMActionSet]) {
        guard let trigger = trigger else { return }
        /*
            Save a standard completion handler to use when we either add or remove 
            an action set.
        */
        let defaultCompletion: (Error?) -> Void = { error in
            // Leave the dispatch group, to notify that we've finished this task.
            if let error = error {
                self.errors.append(error)
            }
            self.saveTriggerGroup.leave()
        }
        
        // First pass, remove the action sets that have been deselected.
        for actionSet in trigger.actionSets {
            if actionSets.contains(actionSet)  {
                continue
            }
            saveTriggerGroup.enter()
            trigger.removeActionSet(actionSet, completionHandler: defaultCompletion)
        }
        
        // Second pass, add the new action sets that were just selected.
        for actionSet in actionSets {
            if trigger.actionSets.contains(actionSet)  {
                continue
            }
            saveTriggerGroup.enter()
            trigger.addActionSet(actionSet, completionHandler: defaultCompletion)
        }
    }
    
    /// Updates the trigger's name from the stored name, entering and leaving the dispatch group if necessary.
    func updateNameIfNecessary() {
        if trigger?.name == self.name {
            return
        }
        saveTriggerGroup.enter()
        trigger?.updateName(name) { error in
            if let error = error {
                self.errors.append(error)
            }
            self.saveTriggerGroup.leave()
        }
    }
}
