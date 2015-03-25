//
//  AppDelegate.swift
//  LayerQuickStart
//
//  Created by Jawwad Ahmad on 3/20/15.
//  Copyright (c) 2015 Layer. All rights reserved.
//

import UIKit

private let LQSLayerAppIDString = "LAYER_APP_ID"

#if arch(i386) || arch(x86_64) // simulator
    let LQSCurrentUserID     = "Simulator"
    let LQSParticipantUserID = "Device"
#else // device
    let LQSCurrentUserID     = "Device"
    let LQSParticipantUserID = "Simulator"
#endif

let LQSInitialMessageText = "Hey \(LQSParticipantUserID)! This is your friend, \(LQSCurrentUserID)."
let LQSParticipant2UserID = "Dashboard"

typealias AuthenticationCompletionBlock = (error: NSError?) -> Void
typealias IdentityTokenCompletionBlock  = (String?, NSError?) -> Void

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, LYRClientDelegate, UIAlertViewDelegate {

    var window: UIWindow?

    var layerClient: LYRClient!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Check if Sample App is using a valid app ID.
        if isValidAppID() {

            // Show a usage the first time the app is launched
            showFirstTimeMessage()

            // Initializes a LYRClient object
            let appID = NSUUID(UUIDString: LQSLayerAppIDString)
            layerClient = LYRClient(appID: appID)
            layerClient.delegate = self

            // Connect to Layer
            // See "Quick Start - Connect" for more details
            // https://developer.layer.com/docs/quick-start/ios#connect

            LayerAuthenticationHelper(layerClient: layerClient).authenticateWithLayer { error in
                if let error = error {
                    println("Failed to connect to Layer: \(error.localizedDescription)")
                } else {
                    let navigationController = self.window?.rootViewController as UINavigationController
                    (navigationController.topViewController as ChatViewController).layerClient = self.layerClient

                    // Register for push
                    self.registerApplicationForPushNotifications(application)
                }
            }
        }

        return true
    }

    // MARK: - Push Notification Methods

    func registerApplicationForPushNotifications(application: UIApplication) {
        // Set up push notifications
        // For more information about Push, check out:
        // https://developer.layer.com/docs/guides/ios#push-notification

        // Checking if app is running iOS 8
        if application.respondsToSelector("registerForRemoteNotifications") {
            // Register device for iOS8
            let notificationSettings = UIUserNotificationSettings(forTypes: .Alert | .Badge | .Sound, categories: nil)
            application.registerUserNotificationSettings(notificationSettings)
            application.registerForRemoteNotifications()
        } else {
            // Register device for iOS7
            application.registerForRemoteNotificationTypes(.Alert | .Badge | .Sound)
        }
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Send device token to Layer so Layer can send pushes to this device.
        // For more information about Push, check out:
        // https://developer.layer.com/docs/guides/ios#push-notification

        var error: NSError?
        let success = layerClient.updateRemoteNotificationDeviceToken(deviceToken, error: &error)
        if success {
            println("Application did register for remote notifications: \(deviceToken)")
        } else if let error = error {
            println("Failed updating device token with error: \(error.localizedDescription)")
        }
    }


    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        // Get Message from Metadata
        var message = messageFromRemoteNotification(userInfo)

        var error: NSError?

        let success = layerClient.synchronizeWithRemoteNotification(userInfo) { changes, error in
            if changes != nil {
                if changes.count > 0 {
                    message = self.messageFromRemoteNotification(userInfo)
                    completionHandler(.NewData)
                } else {
                    completionHandler(.NoData)
                }
            } else {
                completionHandler(.Failed)
            }
        }

        if success {
            println("Application did complete remote notification sync")
        } else {
            println("Failed processing push notification with error: \(error!.localizedDescription)")
            completionHandler(.NoData)
        }
    }

    func messageFromRemoteNotification(remoteNotification: NSDictionary) -> LYRMessage {
        let LQSPushMessageIdentifierKeyPath = "layer.message_identifier"

        // Retrieve message URL from Push Notification
        let messageURL = NSURL(string: remoteNotification[LQSPushMessageIdentifierKeyPath] as String)!

        // Retrieve LYRMessage from Message URL
        let query = LYRQuery(`class`: LYRMessage.self)
        query.predicate = LYRPredicate(property: "identifier", `operator`: .IsIn, value: NSSet(object: messageURL))

        var error: NSError?
        let messages = layerClient.executeQuery(query, error: &error)
        if let error = error {
            println("Query failed with error \(error.localizedDescription)")
        } else {
            println("Query contains \(messages.count) messages")
            let message = messages.firstObject as LYRMessage
            let messagePart = message.parts[0] as LYRMessagePart

            println("Pushed Message Contents: \(NSString(data: messagePart.data, encoding: NSUTF8StringEncoding))")
        }

        return messages.firstObject as LYRMessage
    }


    // MARK: - LYRClientDelegate

    func layerClient(client: LYRClient!, didReceiveAuthenticationChallengeWithNonce nonce: String!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didAuthenticateAsUserID userID: String!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didFailOperationWithError error: NSError!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didFailSynchronizationWithError error: NSError!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didFinishContentTransfer contentTransferType: LYRContentTransferType, ofObject object: AnyObject!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didFinishSynchronizationWithChanges changes: [AnyObject]!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, didLoseConnectionWithError error: NSError!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, objectsDidChange changes: [AnyObject]!) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, willAttemptToConnect attemptNumber: UInt, afterDelay delayInterval: NSTimeInterval, maximumNumberOfAttempts attemptLimit: UInt) {
        println(__FUNCTION__)
    }

    func layerClient(client: LYRClient!, willBeginContentTransfer contentTransferType: LYRContentTransferType, ofObject object: AnyObject!, withProgress progress: LYRProgress!) {
        println(__FUNCTION__)
    }

    func layerClientDidConnect(client: LYRClient!) {
        println(__FUNCTION__)
    }

    func layerClientDidDeauthenticate(client: LYRClient!) {
        println(__FUNCTION__)
    }

    func layerClientDidDisconnect(client: LYRClient!) {
        println(__FUNCTION__)
    }


    // MARK: - First Run Notification

    func showFirstTimeMessage() {
        let LQSApplicationHasLaunchedOnceDefaultsKey = "applicationHasLaunchedOnce"

        if !NSUserDefaults.standardUserDefaults().boolForKey(LQSApplicationHasLaunchedOnceDefaultsKey) {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: LQSApplicationHasLaunchedOnceDefaultsKey)

            // This is the first launch ever

            UIAlertView(
                title: "Hello!",
                message: "This is a very simple example of a chat app using Layer. Launch this app on a Simulator and a Device to start a 1:1 conversation. If you shake the Device the navbar color will change on both the Simulator and Device.",
                delegate: nil,
                cancelButtonTitle: "Got It!").show()
        }
    }

    // MARK: - Check if Sample App is using a valid app ID.

    func isValidAppID() -> Bool {
        if LQSLayerAppIDString == "LAYER_APP_ID" {
            let alert = UIAlertView(
                title: "\u{1F625}", //"😥"
                message: "To correctly use this project you need to replace LAYER_APP_ID in AppDelegate.m (line 11) with your App ID from developer.layer.com.",
                delegate: self,
                cancelButtonTitle: nil)
            
            alert.addButtonWithTitle("OK")
            alert.show()
            return false
        }
        return true
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if alertView.buttonTitleAtIndex(buttonIndex) == "OK" {
            abort()
        }
    }
}

