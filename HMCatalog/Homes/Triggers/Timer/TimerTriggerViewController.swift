/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `TimerTriggerViewController` allows the user to create Timer triggers.
*/

import UIKit
import HomeKit

/// A view controller which facilitates the creation of timer triggers.
class TimerTriggerViewController: TriggerViewController {
    // MARK: Types
    
    struct Identifiers {
        static let recurrenceCell = "RecurrenceCell"
    }
    
    static let RecurrenceTitles = [
        NSLocalizedString("Every Hour", comment: "Every Hour"),
        NSLocalizedString("Every Day", comment: "Every Day"),
        NSLocalizedString("Every Week", comment: "Every Week")
    ]
    
    // MARK: Properties
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
    /**
        Sets the stored fireDate to the new value.
        HomeKit only accepts dates aligned with minute boundaries,
        so we use NSDateComponents to only get the appropriate pieces of information from that date.
        Eventually we will end up with a date following this format: "MM/dd/yyyy hh:mm"
    */
    
    var timerTrigger: HMTimerTrigger? {
        return trigger as? HMTimerTrigger
    }
    
    var timerTriggerCreator: TimerTriggerCreator {
        return triggerCreator as! TimerTriggerCreator
    }
    
    // MARK: View Methods
    
    /// Configures the views and registers for table view cells.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
        triggerCreator = TimerTriggerCreator(trigger: trigger, home: home)
        datePicker.date = timerTriggerCreator.fireDate as Date
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.recurrenceCell)
    }
    
    // MARK: IBAction Methods
    
    /// Reset our saved fire date to the date in the picker.
    @IBAction func didChangeDate(_ picker: UIDatePicker) {
        timerTriggerCreator.rawFireDate = picker.date
    }
    
    // MARK: Table View Methods
    
    /**
        - returns:  The number of rows in the Recurrence section;
                    defaults to the super implementation for other sections
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionForIndex(section) {
            case .recurrence?:
                return TimerTriggerViewController.RecurrenceTitles.count
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    /**
        Generates a recurrence cell.
        Defaults to the super implementation for other sections
    */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionForIndex(indexPath.section) {
            case .recurrence?:
                return self.tableView(tableView, recurrenceCellForRowAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")

            default:
                return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    /// Creates a cell that represents a recurrence type.
    func tableView(_ tableView: UITableView, recurrenceCellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.recurrenceCell, for: indexPath)
        let title = TimerTriggerViewController.RecurrenceTitles[indexPath.row]
        cell.textLabel?.text = title
        
        // The current preferred recurrence style should have a check mark.
        if indexPath.row == timerTriggerCreator.selectedRecurrenceIndex {
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    /**
        Tell the tableView to automatically size the custom rows, while using the superclass's
        static sizing for the static cells.
    */
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sectionForIndex(indexPath.section) {
            case .recurrence?:
                return UITableViewAutomaticDimension
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    /**
        Handles recurrence cell selection.
        Defaults to the super implementation for other sections
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sectionForIndex(indexPath.section) {
            case .recurrence?:
                self.tableView(tableView, didSelectRecurrenceComponentAtIndexPath: indexPath)
                
            case nil:
                fatalError("Unexpected `TriggerTableViewSection` raw value.")
                
            default:
                super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    /**
        Handles selection of a recurrence cell.
        
        If the newly selected recurrence component is the previously selected
        recurrence component, reset the current selected component to `NSNotFound`
        and deselect that row.
    */
    func tableView(_ tableView: UITableView, didSelectRecurrenceComponentAtIndexPath indexPath: IndexPath) {
        if indexPath.row == timerTriggerCreator.selectedRecurrenceIndex {
            timerTriggerCreator.selectedRecurrenceIndex = nil
        }
        else {
            timerTriggerCreator.selectedRecurrenceIndex = indexPath.row
        }
        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
    }
    
    /**
        - parameter index: The section index.
        
        - returns:  The `TriggerTableViewSection` for the given index.
    */
    override func sectionForIndex(_ index: Int) -> TriggerTableViewSection? {
        switch index {
            case 0:
                return .name
            
            case 1:
                return .enabled
            
            case 2:
                return .dateAndTime
            
            case 3:
                return .recurrence
            
            case 4:
                return .actionSets
            
            default:
                return nil
        }
    }
    
}
