/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `AddServicesViewController` allows users to add services to a service group.
*/

import UIKit
import HomeKit

/**
    A view controller that provides a list of services and lets the user select services to be added to the provided Service Group.

    The services are not added to the service group until the 'Done' button is pressed.
*/
class AddServicesViewController: HMCatalogViewController, HMAccessoryDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let serviceCell = "ServiceCell"
    }
    
    // MARK: Properties
    
    lazy private var displayedAccessories = [HMAccessory]()
    lazy private var displayedServicesForAccessory = [HMAccessory: [HMService]]()
    lazy private var selectedServices = [HMService]()
    
    var serviceGroup: HMServiceGroup!
    
    // MARK: View Methods
    
    /// Reloads internal data and view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectedServices = []
        reloadTable()
    }
    
    /// Registers as the delegate for the home and all accessories.
    override func registerAsDelegate() {
        super.registerAsDelegate()
        for accessory in homeStore.home!.accessories {
            accessory.delegate = self
        }
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of displayed accessories.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return displayedAccessories.count
    }
    
    /// - returns:  The number of displayed services for the provided accessory.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let accessory = displayedAccessories[section]
        return displayedServicesForAccessory[accessory]!.count
    }
    
    /// - returns:  A configured `ServiceCell`.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.serviceCell, for: indexPath) as! ServiceCell
        
        let service = serviceAtIndexPath(indexPath)
        
        cell.includeAccessoryText = false
        cell.service = service
        cell.accessoryType = selectedServices.contains(service)  ? .checkmark : .none

        return cell
    }
    
    /**
        When an indexPath is selected, this function either adds or removes the selected service from the
        service group.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Get the service associated with this index.
        let service = serviceAtIndexPath(indexPath)
        
        // Call the appropriate add/remove operation with the closure from above.
        if let index = selectedServices.index(of: service) {
            selectedServices.remove(at: index)
        }
        else {
            selectedServices.append(service)
        }

        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    /// - returns: The name of the displayed accessory at the given section.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displayedAccessories[section].name
    }
    
    // MARK: Helper Methods
    
    /**
        Adds the selected services to the service group.
        
        Calls the provided completion handler once all services have been added.
    */
    func addSelectedServicesWithCompletionHandler(_ completion: @escaping () -> Void) {
        // Create a dispatch group for each of the service additions.
        let addServicesGroup = DispatchGroup()
        for service in selectedServices {
            addServicesGroup.enter()
            serviceGroup.addService(service) { error in
                if let error = error {
                    self.displayError(error)
                }
                addServicesGroup.leave()
            }
        }
        addServicesGroup.notify(queue: DispatchQueue.main, execute: completion)
    }
    
    /**
        Finds the service at a specific index path.
        
        - parameter indexPath: An `NSIndexPath`
        
        - returns:  The `HMService` at the given index path.
    */
    private func serviceAtIndexPath(_ indexPath: IndexPath) -> HMService {
        let accessory = displayedAccessories[indexPath.section]
        let services = displayedServicesForAccessory[accessory]!
        return services[indexPath.row]
    }
    
    /**
        Commits the changes to the service group
        and dismisses the view.
    */
    @IBAction func dismiss() {
        addSelectedServicesWithCompletionHandler {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    /// Resets internal data and view.
    func reloadTable() {
        resetDisplayedServices()
        tableView.reloadData()
    }
    
    /**
        Updates internal array of accessories and the mapping
        of accessories to selected services.
    */
    func resetDisplayedServices() {
        displayedAccessories = []
        let allAccessories = home.accessories.sortByLocalizedName()
        displayedServicesForAccessory = [:]
        for accessory in allAccessories {
            var displayedServices = [HMService]()
            for service in accessory.services {
                if !serviceGroup.services.contains(service)  && service.serviceType != HMServiceTypeAccessoryInformation {
                    displayedServices.append(service)
                }
            }
            
            // Only add the accessory if it has displayed services.
            if !displayedServices.isEmpty {
                displayedServicesForAccessory[accessory] = displayedServices.sortByLocalizedName()
                displayedAccessories.append(accessory)
            }
        }
    }
    
    // MARK: HMHomeDelegate Methods
    
    /// Dismisses the view controller if our service group was removed.
    func home(_ home: HMHome, didRemoveServiceGroup group: HMServiceGroup) {
        if serviceGroup == group {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    /// Reloads the view if an accessory was added to HomeKit.
    func home(_ home: HMHome, didAddAccessory accessory: HMAccessory) {
        reloadTable()
        accessory.delegate = self
    }
    
    /// Dismisses the view controller if we no longer have accesories.
    func home(_ home: HMHome, didRemoveAccessory accessory: HMAccessory) {
        if home.accessories.isEmpty {
            navigationController?.dismiss(animated: true, completion: nil)
        }
        
        reloadTable()
    }
    
    // MARK: HMAccessoryDelegate Methods
    
    // Accessory changes reload the data and view.

    func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService) {
        reloadTable()
    }
    
    func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        reloadTable()
    }
}
