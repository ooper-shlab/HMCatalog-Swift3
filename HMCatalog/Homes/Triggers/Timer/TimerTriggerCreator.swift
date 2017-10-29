/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `TimerTriggerCreator` creates Timer triggers.
*/

import HomeKit

/**
    A `TriggerCreator` subclass which allows for the creation
    of timer triggers.
*/
class TimerTriggerCreator: TriggerCreator {
    static let RecurrenceComponents: [Calendar.Component] = [
        .hour,
        .day,
        .weekOfYear
    ]
    
    // MARK: Properties
    
    var timerTrigger: HMTimerTrigger? {
        return trigger as? HMTimerTrigger
    }
    
    var selectedRecurrenceIndex: Int? = nil
    
    var rawFireDate = Date()
    var fireDate: Date {
        let flags: Set<Calendar.Component> = [.year, .weekday, .month, .day, .hour, .minute]
        let dateComponents = Calendar.current.dateComponents(flags, from: self.rawFireDate)
        let probableDate = Calendar.current.date(from: dateComponents)
        return probableDate ?? rawFireDate
    }
    
    // MARK: Trigger Creator Methods
    
    /// Configures raw fire date and selected recurrence index.
    required init(trigger: HMTrigger?, home: HMHome) {
        super.init(trigger: trigger, home: home)
        if let timerTrigger = timerTrigger {
            rawFireDate = timerTrigger.fireDate
            selectedRecurrenceIndex = recurrenceIndexFromDateComponents(timerTrigger.recurrence)
        }
    }
    
    /// - returns:  A new `HMTimerTrigger` with the stored configurations.
    override func newTrigger() -> HMTrigger? {
        return HMTimerTrigger(name: name, fireDate: fireDate, timeZone: Calendar.current.timeZone, recurrence: recurrenceComponents, recurrenceCalendar: nil)
    }
    
    /// Updates the fire date and recurrence of the trigger.
    override func updateTrigger() {
        updateFireDateIfNecessary()
        updateRecurrenceIfNecessary()
    }
    
    // MARK: Helper Methods
    
    /**
        Creates an NSDateComponent for the selected recurrence type.
        
        - returns: An NSDateComponent where either `weekOfYear`,
                   `hour`, or `day` is set to 1.
    */
    var recurrenceComponents:DateComponents? {
        guard let selectedRecurrenceIndex = selectedRecurrenceIndex else {
            return nil
        }
        var recurrenceComponents = DateComponents()
        let unit = TimerTriggerCreator.RecurrenceComponents[selectedRecurrenceIndex]
        switch unit {
            case .weekOfYear:
                recurrenceComponents.weekOfYear = 1
            
            case .hour:
                recurrenceComponents.hour = 1
            
            case .day:
                recurrenceComponents.day = 1
            
            default:
                break
        }
        return recurrenceComponents
    }
    
    /**
        Maps the possible calendar units associated with recurrence titles, so we can properly
        set our recurrenceUnit when an index is selected.
        
        - parameter components: An optional `NSDateComponents` to query.
        
        - returns: An index for the date components.
    */
    func recurrenceIndexFromDateComponents(_ components: DateComponents?) -> Int? {
        guard let components = components else { return nil }
        var unit: Calendar.Component?
        if components.day == 1 {
            unit = .day
        }
        else if components.weekOfYear == 1 {
            unit = .weekOfYear
        }
        else if components.hour == 1 {
            unit = .hour
        }
        if let unit = unit {
            return TimerTriggerCreator.RecurrenceComponents.index(of: unit)
        }
        return nil
    }
    
    /**
        Updates the trigger's fire date, entering and leaving the dispatch group if necessary.
        If the trigger's fire date is already equal to the passed-in fire date, this method does nothing.
        
        - parameter fireDate: The trigger's new fire date.
    */
    private func updateFireDateIfNecessary() {
        if timerTrigger?.fireDate == fireDate {
            return
        }
        saveTriggerGroup.enter()
        timerTrigger?.updateFireDate(fireDate) { error in
            if let error = error {
                self.errors.append(error)
            }
            self.saveTriggerGroup.leave()
        }
    }
    
    /**
        Updates the trigger's recurrence components, entering and leaving the dispatch group if necessary.
        If the trigger's components are already equal to the passed-in components, this method does nothing.
        
        - parameter recurrenceComponents: The trigger's new recurrence components.
    */
    private func updateRecurrenceIfNecessary() {
        if recurrenceComponents == timerTrigger?.recurrence {
            return
        }
        saveTriggerGroup.enter()
        timerTrigger?.updateRecurrence(recurrenceComponents) { error in
            if let error = error {
                self.errors.append(error)
            }
            self.saveTriggerGroup.leave()
        }
    }
}
