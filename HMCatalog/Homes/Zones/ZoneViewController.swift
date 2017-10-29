/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ZoneViewController` lists the rooms in a zone.
*/

import UIKit
import HomeKit

/// A view controller that lists the rooms within a provided zone.
class ZoneViewController: HMCatalogViewController {
    // MARK: Types
    
    struct Identifiers {
        static let roomCell = "RoomCell"
        static let addCell = "AddCell"
        static let disabledAddCell = "DisabledAddCell"
        static let addRoomsSegue = "Add Rooms"
    }
    
    // MARK: Properties
    
    var homeZone: HMZone!
    var rooms = [HMRoom]()
    
    // MARK: View Methods
    
    /// Reload the data and configure the view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = homeZone.name
        reloadData()
    }
    
    /// If our data is invalid, pop the view controller.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldPopViewController() {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    /// Provide the zone to `AddRoomViewController`.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Identifiers.addRoomsSegue {
            let addViewController = segue.intendedDestinationViewController as! AddRoomViewController
            addViewController.homeZone = homeZone
        }
    }
    
    // MARK: Helper Methods
    
    /// Resets the internal list of rooms and reloads the table view.
    private func reloadData() {
        rooms = homeZone.rooms.sortByLocalizedName()
        tableView.reloadData()
    }
    
    /// Sorts the internal list of rooms by localized name.
    private func sortRooms() {
        rooms = rooms.sortByLocalizedName()
    }
    
    /// - returns:  The `NSIndexPath` where the 'Add Cell' should be located.
    private var addIndexPath: IndexPath {
        return IndexPath(row: rooms.count, section: 0)
    }
    
    /**
        - parameter indexPath: The index path in question.
        
        - returns:  `true` if the indexPath should contain
                    an 'add' cell, `false` otherwise
    */
    private func indexPathIsAdd(_ indexPath: IndexPath) -> Bool {
        return indexPath.row == addIndexPath.row
    }
    
    /**
        Reloads the `addIndexPath`.
        
        This is typically used when something has changed to allow
        the user to add a room.
    */
    private func reloadAddIndexPath() {
        tableView.reloadRows(at: [addIndexPath], with: .automatic)
    }
    
    /**
        Adds a room to the internal array of rooms and inserts new row
        into the table view.
        
        - parameter room: The new `HMRoom` to add.
    */
    private func didAddRoom(_ room: HMRoom) {
        rooms.append(room)

        sortRooms()
        
        if let newRoomIndex = rooms.index(of: room) {
            let newRoomIndexPath = IndexPath(row: newRoomIndex, section: 0)
            tableView.insertRows(at: [newRoomIndexPath], with: .automatic)
        }
        
        reloadAddIndexPath()
    }
    
    /**
        Removes a room from the internal array of rooms and deletes
        the row from the table view.
        
        - parameter room: The `HMRoom` to remove.
    */
    private func didRemoveRoom(_ room: HMRoom) {
        if let roomIndex = rooms.index(of: room) {
            rooms.remove(at: roomIndex)
            let roomIndexPath = IndexPath(row: roomIndex, section: 0)
            tableView.deleteRows(at: [roomIndexPath], with: .automatic)
        }

        reloadAddIndexPath()
    }
    
    /**
        Reloads the cell corresponding a given room.
        
        - parameter room: The `HMRoom` to reload.
    */
    private func didUpdateRoom(_ room: HMRoom) {
        if let roomIndex = rooms.index(of: room) {
            let roomIndexPath = IndexPath(row: roomIndex, section: 0)
            tableView.reloadRows(at: [roomIndexPath], with: .automatic)
        }
    }
    
    /**
        Removes a room from HomeKit and updates the view.
        
        - parameter room: The `HMRoom` to remove.
    */
    private func removeRoom(_ room: HMRoom) {
        didRemoveRoom(room)
        homeZone.removeRoom(room) { error in
            if let error = error {
                self.displayError(error)
                self.didAddRoom(room)
            }
        }
    }
    
    /**
        - returns:  `true` if our current home no longer
                    exists, `false` otherwise.
    */
    private func shouldPopViewController() -> Bool {
        for zone in home.zones {
            if zone == homeZone {
                return false
            }
        }
        return true
    }
    
    /**
        - returns:  `true` if more rooms can be added to this zone;
                    `false` otherwise.
    */
    private var canAddRoom: Bool {
        return rooms.count < home.rooms.count
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of rooms in the zone, plus 1 for the 'add' row.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rooms.count + 1
    }
    
    /// - returns:  A cell containing the name of an HMRoom.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPathIsAdd(indexPath) {
            let reuseIdentifier = home.isAdmin && canAddRoom ? Identifiers.addCell : Identifiers.disabledAddCell

            return tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.roomCell, for: indexPath)
        
        cell.textLabel?.text = rooms[indexPath.row].name
        
        return cell
    }
    
    /**
        - returns:  `true` if the cell is anything but an 'add' cell;
                    `false` otherwise.
    */
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return home.isAdmin && !indexPathIsAdd(indexPath)
    }
    
    /// Deletes the room at the provided index path.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let room = rooms[indexPath.row]

            removeRoom(room)
        }
    }
    
    // MARK: HMHomeDelegate Methods
    
    /// If our zone was removed, pop the view controller.
    func home(_ home: HMHome, didRemoveZone zone: HMZone) {
        if zone == homeZone{
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    /// If our zone was renamed, update the title.
    func home(_ home: HMHome, didUpdateNameForZone zone: HMZone) {
        if zone == homeZone {
            title = zone.name
        }
    }

    /// Update the row for the room.
    func home(_ home: HMHome, didUpdateNameForRoom room: HMRoom) {
        didUpdateRoom(room)
    }
    
    /**
        A room has been added, we may be able to add it to the zone.
        Reload the 'addIndexPath'
    */
    func home(_ home: HMHome, didAddRoom room: HMRoom) {
        reloadAddIndexPath()
    }
    
    /**
        A room has been removed, attempt to remove it from the room.
        This will always reload the 'addIndexPath'.
    */
    func home(_ home: HMHome, didRemoveRoom room: HMRoom) {
        didRemoveRoom(room)
    }
    
    /// If the room was added to our zone, add it to the view.
    func home(_ home: HMHome, didAddRoom room: HMRoom, toZone zone: HMZone) {
        if zone == homeZone {
            didAddRoom(room)
        }
    }
    
    /// If the room was removed from our zone, remove it from the view.
    func home(_ home: HMHome, didRemoveRoom room: HMRoom, fromZone zone: HMZone) {
        if zone == homeZone {
            didRemoveRoom(room)
        }
    }
}
