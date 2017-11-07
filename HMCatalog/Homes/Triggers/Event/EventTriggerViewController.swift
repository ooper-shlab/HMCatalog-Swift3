/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `EventTriggerViewController` is a superclass that helps users create Characteristic and Location triggers.
*/

import UIKit
import HomeKit

/**
    A superclass for all event-based view controllers.

    It handles the process of creating and managing trigger conditions.
*/
class EventTriggerViewController: TriggerViewController {
    // MARK: Types
    
    struct Identifiers {
        static let addCell = "AddCell"
        static let conditionCell = "ConditionCell"
        static let showTimeConditionSegue = "Show Time Condition"
    }
    
    // MARK: Properties
    
    private var eventTriggerCreator: EventTriggerCreator {
        return triggerCreator as! EventTriggerCreator
    }
    
    // MARK: View Methods
    
    /// Registers table view for cells.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier:Identifiers.addCell)
        tableView.register(ConditionCell.self, forCellReuseIdentifier:Identifiers.conditionCell)
    }
    
    /// Hands off the trigger creator to the condition view controllers.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.intendedDestinationViewController {
            case let timeVC as TimeConditionViewController:
                timeVC.triggerCreator = eventTriggerCreator

            case let characteristicEventVC as CharacteristicSelectionViewController:
                let characteristicTriggerCreator = triggerCreator as! EventTriggerCreator
                characteristicEventVC.triggerCreator = characteristicTriggerCreator
            
            default:
                break
        }
    }
    
    // MARK: Table View Methods
    
    /**
        - returns:  In the conditions section: the number of conditions, plus one 
                    for the add row. Defaults to the super implementation.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionForIndex(section) {
            case .conditions?:
                // Add row.
                return eventTriggerCreator.conditions.count + 1
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    /**
        Launchs "Add Condition" if the 'add index path' is selected.
        Defaults to the super implementation.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sectionForIndex(indexPath.section) {
            case .conditions?:
                if indexPathIsAdd(indexPath) {
                    addCondition()
                }
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    /**
        Switches to select the correct type of cell for the section.
        Defaults to the super implementation.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPathIsAdd(indexPath) {
            return self.tableView(tableView, addCellForRowAtIndexPath: indexPath)
        }
        
        switch sectionForIndex(indexPath.section) {
            case .conditions?:
                return self.tableView(tableView, conditionCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    /**
        The conditions can be removed, the 'add index path' cannot.
        For all others, default to super implementation.
    */
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPathIsAdd(indexPath) {
            return false
        }
        
        switch sectionForIndex(indexPath.section) {
            case .conditions?:
                return true
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return false
        }
    }
    
    /// Remove the selected condition from the trigger creator.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let predicate = eventTriggerCreator.conditions[indexPath.row]
            eventTriggerCreator.removeCondition(predicate)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    /// - returns:  An 'add cell' with 'Add Condition' text.
    func tableView(_ tableView: UITableView, addCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.addCell, for: indexPath)
        let cellText: String
        switch sectionForIndex(indexPath.section) {
            case .conditions?:
                cellText = NSLocalizedString("Add Condition…", comment: "Add Condition")
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                cellText = NSLocalizedString("Add…", comment: "Add")
        }

        cell.textLabel?.text = cellText
        cell.textLabel?.textColor = .editableBlue
     
        return cell
    }
    
    /// - returns:  A localized description of a trigger. Falls back to super implementation.
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sectionForIndex(section) {
            case .conditions?:
                return NSLocalizedString("When a trigger is activated by an event, it checks these conditions. If all of them are true, it will set its scenes.", comment: "Trigger Conditions Description")
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, titleForFooterInSection: section)
        }
    }
    
    // MARK: Helper Methods
    
    /// - returns:  A 'condition cell', which displays information about the condition.
    private func tableView(_ tableView: UITableView, conditionCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.conditionCell) as! ConditionCell
        let condition = eventTriggerCreator.conditions[indexPath.row]

        switch condition.homeKitConditionType {
            case .characteristic(let characteristic, let value):
                cell.setCharacteristic(characteristic, targetValue: value)

            case .exactTime(let order, let dateComponents):
                cell.setOrder(order, dateComponents: dateComponents)
            
            case .sunTime(let order, let sunState):
                cell.setOrder(order, sunState: sunState)
            
            case .unknown:
                cell.setUnknown()
        }

        return cell
    }
    
    /// Presents an alert controller to choose the type of trigger.
    private func addCondition() {
        let title = NSLocalizedString("Add Condition", comment: "Add Condition")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        // Time Condition.
        let timeAction = UIAlertAction(title: NSLocalizedString("Time", comment: "Time"), style: .default) { _ in
            self.performSegue(withIdentifier: Identifiers.showTimeConditionSegue, sender: self)
        }
        alertController.addAction(timeAction)
        
        // Characteristic trigger.
        let eventActionTitle = NSLocalizedString("Characteristic", comment: "Characteristic")

        let eventAction = UIAlertAction(title: eventActionTitle, style: .default, handler: { _ in
            if let triggerCreator = self.triggerCreator as? CharacteristicTriggerCreator {
                triggerCreator.mode = .condition
            }
            self.performSegue(withIdentifier: "Select Characteristic", sender: self)
        })

        alertController.addAction(eventAction)
        
        // Cancel.
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        // Present alert.
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = self.view
            presenter.sourceRect = self.view.bounds
        }
        present(alertController, animated: true, completion: nil)
    }
    
    /// - returns:  `true` if the index path is the 'add row'; `false` otherwise.
    func indexPathIsAdd(_ indexPath: IndexPath) -> Bool {
        switch sectionForIndex(indexPath.section) {
            case .conditions?:
                return indexPath.row == eventTriggerCreator.conditions.count
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return false
        }
    }
}
