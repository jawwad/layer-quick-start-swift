//
//  LayerAuthenticationHelper.swift
//  LayerQuickStart
//
//  Created by Jawwad Ahmad on 3/23/15.
//  Copyright (c) 2015 Layer. All rights reserved.
//

import Foundation

class LayerAuthenticationHelper {

    private let layerClient: LYRClient

    init(layerClient: LYRClient) {
        self.layerClient = layerClient
    }

    // MARK: - Public Interface

    func authenticateWithLayer(authenticationCompletion: AuthenticationCompletionBlock) {
        layerClient.connectWithCompletion { success, error in
            if let error = error {
                authenticationCompletion(error: error)
            } else {
                // Once connected, authenticate user.
                // Check Authenticate step for authenticateLayerWithUserID source
                self.authenticateLayerWithUserID(LQSCurrentUserID) { error in
                    if let error = error {
                        authenticationCompletion(error: error)
                        println("Failed Authenticating Layer Client with error: \(error.localizedDescription)")
                    } else if success {
                        authenticationCompletion(error: nil)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func authenticateLayerWithUserID(userID: String, authenticationCompletion: AuthenticationCompletionBlock) {
        // Check to see if the layerClient is already authenticated.
        if let authenticatedUserID = layerClient.authenticatedUserID {
            // If the layerClient is authenticated with the requested userID, complete the authentication process.
            if authenticatedUserID == userID {
                println("Layer Authenticated as User \(authenticatedUserID)")
                authenticationCompletion(error: nil)
            } else {
                // If the authenticated userID is different, then deauthenticate the current client and re-authenticate with the new userID.
                layerClient.deauthenticateWithCompletion { success, error in
                    if success {
                        self.authenticationTokenWithUserId(userID, authenticationCompletion)
                    } else if let error = error {
                        authenticationCompletion(error: error)
                    } else {
                        assertionFailure("Must have an error when success = false")
                    }
                }
            }
        } else {
            // If the layerClient isn't already authenticated, then authenticate.
            authenticationTokenWithUserId(userID, authenticationCompletion)
        }
    }

    private func authenticationTokenWithUserId(userID: String, authenticationCompletion: AuthenticationCompletionBlock) {
        // 1. Request an authentication Nonce from Layer
        layerClient.requestAuthenticationNonceWithCompletion { nonce, error in
            if nonce == nil {
                authenticationCompletion(error: error)
                return
            }

            // 2. Acquire identity Token from Layer Identity Service
            self.requestIdentityTokenForUserID(userID, appID: self.layerClient.appID.UUIDString, nonce: nonce) { identityToken, error in
                if identityToken == nil {
                    authenticationCompletion(error: error)
                    return
                }

                // 3. Submit identity token to Layer for validation
                self.layerClient.authenticateWithIdentityToken(identityToken) { authenticatedUserID, error in
                    if authenticatedUserID != nil {
                        println("Layer Authenticated as User: \(authenticatedUserID)")
                        authenticationCompletion(error: nil)
                    } else {
                        authenticationCompletion(error: error)
                    }
                }
            }
        }
    }

    private func requestIdentityTokenForUserID(userID: String, appID: String, nonce: String, tokenCompletion: IdentityTokenCompletionBlock) {
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
                tokenCompletion(nil, error)
                return
            }

            // Deserialize the response
            let responseObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) as NSDictionary
            if responseObject["error"] == nil {
                let identityToken = responseObject["identity_token"] as String
                tokenCompletion(identityToken, nil)
            } else {
                let domain = "layer-identity-provider.herokuapp.com"
                let code = responseObject["status"]!.integerValue
                let userInfo = [
                    NSLocalizedDescriptionKey: "Layer Identity Provider Returned an Error.",
                    NSLocalizedRecoverySuggestionErrorKey: "There may be a problem with your APPID."
                ]

                let error = NSError(domain: domain, code: code, userInfo: userInfo)
                tokenCompletion(nil, error)
            }
        }
        dataTask.resume()
    }

}
