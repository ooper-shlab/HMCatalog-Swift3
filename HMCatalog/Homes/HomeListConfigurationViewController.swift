/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `HomeListConfigurationViewController` allows for the creation and deletion of homes.
*/

import UIKit
import HomeKit

// Represents the sections in the `HomeListConfigurationViewController`.
enum HomeListSection: Int {
    case homes, primaryHome
    
    static let count = 2
}

/**
    A `HomeListViewController` subclass which allows the user to add and remove 
    homes and set the primary home.
*/
class HomeListConfigurationViewController: HomeListViewController {
    // MARK: Types
    
    struct Identifiers {
        static let addHomeCell = "AddHomeCell"
        static let noHomesCell = "NoHomesCell"
        static let primaryHomeCell = "PrimaryHomeCell"
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of sections in the `HomeListSection` enum.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return HomeListSection.count
    }
    
    /// Provides the number of rows in the section using the internal home's list.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch HomeListSection(rawValue: section) {
            // Add row.
            case .homes?:
                return homes.count + 1

            // 'No homes' row.
            case .primaryHome?:
                return max(homes.count, 1)
            
            case nil: fatalError("Unexpected `HomeListSection` raw value.")
        }
    }
    
    /**
        Generates and configures either a content cell or an add cell using the 
        provided index path.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPathIsAdd(indexPath) {
            return tableView.dequeueReusableCell(withIdentifier: Identifiers.addHomeCell, for: indexPath)
        }
        else if homes.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: Identifiers.noHomesCell, for: indexPath)
        }
        
        let reuseIdentifier: String

        switch HomeListSection(rawValue: indexPath.section) {
            case .homes?:
                reuseIdentifier = Identifiers.homeCell

            case .primaryHome?:
                reuseIdentifier = Identifiers.primaryHomeCell
            
            case nil: fatalError("Unexpected `HomeListSection` raw value.")
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        let home = homes[indexPath.row]
        
        cell.textLabel!.text = home.name
        cell.detailTextLabel?.text = sharedTextForHome(home)
        
        // Mark the primary home with checkmark.
        if HomeListSection(rawValue: indexPath.section) == .primaryHome {
            if home == homeManager.primaryHome {
                cell.accessoryType = .checkmark
            }
            else {
                cell.accessoryType = .none
            }
        }
        
        return cell
    }
    
    /// Homes in the list section can be deleted. The add row cannot be deleted.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return HomeListSection(rawValue: indexPath.section) == .homes && !indexPathIsAdd(indexPath)
    }
    
    /// Only the 'primary home' section has a title.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if HomeListSection(rawValue: section) == .primaryHome {
            return NSLocalizedString("Primary Home", comment: "Primary Home")
        }

        return nil
    }
    
    /// Provides subtext about the use of designating a "primary home".
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == HomeListSection.primaryHome.rawValue {
            return NSLocalizedString("The primary home is used by Siri to route commands if the home is not specified.", comment: "Primary Home Description")
        }
        return nil
    }
    
    /**
        If selecting a regular home, a segue will be performed.
        If this method is called, the user either selected the 'add' row,
        a primary home cell, or the `No Homes` cell.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPathIsAdd(indexPath) {
            addNewHome()
        }
        else if indexPathIsNone(indexPath) {
            return
        }
        else if HomeListSection(rawValue: indexPath.section) == .primaryHome {
            let newPrimaryHome = homes[indexPath.row]
            updatePrimaryHome(newPrimaryHome)
        }
    }
    
    /// Removes the home from HomeKit if the row is deleted.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeHomeAtIndexPath(indexPath)
        }
    }
    
    // MARK: Helper Methods
    
    /**
        Updates the primary home in HomeKit and reloads the view.
        If the home is already selected, no action is taken.
        
        - parameter newPrimaryHome: The new `HMHome` to set as the primary home.
    */
    private func updatePrimaryHome(_ newPrimaryHome: HMHome) {
        guard newPrimaryHome != homeManager.primaryHome else { return }

        homeManager.updatePrimaryHome(newPrimaryHome) { error in
            if let error = error {
                self.displayError(error)
                return
            }
            
            self.didUpdatePrimaryHome()
        }
    }
    
    /// Reloads the 'primary home' section.
    private func didUpdatePrimaryHome() {
        let primaryIndexSet = IndexSet(integer: HomeListSection.primaryHome.rawValue)
      
        tableView.reloadSections(primaryIndexSet, with: .automatic)
    }
    
    /**
        Removed the home at the specified index path from HomeKit and updates the view.
        
        - parameter indexPath: The `NSIndexPath` of the home to remove.
    */
    private func removeHomeAtIndexPath(_ indexPath: IndexPath) {
        let home = homes[indexPath.row]

        // Remove the home from the data structure. If it fails, put it back.
        didRemoveHome(home)
        homeManager.removeHome(home) { error in
            if let error = error {
                self.displayError(error)
                self.didAddHome(home)
                return
            }
        }
    }
    
    /**
        Presents an alert controller so the user can provide a name. If committed, 
        the home is created.
    */
    private func addNewHome() {
        let attributedType = NSLocalizedString("Home", comment: "Home")
        let placeholder = NSLocalizedString("Apartment", comment: "Apartment")

        presentAddAlertWithAttributeType(attributedType, placeholder: placeholder) { name in
            self.addHomeWithName(name)
        }
    }
    
    /**
        Removes a home from the internal structure and updates the view.
        
        - parameter home: The `HMHome` to remove.
    */
    override func didRemoveHome(_ home: HMHome) {
        guard let index = homes.index(of: home) else { return }

        let indexPath = IndexPath(row: index, section: HomeListSection.homes.rawValue)
        homes.remove(at: index)
        let primaryIndexPath = IndexPath(row: index, section: HomeListSection.primaryHome.rawValue)
        
        /*
            If there aren't any homes, we still want one cell to display 'No Homes'.
            Just reload.
        */
        tableView.beginUpdates()
        if homes.isEmpty {
            tableView.reloadRows(at: [primaryIndexPath], with: .fade)
        }
        else {
            tableView.deleteRows(at: [primaryIndexPath], with: .automatic)
        }
        tableView.deleteRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()

    }
    
    /// Adds the home to the internal structure and updates the view.
    override func didAddHome(_ home: HMHome) {
        homes.append(home)
        sortHomes()
        guard let newHomeIndex = homes.index(of: home) else { return }

        let indexPath = IndexPath(row: newHomeIndex, section: HomeListSection.homes.rawValue)
        
        let primaryIndexPath = IndexPath(row: newHomeIndex, section: HomeListSection.primaryHome.rawValue)
        
        tableView.beginUpdates()
        
        if homes.count == 1 {
            tableView.reloadRows(at: [primaryIndexPath], with: .fade)
        }
        else {
            tableView.insertRows(at: [primaryIndexPath], with: .automatic)
        }
        
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
    }
    
    /**
        Creates a new home with the provided name, adds the home to HomeKit
        and reloads the view.
    */
    private func addHomeWithName(_ name: String) {
        homeManager.addHome(withName: name) { newHome, error in
            if let error = error {
                self.displayError(error)
                return
            }

            self.didAddHome(newHome!)
        }
    }
    

    /// - returns:  `true` if the index path is the 'add row'; `false` otherwise.
    private func indexPathIsAdd(_ indexPath: IndexPath) -> Bool {
        return HomeListSection(rawValue: indexPath.section) == .homes &&
            indexPath.row == homes.count
    }
    
    /// - returns:  `true` if the index path is the 'No Homes' cell; `false` otherwise.
    private func indexPathIsNone(_ indexPath: IndexPath) -> Bool {
        return HomeListSection(rawValue: indexPath.section) == .primaryHome && homes.isEmpty
    }
    
    // MARK: HMHomeDelegate Methods
    
    /// Finds the home in the internal structure and reloads the corresponding row.
    override func homeDidUpdateName(_ home: HMHome) {
        if let index = homes.index(of: home) {
            let listIndexPath = IndexPath(row: index, section: HomeListSection.homes.rawValue)

            let primaryIndexPath = IndexPath(row: index, section: HomeListSection.primaryHome.rawValue)
            
            tableView.reloadRows(at: [listIndexPath, primaryIndexPath], with: .automatic)
        }
        else {
            // Just reload the data since we don't know the index path.
            tableView.reloadData()
        }
    }
    
    // MARK: HMHomeManagerDelegate Methods
    
    /// Reloads the 'primary home' section.
    func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        didUpdatePrimaryHome()
    }
}
