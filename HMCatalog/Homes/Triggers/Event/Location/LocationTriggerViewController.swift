/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `LocationTriggerViewController` allows the user to modify and create Location triggers.
*/

import UIKit
import MapKit
import HomeKit
import AddressBookUI
import Contacts

/// A view controller which facilitates the creation of a location trigger.
class LocationTriggerViewController: EventTriggerViewController {
    
    struct Identifiers {
        static let locationCell = "LocationCell"
        static let regionStatusCell = "RegionStatusCell"
        static let selectLocationSegue = "Select Location"
    }
    
    static let geocoder = CLGeocoder()
    
    static let regionStatusTitles = [
        NSLocalizedString("When I Enter The Area", comment: "When I Enter The Area"),
        NSLocalizedString("When I Leave The Area", comment: "When I Leave The Area")
    ]
    
    var locationTriggerCreator: LocationTriggerCreator {
        return triggerCreator as! LocationTriggerCreator
    }
    
    var localizedAddress: String?
    
    var viewIsDisplayed = false
    
    // MARK: View Methods
    
    /// Initializes a trigger creator and registers for table view cells.
    override func viewDidLoad() {
        super.viewDidLoad()
        triggerCreator = LocationTriggerCreator(trigger: trigger, home: home)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.locationCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.regionStatusCell)
    }
    
    /**
        Generates an address string for the current region location and
        reloads the table view.
    */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewIsDisplayed = true
        if let region = locationTriggerCreator.targetRegion {
            let centerLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            LocationTriggerViewController.geocoder.reverseGeocodeLocation(centerLocation) { placemarks, error in
                if !self.viewIsDisplayed {
                    // The geocoder took too long, we're not on this view any more.
                    return
                }
                if let error = error {
                    self.displayError(error)
                    return
                }
                if let mostLikelyPlacemark = placemarks?.first {
                    let address = CNMutablePostalAddress(placemark: mostLikelyPlacemark)
                    let addressFormatter = CNPostalAddressFormatter()
                    let addressString = addressFormatter.string(from: address)
                    self.localizedAddress = addressString.replacingOccurrences(of: "\n", with: ", ")
                    let section = IndexSet(integer: 2)
                    self.tableView.reloadSections(section, with: .automatic)
                }
            }
        }
        tableView.reloadData()
    }
    
    /// Passes the trigger creator and region into the `MapViewController`.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Identifiers.selectLocationSegue {
            guard let destinationVC = segue.intendedDestinationViewController as? MapViewController else { return }
            // Give the map the previous target region (if exists).
            destinationVC.targetRegion = locationTriggerCreator.targetRegion
            destinationVC.delegate = locationTriggerCreator
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsDisplayed = false
    }
    
    // MARK: Table View Methods
    
    /**
        - returns:  The number of rows in the Region section;
                    defaults to the super implementation for other sections.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionForIndex(section) {
            case .region?:
                return 2
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    /**
        Generates a cell based on the section.
        Handles Region and Location sections, defaults to
        super implementations for other sections.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionForIndex(indexPath.section) {
            case .region?:
                return self.tableView(tableView, regionStatusCellForRowAtIndexPath: indexPath)
                
            case .location?:
                return self.tableView(tableView, locationCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    /// Generates the single location cell.
    private func tableView(_ tableView: UITableView, locationCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.locationCell, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        
        if locationTriggerCreator.targetRegion != nil {
            cell.textLabel?.text = localizedAddress ?? NSLocalizedString("Update Location", comment: "Update Location")
        }
        else {
            cell.textLabel?.text = NSLocalizedString("Set Location", comment: "Set Location")
        }
        return cell
    }
    
    /// Generates the cell which allow the user to select either 'on enter' or 'on exit'.
    private func tableView(_ tableView: UITableView, regionStatusCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.regionStatusCell, for: indexPath)
        cell.textLabel?.text = LocationTriggerViewController.regionStatusTitles[indexPath.row]
        cell.accessoryType = (locationTriggerCreator.targetRegionStateIndex == indexPath.row) ? .checkmark : .none
        return cell
    }
    
    /**
        Allows the user to select a location or change the region status.
        Defaults to the super implmentation for other sections.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sectionForIndex(indexPath.section) {
            case .location?:
                performSegue(withIdentifier: Identifiers.selectLocationSegue, sender: self)
                
            case .region?:
                locationTriggerCreator.targetRegionStateIndex = indexPath.row
                let reloadIndexSet = IndexSet(integer: indexPath.section)
                tableView.reloadSections(reloadIndexSet, with: .automatic)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    /**
        - returns:  A localized title for the Location and Region sections.
                    Defaults to the super implmentation for other sections.
    */
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sectionForIndex(section) {
            case .location?:
                return NSLocalizedString("Location", comment: "Location")
                
            case .region?:
                return NSLocalizedString("Region Status", comment: "Region Status")
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    
    /**
        - returns:  A localized description of the region status.
                    Defaults to the super implmentation for other sections.
    */
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sectionForIndex(section) {
            case .region?:
                return NSLocalizedString("This trigger can activate when you enter or leave a region. For example, when you arrive at home or when you leave work.", comment: "Location Region Description")
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, titleForFooterInSection: section)
        }
    }
    
    // MARK: Trigger Controller Methods
    
    /**
        - parameter index: The section index.
        
        - returns: The `TriggerTableViewSection` for the given index.
    */
    override func sectionForIndex(_ index: Int) -> TriggerTableViewSection? {
        switch index {
            case 0:
                return .name
                
            case 1:
                return .enabled
                
            case 2:
                return .location
                
            case 3:
                return .region
                
            case 4:
                return .conditions
                
            case 5:
                return .actionSets
                
            default:
                return nil
        }
    }
}
