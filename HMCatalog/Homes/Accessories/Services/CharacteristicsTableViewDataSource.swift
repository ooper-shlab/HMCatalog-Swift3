/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `CharacteristicsTableViewDataSource` provides the data for the `CharacteristicsViewController`.
*/

import UIKit
import HomeKit

/// Represents the sections in the `CharacteristicsViewController`.
enum CharacteristicTableViewSection: Int {
    case characteristics, associatedServiceType
}

/// A `UITableViewDataSource` that populates a `CharacteristicsViewController`.
class CharacteristicsTableViewDataSource: NSObject, UITableViewDelegate, UITableViewDataSource {
    // MARK: Types
    
    struct Identifiers {
        static let characteristicCell = "CharacteristicCell"
        static let sliderCharacteristicCell = "SliderCharacteristicCell"
        static let switchCharacteristicCell = "SwitchCharacteristicCell"
        static let segmentedControlCharacteristicCell = "SegmentedControlCharacteristicCell"
        static let textCharacteristicCell = "TextCharacteristicCell"
        static let serviceTypeCell = "ServiceTypeCell"
    }
    
    // MARK: Properties
    
    var service: HMService
    var tableView: UITableView
    var delegate: CharacteristicCellDelegate
    var showsFavorites: Bool
    var allowsAllWrites: Bool
    
    /// Sets up properties from specified values, configures the table view, and cell reuse identifiers.
    required init(service: HMService, tableView: UITableView, delegate: CharacteristicCellDelegate, showsFavorites: Bool = false, allowsAllWrites: Bool = false) {
        self.service = service
        self.tableView = tableView
        self.delegate = delegate
        self.showsFavorites = showsFavorites
        self.allowsAllWrites = allowsAllWrites
        super.init()
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50.0
        registerReuseIdentifiers()
    }
    
    /// Registers all of the characteristic cell reuse identifiers with this table.
    func registerReuseIdentifiers() {
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
    
    /**
        - returns: The number of sections, computed from whether or not
                   the services supports an associated service type.
    */
    func numberOfSections(in tableView: UITableView) -> Int {
        return service.supportsAssociatedServiceType ? 2 : 1
    }
    
    /**
        The characteristics section uses the services count to generate the number of rows.
        The associated service type uses the valid associated service types.
    */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch CharacteristicTableViewSection(rawValue: section) {
            case .characteristics?:
                return service.characteristics.count
                
            case .associatedServiceType?:
                // For 'None'.
                return HMService.validAssociatedServiceTypes.count + 1
                
            case nil:
                fatalError("Unexpected `CharacteristicTableViewSection` raw value.")
        }
    }
    
    /**
        Looks up the appropriate service type for the row in the list and returns a localized version,
        or 'None' if the row doesn't correspond to any valid service type.
        
        - parameter row: The row to look up.
        
        - returns:  The localized service type in that row, or 'None'.
    */
    func displayedServiceTypeForRow(_ row: Int) -> String {
        let serviceTypes = HMService.validAssociatedServiceTypes
        if row < serviceTypes.count {
            return HMService.localizedDescriptionForServiceType(serviceTypes[row])
        }

        return NSLocalizedString("None", comment: "None")
    }
    
    /**
        Evaluates whether or not a service type is selected for a given row.
        
        - parameter row: The selected row.
        
        - returns:  `true` if the current row is a valid service type, `false` otherwise
    */
    func serviceTypeIsSelectedForRow(_ row: Int) -> Bool {
        let serviceTypes = HMService.validAssociatedServiceTypes
        if row >= serviceTypes.count {
            return service.associatedServiceType == nil
        }
        
        if let associatedServiceType = service.associatedServiceType {
            return serviceTypes[row] == associatedServiceType
        }

        return false
    }
    
    /// Generates a cell for an associated service.
    private func tableView(_ tableView: UITableView, associatedServiceTypeCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.serviceTypeCell, for: indexPath)
        
        cell.textLabel?.text = displayedServiceTypeForRow(indexPath.row)
        cell.accessoryType = serviceTypeIsSelectedForRow(indexPath.row) ? .checkmark : .none

        return cell
    }
    
    /**
        Generates a characteristic cell based on the type of characteristic
        located at the specified index path.
    */
    private func tableView(_ tableView: UITableView, characteristicCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let characteristic = service.characteristics[indexPath.row]

        var reuseIdentifier = Identifiers.characteristicCell
        
        if (characteristic.isReadOnly || characteristic.isWriteOnly) && !allowsAllWrites {
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
        cell.delegate = delegate
        cell.characteristic = characteristic
        
        return cell
    }
    
    /// Uses convenience methods to generate a cell based on the index path's section.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch CharacteristicTableViewSection(rawValue: indexPath.section) {
            case .characteristics?:
                return self.tableView(tableView, characteristicCellForRowAtIndexPath: indexPath)
                
            case .associatedServiceType?:
                return self.tableView(tableView, associatedServiceTypeCellForRowAtIndexPath: indexPath)
            
            case nil:
                fatalError("Unexpected `CharacteristicTableViewSection` raw value.")
        }
    }
    
    /// - returns:  A localized string for the section.
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch CharacteristicTableViewSection(rawValue: section) {
            case .characteristics?:
                return NSLocalizedString("Characteristics", comment: "Characteristics")
                
            case .associatedServiceType?:
                return NSLocalizedString("Associated Service Type", comment: "Associated Service Type")
                
            case nil:
                fatalError("Unexpected `CharacteristicTableViewSection` raw value.")
        }
    }
    
}
