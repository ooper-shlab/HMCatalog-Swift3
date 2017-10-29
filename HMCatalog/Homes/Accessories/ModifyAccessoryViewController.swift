/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The  `ModifyAccessoryViewController` allows the user to modify a HomeKit accessory.
*/

import UIKit
import HomeKit

/// Represents the sections in the `ModifyAccessoryViewController`.
enum AddAccessoryTableViewSection: Int {
    case name, rooms, identify
    
    static let count = 3
}

/// Contains a method for notifying the delegate that the accessory was saved.
protocol ModifyAccessoryDelegate {
    func accessoryViewController(_ accessoryViewController: ModifyAccessoryViewController, didSaveAccessory accessory: HMAccessory)
}

/// A view controller that allows for renaming, reassigning, and identifying accessories before and after they've been added to a home.
class ModifyAccessoryViewController: HMCatalogViewController, HMAccessoryDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let roomCell = "RoomCell"
    }
    
    // MARK: Properties
    
    // Update this if the acessory failed in any way.
    private var didEncounterError = false
    
    private var selectedIndexPath: IndexPath?
    private var selectedRoom: HMRoom!
    
    @IBOutlet weak var nameField: UITextField!
    private lazy var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    private let saveAccessoryGroup = DispatchGroup()
    
    private var editingExistingAccessory = false
    
    // Strong reference, because we will replace the button with an activity indicator.
    @IBOutlet /* strong */ var addButton: UIBarButtonItem!
    var delegate: ModifyAccessoryDelegate?
    var rooms = [HMRoom]()
    
    var accessory: HMAccessory!
    
    // MARK: View Methods
    
    /// Configures the table view and initializes view elements.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableViewAutomaticDimension
        
        selectedRoom = accessory.room ?? home.roomForEntireHome()
        
        // If the accessory belongs to the home already, we are in 'edit' mode.
        editingExistingAccessory = accessoryHasBeenAddedToHome()
        if editingExistingAccessory {
            // Show 'save' instead of 'add.'
            addButton.title = NSLocalizedString("Save", comment: "Save")
        }
        else {
            /*
                If we're not editing an existing accessory, then let the back
                button show in the left.
            */
            navigationItem.leftBarButtonItem = nil
        }
        
        // Put the accessory's name in the 'name' field.
        resetNameField()
        
        // Register a cell for the rooms.
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.roomCell)
    }
    
    /**
        Registers as the delegate for the current home
        and the accessory.
    */
    override func registerAsDelegate() {
        super.registerAsDelegate()
        accessory.delegate = self
    }
    
    /// Replaces the activity indicator with the 'Add' or 'Save' button.
    func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        navigationItem.rightBarButtonItem = addButton
    }
    
    /// Temporarily replaces the 'Add' or 'Save' button with an activity indicator.
    func showActivityIndicator() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        activityIndicator.startAnimating()
    }
    
    /**
        Called whenever the user taps the 'add' button.
        
        This method:
        1. Adds the accessory to the home, if not already added.
        2. Updates the accessory's name, if necessary.
        3. Assigns the accessory to the selected room, if necessary.
    */
    @IBAction func didTapAddButton() {
        let name = trimmedName
        showActivityIndicator()
        
        if editingExistingAccessory {
            home(home, assignAccessory: accessory, toRoom: selectedRoom)
            updateName(name, forAccessory: accessory)
        }
        else {
            saveAccessoryGroup.enter()
            home.addAccessory(accessory) { error in
                if let error = error {
                    self.hideActivityIndicator()
                    self.displayError(error)
                    self.didEncounterError = true
                }
                else {
                    // Once it's successfully added to the home, add it to the room that's selected.
                    self.home(self.home, assignAccessory:self.accessory, toRoom: self.selectedRoom)
                    self.updateName(name, forAccessory: self.accessory)
                }
                self.saveAccessoryGroup.leave()
            }
        }
        
        saveAccessoryGroup.notify(queue: DispatchQueue.main) {
            self.hideActivityIndicator()
            if !self.didEncounterError {
                self.dismiss(nil)
            }
        }
    }
    
    /**
        Informs the delegate that the accessory has been saved, and
        dismisses the view controller.
    */
    @IBAction func dismiss(_ sender: AnyObject?) {
        delegate?.accessoryViewController(self, didSaveAccessory: accessory)
        if editingExistingAccessory {
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
        else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    /**
        - returns: `true` if the accessory has already been added to
                    the home; `false` otherwise.
    */
    func accessoryHasBeenAddedToHome() -> Bool {
        return home.accessories.contains(accessory) 
    }
    
    /**
        Updates the accessories name. This function will enter and leave the saved dispatch group.
        If the accessory's name is already equal to the passed-in name, this method does nothing.
        
        - parameter name:      The new name for the accessory.
        - parameter accessory: The accessory to rename.
    */
    func updateName(_ name: String, forAccessory accessory: HMAccessory) {
        if accessory.name == name {
            return
        }
        saveAccessoryGroup.enter()
        accessory.updateName(name) { error in
            if let error = error {
                self.displayError(error)
                self.didEncounterError = true
            }
            self.saveAccessoryGroup.leave()
        }
    }
    
    /**
        Assigns the given accessory to the provided room. This method will enter and leave the saved dispatch group.
        
        - parameter home:      The home to assign.
        - parameter accessory: The accessory to be assigned.
        - parameter room:      The room to which to assign the accessory.
    */
    func home(_ home: HMHome, assignAccessory accessory: HMAccessory, toRoom room: HMRoom) {
        if accessory.room == room {
            return
        }
        saveAccessoryGroup.enter()
        home.assignAccessory(accessory, to: room) { error in
            if let error = error {
                self.displayError(error)
                self.didEncounterError = true
            }
            self.saveAccessoryGroup.leave()
        }
    }
    
    /// Tells the current accessory to identify itself.
    func identifyAccessory() {
        accessory.identify { error in
            if let error = error {
                self.displayError(error)
            }
        }
    }
    
    /// Enables the name field if the accessory's name changes.
    func resetNameField() {
        var action: String
        if editingExistingAccessory {
            action = NSLocalizedString("Edit %@", comment: "Edit Accessory")
        }
        else {
            action = NSLocalizedString("Add %@", comment: "Add Accessory")
        }
        navigationItem.title = String(format: action, accessory.name) as String
        nameField.text = accessory.name
        nameField.isEnabled = home.isAdmin
        enableAddButtonIfApplicable()
    }
    
    /// Enables the save button if the name field is not empty.
    func enableAddButtonIfApplicable() {
        addButton.isEnabled = home.isAdmin && trimmedName.characters.count > 0
    }
    
    /// - returns:  The `nameField`'s text, trimmed of newline and whitespace characters.
    var trimmedName: String {
        return nameField.text!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /// Enables or disables the add button.
    @IBAction func nameFieldDidChange(_ sender: AnyObject) {
        enableAddButtonIfApplicable()
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of `AddAccessoryTableViewSection`s.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return AddAccessoryTableViewSection.count
    }
    
    /// - returns: The number rows for the rooms section. All other sections are static.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch AddAccessoryTableViewSection(rawValue: section) {
            case .rooms?:
                return home.allRooms.count
                
            case nil:
                fatalError("Unexpected `AddAccessoryTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    /// - returns:  `UITableViewAutomaticDimension` for dynamic cell, super otherwise.
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch AddAccessoryTableViewSection(rawValue: indexPath.section) {
            case .rooms?:
                return UITableViewAutomaticDimension
                
            case nil:
                fatalError("Unexpected `AddAccessoryTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    /// - returns:  A 'room cell' for the rooms section, super otherwise.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch AddAccessoryTableViewSection(rawValue: indexPath.section) {
            case .rooms?:
                return self.tableView(tableView, roomCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `AddAccessoryTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    /**
        Creates a cell with the name of each room within the home, displaying a checkmark if the room
        is the currently selected room.
    */
    func tableView(_ tableView: UITableView, roomCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.roomCell, for: indexPath)
        let room = home.allRooms[indexPath.row] as HMRoom
        
        cell.textLabel?.text = home.nameForRoom(room)
        
        // Put a checkmark on the selected room.
        cell.accessoryType = room == selectedRoom ? .checkmark : .none
        if !home.isAdmin {
            cell.selectionStyle = .none
        }
        return cell
    }
    
    
    /// Handles row selection based on the section.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch AddAccessoryTableViewSection(rawValue: indexPath.section) {
            case .rooms?:
                guard home.isAdmin else { return }

                selectedRoom = home.allRooms[indexPath.row]

                let sections = IndexSet(integer: AddAccessoryTableViewSection.rooms.rawValue)
                
                tableView.reloadSections(sections, with: .automatic)
                
            case .identify?:
                identifyAccessory()
                
            case nil:
                fatalError("Unexpected `AddAccessoryTableViewSection` raw value.")
                
            default: break
        }
    }
    
    /// Required override.
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: indexPath.section))
    }
    
    // MARK: HMHomeDelegate Methods
    
    // All home changes reload the view.
    
    func home(_ home: HMHome, didUpdateNameFor room: HMRoom) {
        tableView.reloadData()
    }
    
    func home(_ home: HMHome, didAddRoom room: HMRoom) {
        tableView.reloadData()
    }
    
    func home(_ home: HMHome, didRemoveRoom room: HMRoom)  {
        if selectedRoom == room {
            // Reset the selected room if ours was deleted.
            selectedRoom = homeStore.home!.roomForEntireHome()
        }
        tableView.reloadData()
    }
    
    func home(_ home: HMHome, didAddAccessory accessory: HMAccessory) {
        /*
            Bridged accessories don't call the original completion handler if their 
            bridges are added to the home. We must respond to `HMHomeDelegate`'s 
            `home(_:didAddAccessory:)` and assign bridged accessories properly.
        */
        if selectedRoom != nil {
            self.home(home, assignAccessory: accessory, toRoom: selectedRoom)
        }
    }
    
    func home(_ home: HMHome, didUnblockAccessory accessory: HMAccessory) {
        tableView.reloadData()
    }
    
    // MARK: HMAccessoryDelegate Methods
    
    /// If the accessory's name changes, we update the name field.
    func accessoryDidUpdateName(_ accessory: HMAccessory) {
        resetNameField()
    }
}
