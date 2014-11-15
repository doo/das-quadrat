//
//  Authorizer.swift
//  Quadrat
//
//  Created by Constantine Fry on 09/11/14.
//  Copyright (c) 2014 Constantine Fry. All rights reserved.
//

import Foundation

protocol AuthorizationDelegate {
    func userDidCancel()
    func didReachRedirectURL(redirectURL: NSURL)
}

class Authorizer: AuthorizationDelegate {
    var redirectURL : NSURL
    var authorizationURL : NSURL
    var completionHandler: ((String?, NSError?) -> Void)?
    let keychain : Keychain
    
    convenience init(configuration: Configuration) {
        let baseURL = configuration.server.oauthBaseURL
        let parameters = [
            Parameter.client_id        : configuration.client.id,
            Parameter.redirect_uri     : configuration.client.redirectURL,
            Parameter.v                : configuration.version,
            Parameter.response_type    : "token"
        ]
        
        let URLString = baseURL + "?" + Parameter.makeQuery(parameters)
        let authorizationURL = NSURL(string: URLString)
        let redirectURL = NSURL(string: configuration.client.redirectURL)
        if authorizationURL == nil || redirectURL == nil {
            fatalError("Can't build auhorization URL. Check your clientId and redirectURL")
        }
        let keychain = Keychain(configuration: configuration)
        self.init(authorizationURL: authorizationURL!, redirectURL: redirectURL!, keychain: keychain)
        self.cleanupCookiesForURL(authorizationURL!)
    }
    
    init(authorizationURL: NSURL, redirectURL: NSURL, keychain:Keychain) {
        self.authorizationURL = authorizationURL
        self.redirectURL = redirectURL
        self.keychain = keychain
    }
    
    // MARK: - Delegate methods
    
    func userDidCancel() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.finilizeAuthorization(nil, error: error)
    }
    
    func didReachRedirectURL(redirectURL: NSURL) {
        println("redirectURL" + redirectURL.absoluteString!)
        let parameters = self.extractParametersFromURL(redirectURL)
        self.finilizeAuthorizationWithParameters(parameters)
    }
    
    // MARK: - Finilization
    
    func finilizeAuthorizationWithParameters(parameters: Parameters) {
        var error: NSError?
        if let errorString = parameters["error"] {
            error = NSError.quadratOauthErrorForString(errorString)
        }
        self.finilizeAuthorization(parameters["access_token"], error: error)
    }
    
    func finilizeAuthorization(accessToken: String?, error: NSError?) {
        if accessToken != nil {
            self.keychain.saveAccessToken(accessToken!)
            println("access token: " + accessToken!)
        } else {
            println("acces token error: ", error)
        }
        self.completionHandler?(accessToken, error)
        self.completionHandler = nil
    }
    
    // MARK: - Helpers
    
    func cleanupCookiesForURL(URL: NSURL) {
        let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        if storage.cookies != nil {
            let cookies = storage.cookies as [NSHTTPCookie]
            for cookie in cookies {
                if cookie.domain == URL.host {
                    storage.deleteCookie(cookie as NSHTTPCookie)
                }
            }
        }
    }
    
    func extractParametersFromURL(fromURL: NSURL) -> Parameters {
        var queryString: String?
        if fromURL.absoluteString!.hasPrefix((self.redirectURL.absoluteString! + "#")) {
            // If we are here it's was web authorization and we have redirect URL like this:
            // testapp123://foursquare#access_token=ACCESS_TOKEN
            queryString = (fromURL.absoluteString!.componentsSeparatedByString("#"))[1]
        } else {
            // If we are here it's was native iOS authorization and we have redirect URL like this:
            // testapp123://foursquare?access_token=ACCESS_TOKEN
            queryString = fromURL.query
        }
        var parameters = queryString?.componentsSeparatedByString("&")
        var map = Parameters()
        if parameters != nil {
            for string: String in parameters! {
                let keyValue = string.componentsSeparatedByString("=")
                if keyValue.count == 2 {
                    map[keyValue[0]] = keyValue[1]
                }
            }
        }
        return map
    }
    
    func errorForErrorString(errorString: String) -> NSError? {
        return nil
    }
}
