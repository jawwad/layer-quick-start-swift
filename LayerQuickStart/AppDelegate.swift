//
//  AppDelegate.swift
//  LayerQuickStart
//
//  Created by Jawwad Ahmad on 3/20/15.
//  Copyright (c) 2015 Layer. All rights reserved.
//

import UIKit

let LQSLayerAppIDString = "LAYER_APP_ID"

#if arch(i386) || arch(x86_64) // simulator
    let LQSCurrentUserID = "Simulator"
    let LQSParticipantUserID = "Device"
    let LQSInitialMessageText = "Hey Device! This is your friend, Simulator."
#else // device
    let LQSCurrentUserID = "Device"
    let LQSParticipantUserID = "Simulator"
    let LQSInitialMessageText = "Hey Simulator! This is your friend, Device."
#endif

let LQSParticipant2UserID = "Dashboard"

typealias CompletionBlock = ((Bool, NSError!) -> Void)!

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
            layerClient.connectWithCompletion { success, error in
                if !success {
                    println("Failed to connect to Layer: \(error!.localizedDescription)")
                } else {
                    // For the purposes of this Quick Start project, let's authenticate as a user named 'Device'.  Alternatively, you can authenticate as a user named 'Simulator' if you're running on a Simulator.
                    let userIDString = LQSCurrentUserID

                    // Once connected, authenticate user.
                    // Check Authenticate step for authenticateLayerWithUserID source
                    self.authenticateLayerWithUserID(userIDString) { success, error in
                        if !success {
                            println("Failed Authenticating Layer Client with error: \(error!.localizedDescription)")
                        }
                    }
                }
            }

            // Register for push
            registerApplicationForPushNotifications(application)

            let navigationController = window?.rootViewController as UINavigationController
            (navigationController.topViewController as ChatViewController).layerClient = layerClient
        }

        return true
    }

    func authenticateLayerWithUserID(userID: String, completion: CompletionBlock) {

        // Check to see if the layerClient is already authenticated.
        if let authenticatedUserID = layerClient.authenticatedUserID {
            // If the layerClient is authenticated with the requested userID, complete the authentication process.
            if authenticatedUserID == userID {
                println("Layer Authenticated as User \(authenticatedUserID)")
                if completion != nil {
                    completion(true, nil)
                }
                return
            } else {
                // If the authenticated userID is different, then deauthenticate the current client and re-authenticate with the new userID.
                layerClient.deauthenticateWithCompletion { success, error in
                    if error == nil {
                        self.authenticationTokenWithUserId(userID) { success, error in
                            if completion != nil {
                                completion(success, error)
                            }
                        }
                    } else {
                        if completion != nil {
                            completion(false, error)
                        }
                    }
                }
            }
        } else {
            // If the layerClient isn't already authenticated, then authenticate.
            authenticationTokenWithUserId(userID) { success, error in
                if completion != nil {
                    completion(success, error)
                }
            }
        }
    }

    func authenticationTokenWithUserId(userID: String, completion: CompletionBlock) {

        // 1. Request an authentication Nonce from Layer
        layerClient.requestAuthenticationNonceWithCompletion { nonce, error in
            if nonce == nil {
                if completion != nil {
                    completion(false, error)
                }
                return
            }

            // 2. Acquire identity Token from Layer Identity Service
            self.requestIdentityTokenForUserID(userID, appID: self.layerClient.appID.UUIDString, nonce: nonce) { identityToken, error in
                if identityToken == nil {
                    if completion != nil {
                        completion(false, error)
                    }
                    return
                }

                // 3. Submit identity token to Layer for validation
                self.layerClient.authenticateWithIdentityToken(identityToken) { authenticatedUserID, error in
                    if authenticatedUserID != nil {
                        if completion != nil {
                            completion(true, nil)
                        }
                        println("Layer Authenticated as User: \(authenticatedUserID)")
                    } else {
                        completion(false, error)
                    }
                }
            }
        }
    }

    func requestIdentityTokenForUserID(userID: String, appID: String, nonce: String, completion: (String!, NSError!) -> Void) {
        let identityTokenURL = NSURL(string: "https://layer-identity-provider.herokuapp.com/identity_tokens")!
        let request = NSMutableURLRequest(URL: identityTokenURL)
        request.HTTPMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let parameters = ["app_id": appID, "user_id": userID, "nonce": nonce]
        let requestBody = NSJSONSerialization.dataWithJSONObject(parameters, options: nil, error: nil)
        request.HTTPBody = requestBody

        let sessionConfiguration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfiguration)

        let dataTask = session.dataTaskWithRequest(request) { data, response, error in
            if error != nil {
                completion(nil, error)
                return
            }

            // Deserialize the response
            let responseObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) as NSDictionary
            if responseObject["error"] == nil {
                let identityToken = responseObject["identity_token"] as String
                completion(identityToken, nil)
            } else {
                let domain = "layer-identity-provider.herokuapp.com"
                let code = responseObject["status"]!.integerValue
                let userInfo = [
                    NSLocalizedDescriptionKey: "Layer Identity Provider Returned an Error.",
                    NSLocalizedRecoverySuggestionErrorKey: "There may be a problem with your APPID."
                ]

                let error = NSError(domain: domain, code: code, userInfo: userInfo)
                completion(nil, error)
            }
        }
        dataTask.resume()
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
            application.registerForRemoteNotificationTypes(.Alert | .Sound | .Badge)
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
        } else {
            println("Failed updating device token with error: \(error!.localizedDescription)")
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
        if error == nil {
            println("Query contains \(messages.count) messages")
            let message = messages.firstObject as LYRMessage
            let messagePart = message.parts[0] as LYRMessagePart

            println("Pushed Message Contents: \(NSString(data: messagePart.data, encoding: NSUTF8StringEncoding))")
        } else {
            println("Query failed with error \(error?.localizedDescription)")
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
            NSUserDefaults.standardUserDefaults().synchronize()

            // This is the first launch ever

            let alert = UIAlertView(
                title: "Hello!",
                message: "This is a very simple example of a chat app using Layer. Launch this app on a Simulator and a Device to start a 1:1 conversation. If you shake the Device the navbar color will change on both the Simulator and Device.",
                delegate: nil,
                cancelButtonTitle: nil)

            alert.addButtonWithTitle("Got It!")
            alert.show()
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

