/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ServicesViewController` displays an accessory's services.
*/

import UIKit
import HomeKit

/// Represents the sections in the `ServicesViewController`.
enum AccessoryTableViewSection: Int {
    case services, bridgedAccessories
}

/**
    A view controller which displays all the services of a provided accessory, and 
    passes its cell delegate onto a `CharacteristicsViewController`.
*/
class ServicesViewController: HMCatalogViewController, HMAccessoryDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let accessoryCell = "AccessoryCell"
        static let serviceCell = "ServiceCell"
        static let showServiceSegue = "Show Service"
    }
    
    // MARK: Properties
    
    var accessory: HMAccessory!
    lazy var cellDelegate: CharacteristicCellDelegate = AccessoryUpdateController()
    var showsFavorites = false
    var allowsAllWrites = false
    var onlyShowsControlServices = false
    var displayedServices = [HMService]()
    var bridgedAccessories = [HMAccessory]()
    
    // MARK: View Methods
    
    /// Configures table view.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    /// Reloads the view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitle()
        reloadData()
    }
    
    /// Pops the view controller, if required.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldPopViewController() {
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }
    
    /**
        Passes the `CharacteristicsViewController` the service from the cell and
        configures the view controller.
    */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard segue.identifier == Identifiers.showServiceSegue else { return }
        
        if let indexPath = tableView.indexPath(for: sender as! UITableViewCell) {
            let selectedService = displayedServices[indexPath.row]
            let characteristicsViewController = segue.intendedDestinationViewController as! CharacteristicsViewController
            characteristicsViewController.showsFavorites = showsFavorites
            characteristicsViewController.allowsAllWrites = allowsAllWrites
            characteristicsViewController.service = selectedService
            characteristicsViewController.cellDelegate = cellDelegate
        }
    }
    
    /**
        - returns:  `true` if our accessory is no longer in the
                    current home's list of accessories.
    */
    private func shouldPopViewController() -> Bool {
        for accessory in homeStore.home!.accessories {
            if accessory == accessory {
                return false
            }
        }
        return true
    }
    
    // MARK: Delegate Registration
    
    /**
        Registers as the delegate for the current home
        and for the current accessory.
    */
    override func registerAsDelegate() {
        super.registerAsDelegate()
        accessory.delegate = self
    }
    
    // MARK: Table View Methods
    
    /// Two sections if we're showing bridged accessories.
    override func numberOfSections(in tableView: UITableView) -> Int {
        if accessory.uniqueIdentifiersForBridgedAccessories != nil {
            return 2
        }
        return 1
    }
    
    /**
        Section 1 contains the services within the accessory.
        Section 2 contains the bridged accessories.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch AccessoryTableViewSection(rawValue: section) {
            case .services?:
                return displayedServices.count
                
            case .bridgedAccessories?:
                return bridgedAccessories.count
                
            case nil:
                fatalError("Unexpected `AccessoryTableViewSection` raw value.")
        }
    }
    
    /**
        - returns:  A Service or Bridged Accessory Cell based
                    on the section.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch AccessoryTableViewSection(rawValue: indexPath.section) {
            case .services?:
                return self.tableView(tableView, serviceCellForRowAtIndexPath: indexPath)
                
            case .bridgedAccessories?:
                return self.tableView(tableView, bridgedAccessoryCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `AccessoryTableViewSection` raw value.")
        }
    }
    
    /**
        - returns:  A cell containing the name of a bridged
                    accessory at a given index path.
    */
    func tableView(_ tableView: UITableView, bridgedAccessoryCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.accessoryCell, for: indexPath)
        let accessory = bridgedAccessories[indexPath.row]
        cell.textLabel?.text = accessory.name
        return cell
    }
    
    /**
        - returns:  A cell containing the name of a service at
                    a given index path, as well as a localized
                    description of its service type.
    */
    func tableView(_ tableView: UITableView, serviceCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.serviceCell, for: indexPath)
        let service = displayedServices[indexPath.row]
        
        // Inherit the name from the accessory if the Service doesn't have one.
        cell.textLabel?.text = service.name
        cell.detailTextLabel?.text = service.localizedDescription
        return cell
    }
    
    /// - returns:  A title string for the section.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch AccessoryTableViewSection(rawValue: section) {
            case .services?:
                return NSLocalizedString("Services", comment: "Services")
                
            case .bridgedAccessories?:
                return NSLocalizedString("Bridged Accessories", comment: "Bridged Accessories")
                
            case nil:
                fatalError("Unexpected `AccessoryTableViewSection` raw value.")
        }
    }
    
    /// - returns:  A localized description of the accessories bridged status.
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if accessory.isBridged && AccessoryTableViewSection(rawValue: section)! == .services {
            let formatString = NSLocalizedString("This accessory is being bridged into HomeKit by %@.", comment: "Bridge Description")
            if let bridge = home.bridgeForAccessory(accessory) {
                return String(format: formatString, bridge.name)
            }
            else {
                return NSLocalizedString("This accessory is being bridged into HomeKit.", comment: "Bridge Description Without Bridge")
            }
        }
        return nil
    }
    
    // MARK: Helper Methods
    
    /// Updates the navigation bar's title.
    func updateTitle() {
        navigationItem.title = accessory.name
    }
    
    /**
        Updates the title, resets the displayed services based on
        view controller configurations, reloads the bridge accessory
        array and reloads the table view.
    */
    private func reloadData() {
        displayedServices = accessory.services.sortByLocalizedName()
        if onlyShowsControlServices {
            // We are configured to only show control services, filter the array.
            displayedServices = displayedServices.filter { service -> Bool in
                return service.isControlType
            }
        }
        
        if let identifiers = accessory.uniqueIdentifiersForBridgedAccessories {
            bridgedAccessories = home.accessoriesWithIdentifiers(identifiers).sortByLocalizedName()
        }
        tableView.reloadData()
    }
    
    // MARK:  HMAccessoryDelegate Methods
    
    /// Reloads the title based on the accessories new name.
    func accessoryDidUpdateName(_ accessory: HMAccessory) {
        updateTitle()
    }
    
    /// Reloads the cell for the specified service.
    func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService) {
        if let index = displayedServices.index(of: service) {
            let path = IndexPath(row: index, section: AccessoryTableViewSection.services.rawValue)
            tableView.reloadRows(at: [path], with: .automatic)
        }
    }
    
    /// Reloads the view.
    func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        reloadData()
    }
    
    /// If our accessory has become unreachable, go back the previous view.
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        if self.accessory == accessory {
            _ = navigationController?.popViewController(animated: true)
        }
    }
}
