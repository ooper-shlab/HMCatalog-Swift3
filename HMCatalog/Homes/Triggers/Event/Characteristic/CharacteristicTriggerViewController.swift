/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `CharacteristicTriggerViewController` allows the user to create a characteristic trigger.
*/

import UIKit
import HomeKit

/// A view controller which facilitates the creation of characteristic triggers.
class CharacteristicTriggerViewController: EventTriggerViewController {
    // MARK: Types
    
    struct Identifiers {
        static let selectCharacteristicSegue = "Select Characteristic"
    }
    
    // MARK: Properties
    
    private var characteristicTriggerCreator: CharacteristicTriggerCreator {
        return triggerCreator as! CharacteristicTriggerCreator
    }
    
    var eventTrigger: HMEventTrigger? {
        return trigger as? HMEventTrigger
    }
    
    /// An internal array of `HMCharacteristicEvent`s to save into the trigger.
    private var events = [HMCharacteristicEvent<CellValueType>]()
    
    // MARK: View Methods
    
    /// Creates the trigger creator.
    override func viewDidLoad() {
        super.viewDidLoad()
        triggerCreator = CharacteristicTriggerCreator(trigger: eventTrigger, home: home)
    }
    
    /// Reloads the internal data.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    /// Passes our event trigger and trigger creator to the `CharacteristicSelectionViewController`
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Identifiers.selectCharacteristicSegue {
            if let destinationVC = segue.intendedDestinationViewController as? CharacteristicSelectionViewController {
                destinationVC.eventTrigger = eventTrigger
                destinationVC.triggerCreator = characteristicTriggerCreator
            }
        }
    }
    
    // MARK: Table View Methods
    
    /**
        - returns:  The characteristic events for the Characteristics section.
                    Defaults to super implementation.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionForIndex(section) {
            case .characteristics?:
                // Plus one for the add row.
                return events.count + 1
            
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    /**
        Switches based on cell type to generate the correct cell for the index path.
        Defaults to super implementation.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPathIsAdd(indexPath) {
            return self.tableView(tableView, addCellForRowAtIndexPath: indexPath)
        }
        
        switch sectionForIndex(indexPath.section) {
            case .characteristics?:
                return self.tableView(tableView, conditionCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    /// - returns:  A 'condition cell' with the event at the specified index path.
    private func tableView(_ tableView: UITableView, conditionCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.conditionCell, for: indexPath) as! ConditionCell
        let event = events[indexPath.row]
        cell.setCharacteristic(event.characteristic, targetValue: event.triggerValue!)
        return cell
    }
    
    /**
        - returns:  An 'add cell' with localized text.
                    Defaults to super implementation.
    */
    override func tableView(_ tableView: UITableView, addCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        switch sectionForIndex(indexPath.section) {
            case .characteristics?:
                let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.addCell, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Add Characteristic…", comment: "Add Characteristic")
                cell.textLabel?.textColor = .editableBlue
                return cell
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, addCellForRowAtIndexPath: indexPath)
        }
    }
    
    /**
        Handles the selection of characteristic events.
        Defaults to super implementation for other sections.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sectionForIndex(indexPath.section) {
            case .characteristics?:
                if indexPathIsAdd(indexPath) {
                    addEvent()
                    return
                }
                let cell = tableView.cellForRow(at: indexPath)
                performSegue(withIdentifier: Identifiers.selectCharacteristicSegue, sender: cell)
            
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    /**
        - returns:  `true` for characteristic cells,
                    otherwise defaults to super implementation.
    */
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPathIsAdd(indexPath) {
            return false
        }
        switch sectionForIndex(indexPath.section) {
            case .characteristics?:
                return true
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, canEditRowAt: indexPath)
        }
    }
    
    /**
        Removes events from the trigger creator.
        Defaults to super implementation for other sections.
    */
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch sectionForIndex(indexPath.section) {
                case .characteristics?:
                    characteristicTriggerCreator.removeEvent(events[indexPath.row])
                    events = characteristicTriggerCreator.events
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    
                case nil:
                    fatalError("Unexpected `TriggerTableViewSection` raw value.")
                    
                default:
                    super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
            }
        }
    }
    
    /**
        - returns:  A localized description of characteristic events
                    Defaults to super implementation for other sections.
    */
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sectionForIndex(section) {
            case .characteristics?:
                return NSLocalizedString("This trigger will activate when any of these characteristics change to their value. For example, 'run when the garage door is opened'.", comment: "Characteristic Trigger Description")
            
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, titleForFooterInSection: section)
        }
    }
    
    // MARK: Helper Methods
    
    /// Resets the internal events array from the trigger creator.
    private func reloadData() {
        events = characteristicTriggerCreator.events
        tableView.reloadData()
    }
    
    /// Performs a segue to the `CharacteristicSelectionViewController`.
    private func addEvent() {
        characteristicTriggerCreator.mode = .event
        self.performSegue(withIdentifier: Identifiers.selectCharacteristicSegue, sender: nil)
    }
    
    /// - returns:  `true` if the section is the Characteristic 'add row'; otherwise defaults to super implementation.
    override func indexPathIsAdd(_ indexPath: IndexPath) -> Bool {
        switch sectionForIndex(indexPath.section) {
            case .characteristics?:
                return indexPath.row == events.count
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.indexPathIsAdd(indexPath)
        }
    }
    
    // MARK: Trigger Controller Methods

    /**
        - parameter index: The section index.
        
        - returns:  The `TriggerTableViewSection` for the given index.
    */
    override func sectionForIndex(_ index: Int) -> TriggerTableViewSection? {
        switch index {
            case 0:
                return .name
            
            case 1:
                return .enabled
            
            case 2:
                return .characteristics
            
            case 3:
                return .conditions
            
            case 4:
                return .actionSets
            
            default:
                return nil
        }
    }
    
}
