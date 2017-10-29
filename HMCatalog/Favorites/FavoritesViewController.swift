/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `FavoritesViewController` allows users to control pinned accessories.
*/

import UIKit
import HomeKit

/**
    Lists favorite characteristics (grouped by accessory) and allows users to 
    manipulate their values.
*/
class FavoritesViewController: UITableViewController, UITabBarControllerDelegate, HMAccessoryDelegate, HMHomeManagerDelegate {
    
    // MARK: Types
    
    struct Identifiers {
        static let characteristicCell = "CharacteristicCell"
        static let segmentedControlCharacteristicCell = "SegmentedControlCharacteristicCell"
        static let switchCharacteristicCell = "SwitchCharacteristicCell"
        static let sliderCharacteristicCell = "SliderCharacteristicCell"
        static let textCharacteristicCell = "TextCharacteristicCell"
        static let serviceTypeCell = "ServiceTypeCell"
    }
    
    // MARK: Properties
    
    var favoriteAccessories = FavoritesManager.sharedManager.favoriteAccessories
    
    var cellDelegate = AccessoryUpdateController()
    
    @IBOutlet weak var editButton: UIBarButtonItem!
    
    /// If `true`, the characteristic cells should show stars.
    var showsFavorites = false {
        didSet {
            editButton.title = showsFavorites ? NSLocalizedString("Done", comment: "Done") : NSLocalizedString("Edit", comment: "Edit")

            reloadData()
        }
    }
    
    // MARK: View Methods
    
    /// Configures the table view and tab bar.
    override func awakeFromNib() {
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.allowsSelectionDuringEditing = true

        registerReuseIdentifiers()
        
        tabBarController?.delegate = self
    }
    
    /// Prepares HomeKit objects and reloads view.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerAsDelegate()
        
        setNotificationsEnabled(true)
        
        reloadData()
    }
    
    /// Disables notifications and "unregisters" as the delegate for the home manager.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setNotificationsEnabled(false)

        // We don't want any more callbacks once the view has disappeared.
        HomeStore.sharedStore.homeManager.delegate = nil
    }
    
    /// Registers for all types of characteristic cells.
    private func registerReuseIdentifiers() {
        let characteristicNib = UINib(nibName: Identifiers.characteristicCell, bundle: nil)
        tableView.register(characteristicNib, forCellReuseIdentifier: Identifiers.characteristicCell)
        
        let sliderNib = UINib(nibName: Identifiers.sliderCharacteristicCell, bundle: nil)
        tableView.register(sliderNib, forCellReuseIdentifier: Identifiers.sliderCharacteristicCell)
        
        let switchNib = UINib(nibName: Identifiers.switchCharacteristicCell, bundle: nil)
        tableView.register(switchNib, forCellReuseIdentifier: Identifiers.switchCharacteristicCell)
        
        let segmentedNib = UINib(nibName: Identifiers.segmentedControlCharacteristicCell, bundle: nil)
        tableView.register(segmentedNib, forCellReuseIdentifier: Identifiers.segmentedControlCharacteristicCell)
        
        let textNib = UINib(nibName: Identifiers.textCharacteristicCell, bundle: nil)
        tableView.register(textNib, forCellReuseIdentifier: Identifiers.textCharacteristicCell)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.serviceTypeCell)
    }
    
    // MARK: Table View Methods
    
    /**
        Provides the number of sections based on the favorite accessories count.
        Also, add/removes the background message, if required.
        
        - returns:  The favorite accessories count.
    */
    override func numberOfSections(in tableView: UITableView) -> Int {
        let sectionCount = favoriteAccessories.count
        
        if sectionCount == 0 {
            let message = NSLocalizedString("No Favorite Characteristics", comment: "No Favorite Characteristics")

            setBackgroundMessage(message)
        }
        else {
            setBackgroundMessage(nil)
        }
        
        return sectionCount
    }
    
    /// - returns:  The number of characteristics for accessory represented by the section index.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let accessory = favoriteAccessories[section]

        let characteristics = FavoritesManager.sharedManager.favoriteCharacteristicsForAccessory(accessory)
        
        return characteristics.count
    }
    
    /**
        Dequeues the appropriate characteristic cell for the characteristic at the
        given index path and configures the cell based on view configurations.
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let characteristics = FavoritesManager.sharedManager.favoriteCharacteristicsForAccessory(favoriteAccessories[indexPath.section])
        
        let characteristic = characteristics[indexPath.row]
        
        var reuseIdentifier = Identifiers.characteristicCell

        if characteristic.isReadOnly || characteristic.isWriteOnly {
            reuseIdentifier = Identifiers.characteristicCell
        }
        else if characteristic.isBoolean {
            reuseIdentifier = Identifiers.switchCharacteristicCell
        }
        else if characteristic.hasPredeterminedValueDescriptions {
            reuseIdentifier = Identifiers.segmentedControlCharacteristicCell
        }
        else if characteristic.isNumeric {
            reuseIdentifier = Identifiers.sliderCharacteristicCell
        }
        else if characteristic.isTextWritable {
            reuseIdentifier = Identifiers.textCharacteristicCell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! CharacteristicCell

        cell.showsFavorites = showsFavorites
        cell.delegate = cellDelegate
        cell.characteristic = characteristic

        return cell
    }
    
    /// - returns:  The name of the accessory at the specified index path.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return favoriteAccessories[section].name
    }
    
    // MARK: IBAction Methods
    
    /// Toggles `showsFavorites`, which will also reload the view.
    @IBAction func didTapEdit(_ sender: UIBarButtonItem) {
        showsFavorites = !showsFavorites
    }
    
    
    // MARK: Helper Methods
    
    /**
        Resets the `favoriteAccessories` array from the `FavoritesManager`,
        resets the state of the edit button, and reloads the data.
    */
    private func reloadData() {
        favoriteAccessories = FavoritesManager.sharedManager.favoriteAccessories

        editButton.isEnabled = !favoriteAccessories.isEmpty
        
        tableView.reloadData()
    }
    
    /**
        Enables or disables notifications for all favorite characteristics which
        support event notifications.
        
        - parameter notificationsEnabled: A `Bool` representing enabled or disabled.
    */
    private func setNotificationsEnabled(_ notificationsEnabled: Bool) {
        for characteristic in FavoritesManager.sharedManager.favoriteCharacteristics {
            if characteristic.supportsEventNotification {
                characteristic.enableNotification(notificationsEnabled) { error in
                    if let error = error {
                        print("HomeKit: Error enabling notification on characteristic \(characteristic): \(error.localizedDescription).")
                    }
                }
            }
        }
    }
    
    /**
        Registers as the delegate for the home manager and all
        favorite accessories.
    */
    private func registerAsDelegate() {
        HomeStore.sharedStore.homeManager.delegate = self

        for accessory in favoriteAccessories {
            accessory.delegate = self
        }
    }
    
    // MARK: HMAccessoryDelegate Methods
    
    /// Update the view to disable cells with unavailable accessories.
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        reloadData()
    }
    
    /// Search for the cell corresponding to that characteristic and update its value.
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        guard let accessory = characteristic.service?.accessory else { return }

        guard let indexOfAccessory = favoriteAccessories.index(of: accessory) else { return }
        
        let favoriteCharacteristics = FavoritesManager.sharedManager.favoriteCharacteristicsForAccessory(accessory)
        
        guard let indexOfCharacteristic = favoriteCharacteristics.index(of: characteristic) else { return }
        
        let indexPath = IndexPath(row: indexOfCharacteristic, section: indexOfAccessory)
        
        let cell = tableView.cellForRow(at: indexPath) as! CharacteristicCell
        
        cell.setValue(characteristic.value as? CellValueType, notify: false)
    }
    
    // MARK: HMHomeManagerDelegate Methods
    
    /// Reloads views and re-configures characteristics.
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        registerAsDelegate()
        setNotificationsEnabled(true)
        reloadData()
    }
}
