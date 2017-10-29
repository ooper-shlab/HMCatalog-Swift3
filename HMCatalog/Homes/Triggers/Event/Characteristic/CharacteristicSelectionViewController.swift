/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `CharacteristicSelectionViewController` allows for the selection of characteristics.
                This is mainly used for creating characteristic events and conditions
*/

import UIKit
import HomeKit

/**
    Allows for the selection of characteristics.
    This is mainly used for creating characteristic events and conditions
*/
class CharacteristicSelectionViewController: HMCatalogViewController {
    // MARK: Types
    
    struct Identifiers {
        static let accessoryCell = "AccessoryCell"
        static let unreachableAccessoryCell = "UnreachableAccessoryCell"
        static let showServicesSegue = "Show Services"
    }
    
    // MARK: Properties
    
    var eventTrigger: HMEventTrigger?
    var triggerCreator: EventTriggerCreator!
    
    /// An internal copy of all controllable accessories in the home.
    private var accessories = [HMAccessory]()
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    // MARK: View Methods
    
    /// Resets the internal array of accessories from the home.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Only take accessories which have one control service.
        accessories = home.sortedControlAccessories
    }
    
    /// Configures the `ServicesViewController` and passes it the correct accessory.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Identifiers.showServicesSegue {
            let senderCell = sender as! UITableViewCell
            let servicesVC = segue.intendedDestinationViewController as! ServicesViewController
            let cellIndex = tableView.indexPath(for: senderCell)!.row
            servicesVC.allowsAllWrites = true
            servicesVC.onlyShowsControlServices = true
            servicesVC.accessory = accessories[cellIndex]
            servicesVC.cellDelegate = triggerCreator
        }
    }
    
    // MARK: IBAction Methods
    
    /**
        Updates the predicates in the trigger creator and then
        dismisses the view controller.
    */
    @IBAction func didTapSave(_ sender: UIBarButtonItem) {
        /*
            We should not save the trigger completely, the user still has a chance to bail out.
            Instead, we generate all of the predicates that were in the map.
        */
        triggerCreator.updatePredicates()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Table View Methods
    
    /// Single section view controller.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    /// - returns:  The number of accessories. If there are none, will return 1 (for the 'none row').
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(accessories.count, 1)
    }
    
    /// - returns:  An Accessory cell that contains an accessory's name.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let accessory = accessories.sortByLocalizedName()[indexPath.row]
        let cellIdentifier = accessory.isReachable ? Identifiers.accessoryCell : Identifiers.unreachableAccessoryCell
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = accessory.name
        
        return cell
    }
    
    /// Shows the services in the selected accessory.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.selectionStyle == .none {
            return
        }
        performSegue(withIdentifier: Identifiers.showServicesSegue, sender: cell)
    }
    
    /// - returns:  Localized "Accessories" string.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Accessories", comment: "Accessories")
    }
}
