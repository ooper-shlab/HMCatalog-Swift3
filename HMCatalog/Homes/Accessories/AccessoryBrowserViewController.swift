/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `AccessoryBrowserViewController` displays new accessories and allows the user to pair with them.
*/

import UIKit
import HomeKit
import ExternalAccessory

/// Represents an accessory type and encapsulated accessory.
enum AccessoryType: Equatable, Nameable {
    /// A HomeKit object
    case homeKit(accessory: HMAccessory)
    
    /// An external, `EAWiFiUnconfiguredAccessory` object
    case external(accessory: EAWiFiUnconfiguredAccessory)
    
    /// The name of the accessory.
    var name: String {
        return accessory.name
    }
    
    /// The accessory within the `AccessoryType`.
    var accessory: AnyObject {
        switch self {
            case .homeKit(let accessory):
                return accessory

            case .external(let accessory):
                return accessory
        }
    }
}

/// Comparison of `AccessoryType`s based on name.
func ==(lhs: AccessoryType, rhs: AccessoryType) -> Bool {
    return lhs.name == rhs.name
}

/**
    A view controller that displays a list of nearby accessories and allows the 
    user to add them to the provided HMHome.
*/
class AccessoryBrowserViewController: HMCatalogViewController, ModifyAccessoryDelegate, EAWiFiUnconfiguredAccessoryBrowserDelegate, HMAccessoryBrowserDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let accessoryCell = "AccessoryCell"
        static let addedAccessoryCell = "AddedAccessoryCell"
        static let addAccessorySegue = "Add Accessory"
    }
    
    // MARK: Properties
    
    var addedAccessories = [HMAccessory]()
    var displayedAccessories = [AccessoryType]()
    let accessoryBrowser = HMAccessoryBrowser()
    var externalAccessoryBrowser: EAWiFiUnconfiguredAccessoryBrowser?
    
    // MARK: View Methods
    
    /// Configures the table view and initializes the accessory browsers.
    override func viewDidLoad() {
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableViewAutomaticDimension
        accessoryBrowser.delegate = self

        #if arch(arm)
        // We can't use the ExternalAccessory framework on the iPhone simulator.
        externalAccessoryBrowser = EAWiFiUnconfiguredAccessoryBrowser(delegate: self, queue: DispatchQueue.main)
        #endif
        
        startBrowsing()
    }
    
    /// Reloads the view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTable()
    }
    
    // MARK: IBAction Methods
    
    /// Stops browsing and dismisses the view controller.
    @IBAction func dismiss(_ sender: AnyObject) {
        stopBrowsing()
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Sets the accessory, home, and delegate of a ModifyAccessoryViewController.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let sender = sender as? HMAccessory , segue.identifier == Identifiers.addAccessorySegue {
            let modifyViewController = segue.intendedDestinationViewController as! ModifyAccessoryViewController
            modifyViewController.accessory = sender
            modifyViewController.delegate = self
        }
    }
    
    // MARK: Table View Methods
    
    /**
        Generates the number of rows based on the number of displayed accessories.
        
        This method will also display a table view background message, if required.
        
        - returns:  The number of rows based on the number of displayed accessories.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = displayedAccessories.count

        if rows == 0 {
            let message = NSLocalizedString("No Discovered Accessories", comment: "No Discovered Accessories")
            setBackgroundMessage(message)
        }
        else {
            setBackgroundMessage(nil)
        }

        return rows
    }
    
    /**
        - returns:  Creates a cell that lists an accessory, and if it hasn't been added to the home,
                    shows a disclosure indicator instead of a checkmark.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let accessoryType = displayedAccessories[indexPath.row]

        var reuseIdentifier = Identifiers.accessoryCell
        
        if case let .homeKit(hmAccessory) = accessoryType , addedAccessories.contains(hmAccessory) {
            reuseIdentifier = Identifiers.addedAccessoryCell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = accessoryType.name

        if let accessory = accessoryType.accessory as? HMAccessory {
            cell.detailTextLabel?.text = accessory.category.localizedDescription
        }
        else {
            cell.detailTextLabel?.text = NSLocalizedString("External Accessory", comment: "External Accessory")
        }
        
        return cell
    }
    
    /// Configures the accessory based on its type.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch displayedAccessories[indexPath.row] {
            case .homeKit(let accessory):
                configureAccessory(accessory)

            case .external(let accessory):
                externalAccessoryBrowser?.configureAccessory(accessory, withConfigurationUIOn: self)
        }
    }
    
    // MARK: Helper Methods
    
    /// Starts browsing on both HomeKit and External accessory browsers.
    private func startBrowsing(){
        accessoryBrowser.startSearchingForNewAccessories()
        externalAccessoryBrowser?.startSearchingForUnconfiguredAccessories(matching: nil)
    }
    
    /// Stops browsing on both HomeKit and External accessory browsers.
    private func stopBrowsing(){
        accessoryBrowser.stopSearchingForNewAccessories()
        externalAccessoryBrowser?.stopSearchingForUnconfiguredAccessories()
    }
    
    /**
        Concatenates and sorts the discovered and added accessories.
        
        - returns:  A sorted list of all accessories involved with this
                    browser session.
    */
    func allAccessories() -> [AccessoryType] {
        var accessories = [AccessoryType]()
        accessories += accessoryBrowser.discoveredAccessories.map { .homeKit(accessory: $0) }

        accessories += addedAccessories.flatMap { addedAccessory in
            let accessoryType = AccessoryType.homeKit(accessory: addedAccessory)
            
            return accessories.contains(accessoryType) ? nil : accessoryType
        }
        
        if let external = externalAccessoryBrowser?.unconfiguredAccessories {
            let unconfiguredAccessoriesArray = Array(external)

            accessories += unconfiguredAccessoriesArray.flatMap { addedAccessory in
                let accessoryType = AccessoryType.external(accessory: addedAccessory)
                
                return accessories.contains(accessoryType) ? nil : accessoryType
            }
        }
        
        return accessories.sortByLocalizedName()
    }
    
    /// Updates the displayed accesories array and reloads the table view.
    private func reloadTable() {
        displayedAccessories = allAccessories()
        tableView.reloadData()
    }
    
    /// Sends the accessory to the next view.
    func configureAccessory(_ accessory: HMAccessory) {
        if displayedAccessories.contains(.homeKit(accessory: accessory)) {
            performSegue(withIdentifier: Identifiers.addAccessorySegue, sender: accessory)
        }
    }
    
    /**
        Finds an unconfigured accessory with a specified name.
        
        - parameter name: The name string of the accessory.
        
        - returns:  An `HMAccessory?` from the search; `nil` if
                    the accessory could not be found.
    */
    func unconfiguredHomeKitAccessoryWithName(_ name: String) -> HMAccessory? {
        for type in displayedAccessories {
            if case let .homeKit(accessory) = type , accessory.name == name {
                return accessory
            }
        }
        return nil
    }
    
    // MARK: ModifyAccessoryDelegate Methods
    
    /// Adds the accessory to the internal array and reloads the views.
    func accessoryViewController(_ accessoryViewController: ModifyAccessoryViewController, didSaveAccessory accessory: HMAccessory) {
        addedAccessories.append(accessory)
        reloadTable()
    }
    
    // MARK: EAWiFiUnconfiguredAccessoryBrowserDelegate Methods
    
    // Any updates to the external accessory browser causes a reload in the table view.
    
    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didFindUnconfiguredAccessories accessories: Set<EAWiFiUnconfiguredAccessory>) {
        reloadTable()
    }
    
    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didRemoveUnconfiguredAccessories accessories: Set<EAWiFiUnconfiguredAccessory>) {
        reloadTable()
    }
    
    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didUpdate state: EAWiFiUnconfiguredAccessoryBrowserState) {
        reloadTable()
    }
    
    /// If the configuration was successful, presents the 'Add Accessory' view.
    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didFinishConfiguringAccessory accessory: EAWiFiUnconfiguredAccessory, with status: EAWiFiUnconfiguredAccessoryConfigurationStatus) {
        if status != .success {
            return
        }
        
        if let foundAccessory = unconfiguredHomeKitAccessoryWithName(accessory.name) {
            configureAccessory(foundAccessory)
        }
    }
    
    // MARK: HMAccessoryBrowserDelegate Methods
    
    /**
        Inserts the accessory into the internal array and inserts the
        row into the table view.
    */
    func accessoryBrowser(_ browser: HMAccessoryBrowser, didFindNewAccessory accessory: HMAccessory) {
        let newAccessory = AccessoryType.homeKit(accessory: accessory)
        if displayedAccessories.contains(newAccessory)  {
            return
        }
        displayedAccessories.append(newAccessory)
        displayedAccessories = displayedAccessories.sortByLocalizedName()

        if let newIndex = displayedAccessories.index(of: newAccessory) {
            let newIndexPath = IndexPath(row: newIndex, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        }
    }
    
    /**
        Removes the accessory from the internal array and deletes the
        row from the table view.
    */
    func accessoryBrowser(_ browser: HMAccessoryBrowser, didRemoveNewAccessory accessory: HMAccessory) {
        let removedAccessory = AccessoryType.homeKit(accessory: accessory)
        if !displayedAccessories.contains(removedAccessory)  {
            return
        }
        if let removedIndex = displayedAccessories.index(of: removedAccessory) {
            let removedIndexPath = IndexPath(row: removedIndex, section: 0)
            displayedAccessories.remove(at: removedIndex)
            tableView.deleteRows(at: [removedIndexPath], with: .automatic)
        }
    }
}
