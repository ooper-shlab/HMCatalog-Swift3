/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ControlsViewController` lists services in the selected home.
*/

import UIKit
import HomeKit

/// A view controller which displays a list of `HMServices`, separated by Service Type.
class ControlsViewController: HMCatalogViewController, HMAccessoryDelegate {
    // MARK: Types
    
    struct Identifiers {
        static let showServiceSegue = "Show Service"
    }
    
    // MARK: Properties
    
    var tableViewDataSource: ControlsTableViewDataSource!
    var cellController = AccessoryUpdateController()
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    // MARK: View Methods
    
    /// Sends the selected service into the destination view controller.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Identifiers.showServiceSegue {
            if let indexPath = tableView.indexPath(for: sender as! UITableViewCell) {
                let characteristicsViewController = segue.intendedDestinationViewController as! CharacteristicsViewController

                if let selectedService = tableViewDataSource.serviceForIndexPath(indexPath) {
                    characteristicsViewController.service = selectedService
                }
                
                characteristicsViewController.cellDelegate = cellController
            }
        }
    }
    
    /// Initializes the table view data source.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewDataSource = ControlsTableViewDataSource(tableView: tableView)
    }
    
    /// Reloads the view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = home.name
        reloadData()
    }
    
    // MARK: Helper Methods
    
    private func reloadData() {
        tableViewDataSource.reloadTable()
        let sections = tableViewDataSource.numberOfSections(in: tableView)

        if sections == 0 {
            setBackgroundMessage(tableViewDataSource.emptyMessage())
        }
        else {
            setBackgroundMessage(nil)
        }
    }
    
    // MARK: Delegate Registration
    
    /// Registers as the delegate for the current home and all accessories in the home.
    override func registerAsDelegate() {
        super.registerAsDelegate()
        for accessory in home.accessories {
            accessory.delegate = self
        }
    }
    
    /*
        Any delegate methods which could change data will reload the
        table view data source.
    */
    
    // MARK: HMHomeDelegate Methods
    
    func home(_ home: HMHome, didAddAccessory accessory: HMAccessory)  {
        accessory.delegate = self
        reloadData()
    }
    
    func home(_ home: HMHome, didRemoveAccessory accessory: HMAccessory)  {
        reloadData()
    }

    // MARK: HMAccessoryDelegate Methods
    
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        reloadData()
    }
    
    func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService)  {
        reloadData()
    }
    
    func accessory(_ accessory: HMAccessory, didUpdateAssociatedServiceTypeFor service: HMService)  {
        reloadData()
    }
    
    func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        reloadData()
    }
    
    func accessoryDidUpdateName(_ accessory: HMAccessory) {
        reloadData()
    }
}
