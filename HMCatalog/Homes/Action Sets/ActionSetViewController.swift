/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ActionSetViewController` allows users to create and modify action sets.
*/


import UIKit
import HomeKit

/// Represents table view sections of the `ActionSetViewController`.
enum ActionSetTableViewSection: Int {
    case name, actions, accessories
}

/**
    A view controller that facilitates creation of Action Sets.

    It contains a cell for a name, and lists accessories within a home.
    If there are actions within the action set, it also displays a list of ActionCells displaying those actions.
    It owns an `ActionSetCreator` and routes events to the creator as appropriate.
*/
class ActionSetViewController: HMCatalogViewController {
    // MARK: Types
    
    struct Identifiers {
        static let accessoryCell = "AccessoryCell"
        static let unreachableAccessoryCell = "UnreachableAccessoryCell"
        static let actionCell = "ActionCell"
        static let showServiceSegue = "Show Services"
    }
    
    // MARK: Properties
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    var actionSet: HMActionSet?
    var actionSetCreator: ActionSetCreator!
    var displayedAccessories = [HMAccessory]()
    
    // MARK: View Methods
    
    /**
        Creates the action set creator, registers the appropriate reuse identifiers in the table,
        and sets the `nameField` if appropriate.
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        actionSetCreator = ActionSetCreator(actionSet: actionSet, home: home)
        displayedAccessories = home.sortedControlAccessories

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.accessoryCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.unreachableAccessoryCell)
        tableView.register(ActionCell.self, forCellReuseIdentifier: Identifiers.actionCell)
        
        tableView.rowHeight = UITableViewAutomaticDimension
        
        tableView.estimatedRowHeight = 44.0
        
        if let actionSet = actionSet {
            nameField.text = actionSet.name
            nameFieldDidChange(nameField)
        }
        
        if !home.isAdmin {
            nameField.isEnabled = false
        }
    }
    
    /// Reloads the data and view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        enableSaveButtonIfNecessary()
    }
    
    /// Dismisses the view controller if our data is invalid.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldPopViewController() {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    /// Dismisses the keyboard when we dismiss.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }
    
    /// Passes our accessory into the `ServicesViewController`.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Identifiers.showServiceSegue {
            let servicesViewController = segue.intendedDestinationViewController as! ServicesViewController
            servicesViewController.onlyShowsControlServices = true
            servicesViewController.cellDelegate = actionSetCreator

            let index = tableView.indexPath(for: sender as! UITableViewCell)!.row
            
            servicesViewController.accessory = displayedAccessories[index]
            servicesViewController.cellDelegate = actionSetCreator
        }
    }
    
    // MARK: IBAction Methods
    
    /// Dismisses the view controller.
    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Saves the action set, adds it to the home, and dismisses the view.
    @IBAction func saveAndDismiss() {
        saveButton.isEnabled = false

        actionSetCreator.saveActionSetWithName(trimmedName) { error in
            self.saveButton.isEnabled = true
        
            if let error = error {
                self.displayError(error)
            }
            else {
                self.dismiss()
            }
        }
    }
    
    /// Prompts an update to the save button enabled state.
    @IBAction func nameFieldDidChange(_ field: UITextField) {
        enableSaveButtonIfNecessary()
    }
    
    // MARK: Table View Methods
    
    /// We do not allow the creation of action sets in a shared home.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return home.isAdmin ? 3 : 2
    }
    
    /**
        - returns:  In the Actions section: the number of actions this set will contain upon saving.
                    In the Accessories section: The number of accessories in the home.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ActionSetTableViewSection(rawValue: section) {
            case .name?:
                return super.tableView(tableView, numberOfRowsInSection: section)
                
            case .actions?:
                return max(actionSetCreator.allCharacteristics.count, 1)
                
            case .accessories?:
                return displayedAccessories.count
                
            case nil:
                fatalError("Unexpected `ActionSetTableViewSection` raw value.")
        }
    }
    
    /**
        Required override to allow for a tableView with both static and dynamic content.
        Basically, since the superclass's indentationLevelForRowAtIndexPath is only
        expecting 1 row per section, just call the super class's implementation 
        for the first row.
    */
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: indexPath.section))
    }
    
    /// Removes the action associated with the index path.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let characteristic = actionSetCreator.allCharacteristics[indexPath.row]
            actionSetCreator.removeTargetValueForCharacteristic(characteristic) {
                if self.actionSetCreator.containsActions {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                else {
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        }
    }
    
    /// - returns:  `true` for the Actions section; `false` otherwise.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return ActionSetTableViewSection(rawValue: indexPath.section) == .actions && home.isAdmin
    }
    
    /// - returns:  `UITableViewAutomaticDimension` for dynamic sections, otherwise the superclass's implementation.
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch ActionSetTableViewSection(rawValue: indexPath.section) {
            case .name?:
                return super.tableView(tableView, heightForRowAt: indexPath)
                
            case .actions?, .accessories?:
                return UITableViewAutomaticDimension
                
            case nil:
                fatalError("Unexpected `ActionSetTableViewSection` raw value.")
        }
    }
    
    /// - returns:  An action cell for the actions section, an accessory cell for the accessory section, or the superclass's implementation.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch ActionSetTableViewSection(rawValue: indexPath.section) {
            case .name?:
                return super.tableView(tableView, cellForRowAt: indexPath)
                
            case .actions?:
                if actionSetCreator.containsActions {
                    return self.tableView(tableView, actionCellForRowAtIndexPath: indexPath)
                }
                else {
                    return super.tableView(tableView, cellForRowAt: indexPath)
                }
                
            case .accessories?:
                return self.tableView(tableView, accessoryCellForRowAtIndexPath: indexPath)
            
            case nil:
                fatalError("Unexpected `ActionSetTableViewSection` raw value.")
        }
    }
    
    // MARK: Helper Methods
    
    /// Enables the save button if there is a valid name and at least one action.
    private func enableSaveButtonIfNecessary() {
        saveButton.isEnabled = home.isAdmin && trimmedName.characters.count > 0 && actionSetCreator.containsActions
    }
    
    /// - returns:  The contents of the nameField, with whitespace trimmed from the beginning and end.
    private var trimmedName: String {
        return nameField.text!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /**
        - returns:  `true` if there are no accessories in the home, we have no set action set,
                    or if our home no longer exists; `false` otherwise
    */
    private func shouldPopViewController() -> Bool {
        if homeStore.home?.accessories.count == 0 && actionSet == nil {
            return true
        }
        
        return !homeStore.homeManager.homes.contains { $0 == homeStore.home }
    }
    
    /// - returns:  An `ActionCell` instance with the target value for the characteristic at the specified index path.
    private func tableView(_ tableView: UITableView, actionCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.actionCell, for: indexPath) as! ActionCell
        let characteristic = actionSetCreator.allCharacteristics[indexPath.row] as HMCharacteristic

        if let target = actionSetCreator.targetValueForCharacteristic(characteristic) {
            cell.setCharacteristic(characteristic, targetValue: target)
        }
        
        return cell
    }
    
    /// - returns:  An Accessory cell that contains an accessory's name.
    private func tableView(_ tableView: UITableView, accessoryCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        /*
            These cells are static, the identifiers are defined in the Storyboard,
            but they're not recognized here. In viewDidLoad:, we're registering 
            `UITableViewCell` as the class for "AccessoryCell" and "UnreachableAccessoryCell". 
            We must configure these cells manually, the cells in the Storyboard 
            are just for reference.
        */
        
        let accessory = displayedAccessories[indexPath.row]
        let cellIdentifier = accessory.isReachable ? Identifiers.accessoryCell : Identifiers.unreachableAccessoryCell
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = accessory.name
        
        if accessory.isReachable {
            cell.textLabel?.textColor = UIColor.darkText
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        else {
            cell.textLabel?.textColor = UIColor.lightGray
            cell.accessoryType = .none
            cell.selectionStyle = .none
        }
        
        return cell
    }
    
    /// Shows the services in the selected accessory.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.selectionStyle == .none {
            return
        }

        if ActionSetTableViewSection(rawValue: indexPath.section) == .accessories {
            performSegue(withIdentifier: Identifiers.showServiceSegue, sender: cell)
        }
    }
    
    // MARK: HMHomeDelegate Methods
    
    /**
        Pops the view controller if our configuration is invalid;
        reloads the view otherwise.
    */
    func home(_ home: HMHome, didRemoveAccessory accessory: HMAccessory) {
        if shouldPopViewController() {
            self.dismiss(animated: true, completion: nil)
        }
        else {
            tableView.reloadData()
        }
    }
    
    /// Reloads the table view data.
    func home(_ home: HMHome, didAddAccessory accessory: HMAccessory) {
        tableView.reloadData()
    }
    
    /// If our action set was removed, dismiss the view.
    func home(_ home: HMHome, didRemoveActionSet actionSet: HMActionSet) {
        if actionSet == self.actionSet {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
