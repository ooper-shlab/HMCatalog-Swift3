/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `UIViewController+Convenience` methods allow for easy presentation of common views.
*/

import HomeKit
import UIKit

extension UIViewController {
    
    /**
     Displays a `UIAlertController` on the main thread with the error's `localizedDescription` at the body.
     
     - parameter error: The error to display.
     */
    func displayError(_ error: Error) {
        if error is CocoaError {
            let errorCode = HMError(_nsError: error as NSError).code
            if self.presentedViewController != nil || errorCode == .operationCancelled || errorCode == .userDeclinedAddingUser {
                print(error.localizedDescription)
            }
            else {
                self.displayErrorMessage(error.localizedDescription)
            }
        }
        else {
            self.displayErrorMessage(String(describing: error))
        }
    }
    
    /**
     Displays a collection of errors, separated by newlines.
     
     - parameter errors: An array of `NSError`s to display.
     */
    func displayErrors(_ errors: [Error]) {
        var messages = [String]()
        for error in errors {
            let errorCode = HMError(_nsError: error as NSError).code
            if self.presentedViewController != nil || errorCode == .operationCancelled || errorCode == .userDeclinedAddingUser {
                print(error.localizedDescription)
            }
            else {
                messages.append(error.localizedDescription)
            }
        }
        
        if messages.count > 0 {
            // There were errors in the list, reduce the messages into a single one.
            let collectedMessage = messages.reduce("", { (accumulator, message) -> String in
                return accumulator + "\n" + message
            })
            self.displayErrorMessage(collectedMessage)
        }
    }
    
    /// Displays a `UIAlertController` with the passed-in text and an 'Okay' button.
    func displayMessage(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, body: message)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    /**
     Displays `UIAlertController` with a message and a localized "Error" title.
     
     - parameter message: The message to display.
     */
    private func displayErrorMessage(_ message: String) {
        let errorTitle = NSLocalizedString("Error", comment: "Error")
        displayMessage(errorTitle, message: message)
    }
    
    /**
     Presents a simple `UIAlertController` with a textField, set up to
     accept a name. Once the name is entered, the completion handler will
     be called and the name will be passed in.
     
     - parameter attributeType: The kind of object being added
     - parameter completion:    The block to run when the user taps the add button.
     */
    func presentAddAlertWithAttributeType(_ type: String, placeholder: String? = nil, shortType: String? = nil, completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(attributeType: type, completionHandler: completion, placeholder: placeholder, shortType: shortType)
        self.present(alertController, animated: true, completion: nil)
    }
    
}
