/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `TriggerViewController` is a superclass which allows users to create triggers.
*/

import UIKit
import HomeKit

/// Represents all possible sections in a `TriggerViewController` subclass.
enum TriggerTableViewSection: Int {
    // All triggers have these sections.
    case name, enabled, actionSets
    
    // Timer triggers only.
    case dateAndTime, recurrence
    
    // Location and Characteristic triggers only.
    case conditions

    // Location triggers only.
    case location, region

    // Characteristic triggers only.
    case characteristics
}

/**
    A superclass for all trigger view controllers.

    It manages the name, enabled state, and action set components of the view,
    as these are shared components.
*/
class TriggerViewController: HMCatalogViewController {
    // MARK: Types
    
    struct Identifiers {
        static let actionSetCell = "ActionSetCell"
    }
    
    // MARK: Properties
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var enabledSwitch: UISwitch!
    
    var trigger: HMTrigger?
    var triggerCreator: TriggerCreator?
    
    /// An internal array of all action sets in the home.
    var actionSets: [HMActionSet]!
    
    /**
        An array of all action sets that the user has selected.
        This will be used to save the trigger when it is finalized.
    */
    lazy var selectedActionSets = [HMActionSet]()
    
    // MARK: View Methods
    
    /// Resets internal data, sets initial UI, and configures the table view.
    override func viewDidLoad() {
        super.viewDidLoad()
        let filteredActionSets = home.actionSets.filter { actionSet in
            return !actionSet.actions.isEmpty
        }

        actionSets = filteredActionSets.sortByTypeAndLocalizedName()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
        
        /*
            If we have a trigger, set the saved properties to the current properties
            of the passed-in trigger.
        */
        if let trigger = trigger {
            selectedActionSets = trigger.actionSets
            nameField.text = trigger.name
            enabledSwitch.isOn = trigger.isEnabled
        }

        enableSaveButtonIfApplicable()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.actionSetCell)
    }
    
    // MARK: IBAction Methods
    
    /**
        Any time the name field changed, reevaluate whether or not
        to enable the save button.
    */
    @IBAction func nameFieldDidChange(_ sender: UITextField) {
        enableSaveButtonIfApplicable()
    }
    
    /// Saves the trigger and dismisses this view controller.
    @IBAction func saveAndDismiss() {
        saveButton.isEnabled = false
        triggerCreator?.saveTriggerWithName(trimmedName, actionSets: selectedActionSets) { trigger, errors in
            self.trigger = trigger
            self.saveButton.isEnabled = true
            
            if !errors.isEmpty {
                self.displayErrors(errors)
                return
            }

            self.enableTrigger(self.trigger!) {
                self.dismiss()
            }
        }
    }
    
    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Subclass Methods
    
    /**
        Generates the section for the index.
        
        This allows for the subclasses to lay out their content in different sections 
        while still maintaining common code in the `TriggerViewController`.
        
        - parameter index: The index of the section
        
        - returns:  The `TriggerTableViewSection` for the provided index.
    */
    func sectionForIndex(_ index: Int) -> TriggerTableViewSection? {
        return nil
    }
    
    // MARK: Helper Methods
    
    /// Enable the trigger if necessary.
    func enableTrigger(_ trigger: HMTrigger, completion: @escaping () -> Void) {
        if trigger.isEnabled == enabledSwitch.isOn {
            completion()
            return
        }

        trigger.enable(enabledSwitch.isOn) { error in
            if let error = error {
                self.displayError(error)
            }
            else {
                completion()
            }
        }
    }
    
    /**
        Enables the save button if:
        
        1. The name field is not empty, and
        2. There will be at least one action set in the trigger after saving.
    */
    private func enableSaveButtonIfApplicable() {
        saveButton.isEnabled = !trimmedName.characters.isEmpty &&
            (!selectedActionSets.isEmpty || trigger?.actionSets.count ?? 0 > 0)
    }
    
    /// - returns:  The name from the `nameField`, stripping newline and whitespace characters.
    var trimmedName: String {
        return nameField.text!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // MARK: Table View Methods
    
    /// Creates a cell that represents either a selected or unselected action set cell.
    private func tableView(_ tableView: UITableView, actionSetCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.actionSetCell, for: indexPath)
        let actionSet = actionSets[indexPath.row]

        if selectedActionSets.contains(actionSet)  {
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        
        cell.textLabel?.text = actionSet.name
        
        return cell
    }
    
    
    /// Only handles the ActionSets case, defaults to super.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sectionForIndex(section) == .actionSets {
            return actionSets?.count ?? 0
        }

        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    /// Only handles the ActionSets case, defaults to super.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if sectionForIndex(indexPath.section) == .actionSets {
            return self.tableView(tableView, actionSetCellForRowAtIndexPath: indexPath)
        }

        return super.tableView(tableView, cellForRowAt: indexPath)
    }
    
    /**
        This is necessary for mixing static and dynamic table view cells.
        We return a fake index path because otherwise the superclass's implementation (which does not
        know about the extra cells we're adding) will cause an error.
        
        - returns:  The superclass's indentationLevel for the first row in the provided section,
                    instead of the provided row.
    */
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        let newIndexPath = IndexPath(row: 0, section: indexPath.section)

        return super.tableView(tableView, indentationLevelForRowAt: newIndexPath)
    }
    
    /**
        Tell the tableView to automatically size the custom rows, while using the superclass's
        static sizing for the static cells.
    */
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sectionForIndex(indexPath.section) {
            case .name?, .enabled?:
                return super.tableView(tableView, heightForRowAt: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return UITableViewAutomaticDimension
        }
    }
    
    /// Handles row selction for action sets, defaults to super implementation.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if sectionForIndex(indexPath.section) == .actionSets {
            self.tableView(tableView, didSelectActionSetAtIndexPath: indexPath)
        }
    }
    
    /**
        Manages footer titles for higher-level sections. Superclasses should fall back
        on this implementation after attempting to handle any special trigger sections.
    */
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sectionForIndex(section) {
            case .actionSets?:
                return NSLocalizedString("When this trigger is activated, it will set these scenes. You can only select scenes which have at least one action.", comment: "Scene Trigger Description")
                
            case .enabled?:
                return NSLocalizedString("This trigger will only activate if it is enabled. You can disable triggers to temporarily stop them from running.", comment: "Trigger Enabled Description")
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, titleForFooterInSection: section)
        }
    }
    
    /**
        Handle selection of an action set cell. If the action set is already part of the selected action sets,
        then remove it from the selected list. Otherwise, add it to the selected list.
    */
    func tableView(_ tableView: UITableView, didSelectActionSetAtIndexPath indexPath: IndexPath) {
        let actionSet = actionSets[indexPath.row]
        if let index = selectedActionSets.index(of: actionSet) {
            selectedActionSets.remove(at: index)
        }
        else {
            selectedActionSets.append(actionSet)
        }

        enableSaveButtonIfApplicable()
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    // MARK: HMHomeDelegate Methods
    
    /**
        If our trigger has been removed from the home,
        dismiss the view controller.
    */
    func home(_ home: HMHome, didRemoveTrigger trigger: HMTrigger) {
        if self.trigger == trigger{
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    /// If our trigger has been updated, reload our data.
    func home(_ home: HMHome, didUpdateTrigger trigger: HMTrigger) {
        if self.trigger == trigger{
            tableView.reloadData()
        }
    }
}
