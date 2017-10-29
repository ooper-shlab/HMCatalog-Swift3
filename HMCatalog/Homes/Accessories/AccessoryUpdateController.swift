/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `AccessoryUpdateController` manages `CharacteristicCell` updates and buffers them up before sending them to HomeKit.
*/

import HomeKit

/// An object that responds to `CharacteristicCell` updates and notifies HomeKit of changes.
class AccessoryUpdateController: NSObject, CharacteristicCellDelegate {

    // MARK: Properties
    
    let updateQueue = DispatchQueue(label: "com.sample.HMCatalog.CharacteristicUpdateQueue", attributes: [])
    
    lazy var pendingWrites = [HMCharacteristic:CellValueType]()
    lazy var sentWrites = [HMCharacteristic:CellValueType]()
    
    // Implicitly unwrapped optional because we need `self` to initialize.
    var updateValueTimer: Timer!
    
    /// Starts the update timer on creation.
    override init() {
        super.init()
        startListeningForCellUpdates()
    }
    
    /// Responds to a cell change, and if the update was marked immediate, updates the characteristics.
    func characteristicCell(_ cell: CharacteristicCell, didUpdateValue value: CellValueType, forCharacteristic characteristic: HMCharacteristic, immediate: Bool) {
        pendingWrites[characteristic] = value
        if immediate {
            updateCharacteristics()
        }
    }
    
    /**
        Reads the characteristic's value and calls the completion with the characteristic's value.
    
        If there is a pending write request on the same characteristic, the read is ignored to prevent
        "UI glitching".
    */
    func characteristicCell(_ cell: CharacteristicCell, readInitialValueForCharacteristic characteristic: HMCharacteristic, completion: @escaping (CellValueType?, Error?) -> Void) {
        characteristic.readValue { error in
            self.updateQueue.sync {
                if let sentValue = self.sentWrites[characteristic] {
                    completion(sentValue, nil)
                    return
                }

                DispatchQueue.main.async {
                    completion(characteristic.value as? CellValueType, error)
                }
            }
        }
    }

    /// Creates and starts the update value timer.
    func startListeningForCellUpdates() {
        updateValueTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateCharacteristics), userInfo: nil, repeats: true)
    }
    
    /// Invalidates the update timer.
    func stopListeningForCellUpdates() {
        updateValueTimer.invalidate()
    }
    
    /// Sends all pending requests in the array.
    @objc func updateCharacteristics() {
        updateQueue.sync {
            for (characteristic, value) in self.pendingWrites {
                self.sentWrites[characteristic] = value

                characteristic.writeValue(value) { error in
                    if let error = error {
                        print("HomeKit: Could not change value: \(error.localizedDescription).")
                    }

                    self.didCompleteWrite(characteristic, value: value)
                }
            }

            self.pendingWrites.removeAll()
        }
    }
    
    /**
        Synchronously adds the characteristic-value pair into the `sentWrites` map.
        
        - parameter characteristic: The `HMCharacteristic` to add.
        - parameter value: The value of the `characteristic`.
    */
    func didSendWrite(_ characteristic: HMCharacteristic, value: CellValueType) {
        updateQueue.sync {
            self.sentWrites[characteristic] = value
        }
    }
    
    /**
        Synchronously removes the characteristic-value pair from the `sentWrites` map.
        
        - parameter characteristic: The `HMCharacteristic` to remove.
        - parameter value: The value of the `characteristic` (unused, but included for clarity).
    */
    func didCompleteWrite(_ characteristic: HMCharacteristic, value: AnyObject) {
        updateQueue.sync {
            _ = self.sentWrites.removeValue(forKey: characteristic)
        }
    }
}
