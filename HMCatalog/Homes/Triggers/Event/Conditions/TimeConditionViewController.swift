/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `TimeConditionViewController` allows the user to create a new time condition.
*/

import UIKit
import HomeKit

/// Represents a section in the `TimeConditionViewController`.
enum TimeConditionTableViewSection: Int {
    /**
        This section contains the segmented control to
        choose a time condition type.
    */
    case timeOrSun
    
    /**
        This section contains cells to allow the selection
        of 'before', 'after', or 'at'. 'At' is only available
        when the exact time is specified.
    */
    case beforeOrAfter
    
    /**
        If the condition type is exact time, this section will
        only have one cell, the date picker cell.
        
        If the condition type is relative to a solar event,
        this section will have two cells, one for 'sunrise' and
        one for 'sunset.
    */
    case value
    
    static let count = 3
}

/**
    Represents the type of time condition.

    The condition can be an exact time, or relative to a solar event.
*/
enum TimeConditionType: Int {
    case time, sun
}

/**
    Represents the type of solar event.

    This can be sunrise or sunset.
*/
enum TimeConditionSunState: Int {
    case sunrise, sunset
}

/**
    Represents the condition order.

    Conditions can be before, after, or exactly at a given time.
*/
enum TimeConditionOrder: Int {
    case before, after, at
}

/// A view controller that facilitates the creation of time conditions for triggers.
class TimeConditionViewController: HMCatalogViewController {
    // MARK: Types
    
    struct Identifiers {
        static let selectionCell = "SelectionCell"
        static let timePickerCell = "TimePickerCell"
        static let segmentedTimeCell = "SegmentedTimeCell"
    }
    
    static let timeOrSunTitles = [
        NSLocalizedString("Relative to time", comment: "Relative to time"),
        NSLocalizedString("Relative to sun", comment: "Relative to sun")
    ]
    
    static let beforeOrAfterTitles = [
        NSLocalizedString("Before", comment: "Before"),
        NSLocalizedString("After", comment: "After"),
        NSLocalizedString("At", comment: "At")
    ]
    
    static let sunriseSunsetTitles = [
        NSLocalizedString("Sunrise", comment: "Sunrise"),
        NSLocalizedString("Sunset", comment: "Sunset")
    ]
    
    // MARK: Properties
    
    private var timeType: TimeConditionType = .time
    private var order: TimeConditionOrder = .before
    private var sunState: TimeConditionSunState = .sunrise
    
    private var datePicker: UIDatePicker?
    
    var triggerCreator: EventTriggerCreator?
    
    // MARK: View Methods
    
    /// Configures the table view.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
    }
    
    // MARK: Table View Methods
    
    /// - returns:  The number of `TimeConditionTableViewSection`s.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return TimeConditionTableViewSection.count
    }
    
    /**
        - returns:  The number rows based on the `TimeConditionTableViewSection`
                    and the `timeType`.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch TimeConditionTableViewSection(rawValue: section) {
            case .timeOrSun?:
                return 1
                
            case .beforeOrAfter?:
                // If we're choosing an exact time, we add the 'At' row.
                return (timeType == .time) ? 3 : 2
                
            case .value?:
                // Date picker cell or sunrise/sunset selection cells
                return (timeType == .time) ? 1 : 2
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
        }
    }
    
    /// Switches based on the section to generate a cell.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch TimeConditionTableViewSection(rawValue: indexPath.section) {
            case .timeOrSun?:
                return self.tableView(tableView, segmentedCellForRowAtIndexPath: indexPath)
                
            case .beforeOrAfter?:
                return self.tableView(tableView, selectionCellForRowAtIndexPath: indexPath)
                
            case .value?:
                switch timeType {
                case .time:
                    return self.tableView(tableView, datePickerCellForRowAtIndexPath: indexPath)
                case .sun:
                    return self.tableView(tableView, selectionCellForRowAtIndexPath: indexPath)
                }
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
        }
    }
    
    /// - returns:  A localized string describing the section.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch TimeConditionTableViewSection(rawValue: section) {
            case .timeOrSun?:
                return NSLocalizedString("Condition Type", comment: "Condition Type")
                
            case .beforeOrAfter?:
                return nil
                
            case .value?:
                if timeType == .time {
                    return NSLocalizedString("Time", comment: "Time")
                }
                else {
                    return NSLocalizedString("Event", comment: "Event")
                }
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
        }
    }
    
    /// - returns:  A localized description for condition type section; `nil` otherwise.
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch TimeConditionTableViewSection(rawValue: section) {
            case .timeOrSun?:
                return NSLocalizedString("Time conditions can relate to specific times or special events, like sunrise and sunset.", comment: "Condition Type Description")
                
            case .beforeOrAfter?:
                return nil
                
            case .value?:
                return nil
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
        }
    }
    
    /// Updates internal values based on row selection.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.selectionStyle == .none {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)

        switch TimeConditionTableViewSection(rawValue: indexPath.section) {
            case .timeOrSun?:
                timeType = TimeConditionType(rawValue: indexPath.row)!
                reloadDynamicSections()
                return
                
            case .beforeOrAfter?:
                order = TimeConditionOrder(rawValue: indexPath.row)!
                tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                
            case .value?:
                if timeType == .sun {
                    sunState = TimeConditionSunState(rawValue: indexPath.row)!
                }
                tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
        }
    }
    
    // MARK: Helper Methods
    
    /**
        Generates a selection cell based on the section.
        Ordering and sun-state sections have selections.
    */
    private func tableView(_ tableView: UITableView, selectionCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.selectionCell, for: indexPath)
        switch TimeConditionTableViewSection(rawValue: indexPath.section) {
            case .beforeOrAfter?:
                cell.textLabel?.text = TimeConditionViewController.beforeOrAfterTitles[indexPath.row]
                cell.accessoryType = (order.rawValue == indexPath.row) ? .checkmark : .none
                
            case .value?:
                if timeType == .sun {
                    cell.textLabel?.text = TimeConditionViewController.sunriseSunsetTitles[indexPath.row]
                    cell.accessoryType = (sunState.rawValue == indexPath.row) ? .checkmark : .none
                }
                
            case nil:
                fatalError("Unexpected `TimeConditionTableViewSection` raw value.")
                
            default:
                break
        }
        return cell
    }
    
    /// Generates a date picker cell and sets the internal date picker when created.
    private func tableView(_ tableView: UITableView, datePickerCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.timePickerCell, for: indexPath) as! TimePickerCell
        // Save the date picker so we can get the result later.
        datePicker = cell.datePicker
        return cell
    }
    
    /// Generates a segmented cell and sets its target when created.
    private func tableView(_ tableView: UITableView, segmentedCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.segmentedTimeCell, for: indexPath) as! SegmentedTimeCell
        cell.segmentedControl.selectedSegmentIndex = timeType.rawValue
        cell.segmentedControl.removeTarget(nil, action: nil, for: .allEvents)
        cell.segmentedControl.addTarget(self, action: #selector(self.segmentedControlDidChange(_:)), for: .valueChanged)
        return cell
    }
    
    /// Creates date components from the date picker's date.
    var dateComponents: DateComponents? {
        guard let datePicker = datePicker else { return nil }
        let flags: Set<Calendar.Component> = [.hour, .minute]
        return Calendar.current.dateComponents(flags, from: datePicker.date)
    }
    
    /**
        Updates the time type and reloads dynamic sections.
        
        - parameter segmentedControl: The segmented control that changed.
    */
    @objc func segmentedControlDidChange(_ segmentedControl: UISegmentedControl) {
        if let segmentedControlType = TimeConditionType(rawValue: segmentedControl.selectedSegmentIndex) {
            timeType = segmentedControlType
        }
        reloadDynamicSections()
    }
    
    /// Reloads the BeforeOrAfter and Value section.
    private func reloadDynamicSections() {
        if timeType == .sun && order == .at {
            order = .before
        }
        let reloadIndexSet = IndexSet(integersIn: Range(NSMakeRange(TimeConditionTableViewSection.beforeOrAfter.rawValue, 2)) ?? 0..<0)
        tableView.reloadSections(reloadIndexSet, with: .automatic)
    }
    
    // MARK: IBAction Methods
    
    /**
        Generates a predicate based on the stored values, adds
        the condition to the trigger, then dismisses the view.
    */
    @IBAction func saveAndDismiss(_ sender: UIBarButtonItem) {
        var predicate: NSPredicate?
        switch timeType {
            case .time:
                switch order {
                    case .before:
                        predicate = HMEventTrigger.predicateForEvaluatingTrigger(occurringBefore: dateComponents!)
                        
                    case .after:
                        predicate = HMEventTrigger.predicateForEvaluatingTrigger(occurringAfter: dateComponents!)
                        
                    case .at:
                        predicate = HMEventTrigger.predicateForEvaluatingTrigger(occurringOn: dateComponents!)
                }
            
            case .sun:
                let significantEventString = (sunState == .sunrise) ? HMSignificantEvent.sunrise : HMSignificantEvent.sunset
                switch order {
                    case .before:
                        predicate = HMEventTrigger.predicateForEvaluatingTrigger(occurringBefore: significantEventString.rawValue, applyingOffset: nil)
                        
                    case .after:
                        predicate = HMEventTrigger.predicateForEvaluatingTrigger(occurringAfter: significantEventString.rawValue, applyingOffset: nil)
                        
                    case .at:
                        // Significant events must be specified 'before' or 'after'.
                        break
                }
        }
        if let predicate = predicate {
            triggerCreator?.addCondition(predicate)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Cancels the creation of the conditions and exits.
    @IBAction func dismiss(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}
