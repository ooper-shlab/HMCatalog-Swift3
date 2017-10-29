/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `NSPredicate+Condition` properties and methods are used to parse the conditions used in `HMEventTrigger`s.
*/

import HomeKit

/// Represents condition type in HomeKit with associated values.
enum HomeKitConditionType {
    /**
        Represents a characteristic condition.
        
        The tuple represents the `HMCharacteristic` and its condition value.
        For example, "Current gargage door is set to 'Open'".
    */
    case characteristic(HMCharacteristic, NSCopying)
    
    /**
        Represents a time condition.
        
        The tuple represents the time ordering and the sun state.
        For example, "Before sunset".
    */
    case sunTime(TimeConditionOrder, TimeConditionSunState)
    
    /**
        Represents an exact time condition.
        
        The tuple represents the time ordering and time.
        For example, "At 12:00pm".
    */
    case exactTime(TimeConditionOrder, DateComponents)
    
    /// The predicate is not a HomeKit condition.
    case unknown
}

extension NSPredicate {
    
    /**
        Parses the predicate and attempts to generate a characteristic-value `HomeKitConditionType`.
        
        - returns:  An optional characteristic-value tuple.
    */
    private func characteristic() -> HomeKitConditionType? {
        guard let predicate = self as? NSCompoundPredicate else { return nil }
        guard let subpredicates = predicate.subpredicates as? [NSPredicate] else { return nil }
        guard subpredicates.count == 2 else { return nil }
        
        var characteristicPredicate: NSComparisonPredicate? = nil
        var valuePredicate: NSComparisonPredicate? = nil
        
        for subpredicate in subpredicates {
            if let comparison = subpredicate as? NSComparisonPredicate , comparison.leftExpression.expressionType == .keyPath && comparison.rightExpression.expressionType == .constantValue {
                switch comparison.leftExpression.keyPath {
                    case HMCharacteristicKeyPath:
                        characteristicPredicate = comparison
                        
                    case HMCharacteristicValueKeyPath:
                        valuePredicate = comparison
                        
                    default:
                        break
                }
            }
        }
        
        if let characteristic = characteristicPredicate?.rightExpression.constantValue as? HMCharacteristic,
            let characteristicValue = valuePredicate?.rightExpression.constantValue as? NSCopying {
                return .characteristic(characteristic, characteristicValue)
        }
        return nil
    }
    
    /**
        Parses the predicate and attempts to generate an order-sunstate `HomeKitConditionType`.
        
        - returns:  An optional order-sunstate tuple.
    */
    private func sunState() -> HomeKitConditionType? {
        guard let comparison = self as? NSComparisonPredicate else { return nil }
        guard comparison.leftExpression.expressionType == .keyPath else { return nil }
        guard comparison.rightExpression.expressionType == .function else { return nil }
        guard comparison.rightExpression.function == "now" else { return nil }
        guard comparison.rightExpression.arguments?.count == 0 else { return nil }
        
        switch (comparison.leftExpression.keyPath, comparison.predicateOperatorType) {
            case (HMSignificantEvent.sunrise.rawValue, .lessThan):
                return .sunTime(.after, .sunrise)
                
            case (HMSignificantEvent.sunrise.rawValue, .lessThanOrEqualTo):
                return .sunTime(.after, .sunrise)
                
            case (HMSignificantEvent.sunrise.rawValue, .greaterThan):
                return .sunTime(.before, .sunrise)
                
            case (HMSignificantEvent.sunrise.rawValue, .greaterThanOrEqualTo):
                return .sunTime(.before, .sunrise)
                
            case (HMSignificantEvent.sunset.rawValue, .lessThan):
                return .sunTime(.after, .sunset)
                
            case (HMSignificantEvent.sunset.rawValue, .lessThanOrEqualTo):
                return .sunTime(.after, .sunset)
                
            case (HMSignificantEvent.sunset.rawValue, .greaterThan):
                return .sunTime(.before, .sunset)
                
            case (HMSignificantEvent.sunset.rawValue, .greaterThanOrEqualTo):
                return .sunTime(.before, .sunset)
                
            default:
                return nil
        }
    }
    
    /**
        Parses the predicate and attempts to generate an order-exacttime `HomeKitConditionType`.
        
        - returns:  An optional order-exacttime tuple.
    */
    private func exactTime() -> HomeKitConditionType? {
        guard let comparison = self as? NSComparisonPredicate else { return nil }
        guard comparison.leftExpression.expressionType == .function else { return nil }
        guard comparison.leftExpression.function == "now" else { return nil }
        guard comparison.rightExpression.expressionType == .constantValue else { return nil }
        guard let dateComponents = comparison.rightExpression.constantValue as? DateComponents else { return nil }
        
        switch comparison.predicateOperatorType {
            case .lessThan, .lessThanOrEqualTo:
                return .exactTime(.before, dateComponents)
            
            case .greaterThan, .greaterThanOrEqualTo:
                return .exactTime(.after, dateComponents)
            
            case .equalTo:
                return .exactTime(.at, dateComponents)
            
            default:
                return nil
        }
    }
    
    /// - returns:  The 'type' of HomeKit condition, with associated value, if applicable.
    var homeKitConditionType: HomeKitConditionType {
        if let characteristic = characteristic() {
            return characteristic
        }
        else if let sunState = sunState() {
            return sunState
        }
        else if let exactTime = exactTime() {
            return exactTime
        }
        else {
            return .unknown
        }
    }
}
