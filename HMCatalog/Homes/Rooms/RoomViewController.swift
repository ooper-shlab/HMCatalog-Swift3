/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `RoomViewController` lists the accessory within a room.
*/


import UIKit
import HomeKit

/// A view controller that lists the accessories within a room.
class RoomViewController: HMCatalogViewController, HMAccessoryDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let accessoryCell = "AccessoryCell"
        static let unreachableAccessoryCell = "UnreachableAccessoryCell"
        static let modifyAccessorySegue = "Modify Accessory"
    }
    
    // MARK: Properties
    
    var room: HMRoom! {
        didSet {
            navigationItem.title = room.name
        }
    }
    
    var accessories = [HMAccessory]()
    
    // MARK: View Methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of accessories within this room.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = accessories.count
        if rows == 0 {
            let message = NSLocalizedString("No Accessories", comment: "No Accessories")
            setBackgroundMessage(message)
        }
        else {
            setBackgroundMessage(nil)
        }

        return rows
    }
    
    /// - returns:  `true` if the current room is not the home's roomForEntireHome; `false` otherwise.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return room != home.roomForEntireHome()
    }
    
    /// - returns:  Localized "Unassign".
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return NSLocalizedString("Unassign", comment: "Unassign")
    }
    
    /// Assigns the 'deleted' room to the home's roomForEntireHome.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            unassignAccessory(accessories[indexPath.row])
        }
    }
    
    /// - returns:  A cell representing an accessory.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let accessory = accessories[indexPath.row]

        var reuseIdentifier = Identifiers.accessoryCell
        
        if !accessory.isReachable {
            reuseIdentifier = Identifiers.unreachableAccessoryCell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        cell.textLabel?.text = accessory.name
        
        return cell
    }
    
    /// - returns:  A localized description, "Accessories" if there are accessories to list.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if accessories.isEmpty {
            return nil
        }

        return NSLocalizedString("Accessories", comment: "Accessories")
    }
    
    // MARK: Helper Methods
    
    /// Updates the internal array of accessories and reloads the table view.
    private func reloadData() {
        accessories = room.accessories.sortByLocalizedName()
        tableView.reloadData()
    }
    
    /// Sorts the internal list of accessories by localized name.
    private func sortAccessories() {
        accessories = accessories.sortByLocalizedName()
    }
    
    /**
        Registers as the delegate for the current home and
        all accessories in our room.
    */
    override func registerAsDelegate() {
        super.registerAsDelegate()
        for accessory in room.accessories {
            accessory.delegate = self
        }
    }
    
    /// Sets the accessory and home of the modifyAccessoryViewController that will be presented.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        let indexPath = tableView.indexPath(for: sender as! UITableViewCell)!
        if segue.identifier == Identifiers.modifyAccessorySegue {
            let modifyViewController = segue.intendedDestinationViewController as! ModifyAccessoryViewController
            modifyViewController.accessory = room.accessories[indexPath.row]
        }
    }
    
    /**
        Adds an accessory into the internal list of accessories
        and inserts the row into the table view.
    
        - parameter accessory: The `HMAccessory` to add.
    */
    private func didAssignAccessory(_ accessory: HMAccessory) {
        accessories.append(accessory)
        sortAccessories()
        if let newAccessoryIndex = accessories.index(of: accessory) {
            let newAccessoryIndexPath = IndexPath(row: newAccessoryIndex, section: 0)
            tableView.insertRows(at: [newAccessoryIndexPath], with: .automatic)
        }
    }
    
    /**
        Removes an accessory from the internal list of accessory (if it
        exists) and deletes the row from the table view.
    
        - parameter accessory: The `HMAccessory` to remove.
    */
    private func didUnassignAccessory(_ accessory: HMAccessory) {
        if let accessoryIndex = accessories.index(of: accessory) {
            accessories.remove(at: accessoryIndex)
            let accessoryIndexPath = IndexPath(row: accessoryIndex, section: 0)
            tableView.deleteRows(at: [accessoryIndexPath], with: .automatic)
        }
    }
    
    /**
        Assigns an accessory to the current room.
    
        - parameter accessory: The `HMAccessory` to assign to the room.
    */
    private func assignAccessory(_ accessory: HMAccessory) {
        didAssignAccessory(accessory)
        home.assignAccessory(accessory, to: room) { error in
            if let error = error {
                self.displayError(error)
                self.didUnassignAccessory(accessory)
            }
        }
    }
    
    /**
        Assigns the current room back into `roomForEntireHome`.
    
        - parameter accessory: The `HMAccessory` to reassign.
    */
    private func unassignAccessory(_ accessory: HMAccessory) {
        didUnassignAccessory(accessory)
        home.assignAccessory(accessory, to: home.roomForEntireHome()) { error in
            if let error = error {
                self.displayError(error)
                self.didAssignAccessory(accessory)
            }
        }
    }
    
    /**
        Finds an accessory in the internal array of accessories
        and updates its row in the table view.
    
        - parameter accessory: The `HMAccessory` to reload.
    */
    func didModifyAccessory(_ accessory: HMAccessory){
        if let index = accessories.index(of: accessory) {
            let indexPaths = [
                IndexPath(row: index, section: 0)
            ]
            
            tableView.reloadRows(at: indexPaths, with: .automatic)
        }
    }
    
    // MARK: HMHomeDelegate Methods
    
    /// If the accessory was added to this room, insert it.
    func home(_ home: HMHome, didAddAccessory accessory: HMAccessory) {
        if accessory.room == room {
            accessory.delegate = self
            didAssignAccessory(accessory)
        }
    }
    
    /// Remove the accessory from our room, if required.
    func home(_ home: HMHome, didRemoveAccessory accessory: HMAccessory) {
        didUnassignAccessory(accessory)
    }
    
    /**
        Handles the update.
        
        We act based on one of three options:
        
        1. A new accessory is being added to this room.
        2. An accessory is being assigned from this room to another room.
        3. We can ignore this message.
    */
    func home(_ home: HMHome, didUpdateRoom room: HMRoom, forAccessory accessory: HMAccessory) {
        if room == self.room {
            didAssignAccessory(accessory)
        }
        else if accessories.contains(accessory)  {
            didUnassignAccessory(accessory)
        }
    }
    
    /// If our room was removed, pop back.
    func home(_ home: HMHome, didRemoveRoom room: HMRoom) {
        if room == self.room {
            navigationController!.popViewController(animated: true)
        }
    }
    
    /// If our room was renamed, reload our title.
    func home(_ home: HMHome, didUpdateNameFor room: HMRoom) {
        if room == self.room {
            navigationItem.title = room.name
        }
    }
    
    // MARK: HMAccessoryDelegate Methods
    
    // Accessory updates will reload the cell for the accessory.

    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        didModifyAccessory(accessory)
    }
    
    func accessoryDidUpdateName(_ accessory: HMAccessory) {
        didModifyAccessory(accessory)
    }
}
