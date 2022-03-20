//
//  QwikHttp.swift
//  oAuthExample
//
//  Created by Logan Sease on 1/26/16.
//  Copyright © 2016 Logan Sease. All rights reserved.
//

import Foundation
import QwikJson

public typealias QBooleanCompletionHandler = (_ success: Bool) -> Void

/****** REQUEST TYPES *******/
@objc public enum HttpRequestMethod : Int {
    case get = 0, post, put, delete, patch, head
    
    public var description: String
    {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .delete:
            return "DELETE"
        case .patch:
            return "PATCH"
        case .head:
            return "HEAD"
        }
    }
}

//parameter types
@objc public enum ParameterType : Int
{
    case json = 0, formEncoded
}

//parameter types
@objc public enum QwikHttpLoggingLevel : Int
{
    case none = 0, errors, requests, debug
}

//indicates if the response should be called on the background or main thread
@objc public enum ResponseThread : Int
{
    case main = 0, background
}

//a delegate used to configure and show a custom loading indicator.
@objc public protocol QwikHttpLoadingIndicatorDelegate
{
    @objc func showIndicator(_ title: String!)
    @objc func hideIndicator()
}


//This interceptor protocol is in place so that we can register an interceptor to our class to intercept certain
//responses. This could be useful to check for expired tokens and then retry the request instead of calling the
//handler with the error. This could also allow you to show the login screen when an unautorized response is returned
//using this class will help avoid the need to do this constantly on each api call.
@objc public protocol QwikHttpResponseInterceptor
{
    @objc optional func didSend(_ request: QwikHttp!)
    func shouldInterceptResponse(_ response: URLResponse!) -> Bool
    func interceptResponse(_ request : QwikHttp!, handler: @escaping (Data?, URLResponse?, NSError?) -> Void)
}

//the request interceptor can be used to intercept requests before they are sent out.
@objc public protocol QwikHttpRequestInterceptor
{
    func shouldInterceptRequest(_ request: QwikHttp!) -> Bool
    func interceptRequest(_ request : QwikHttp!,  handler: @escaping (Data?, URLResponse?, NSError?) -> Void)
}


//a class to store default values and configuration for quikHttp
@objc public class QwikHttpConfig : NSObject
{
    fileprivate static var defaultTimeOut = 40 as Double
    @objc public static var defaultCachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
    @objc public static var defaultParameterType = ParameterType.json
    @objc public static var defaultLoadingTitle : String? = nil
    @objc public static var loadingIndicatorDelegate: QwikHttpLoadingIndicatorDelegate? = nil
    
    @objc public static var responseInterceptor: QwikHttpResponseInterceptor? = nil
    @objc public static var requestInterceptor: QwikHttpRequestInterceptor? = nil
    @objc public static var standardHeaders : [String : String]! = [:]
    @objc public static var loggingLevel : QwikHttpLoggingLevel = .errors
    
    @objc public static var defaultResponseThread : ResponseThread = .main
    @objc public static var urlSession : URLSession = URLSession.shared
    @objc public static var filterLogs : Bool = false
    @objc public static var filterWords : [String] = ["password", "Authorization", "secret", "token"]
    
    //ensure timeout > 0
    @objc public class func setDefaultTimeOut(_ timeout: Double)
    {
        if(timeout > 0)
        {
            defaultTimeOut = timeout
        }
        else
        {
            defaultTimeOut = 40
        }
    }
}

//the main request object
@objc open class QwikHttp : NSObject {
    
    /***** REQUEST VARIABLES ******/
    @objc public var urlString : String!
    @objc public var httpMethod : HttpRequestMethod
    fileprivate var headers : [String : String]!
    fileprivate var params : [String : AnyObject]!
    fileprivate var body: Data?
    fileprivate var parameterType : ParameterType!
    fileprivate var responseThread : ResponseThread!
    fileprivate var avoidResponseInterceptor = false
    fileprivate var avoidRequestInterceptor = false
    fileprivate var avoidStandardHeaders : Bool = false
    fileprivate var requestSender: QwikHttpRequestSender = UrlSessionRequestSender.defaultSender
    
    //response variables
    @objc public var responseError : NSError?
    @objc public var responseData : Data?
    @objc public var response: URLResponse?
    @objc public var responseString : NSString?
    @objc public var wasIntercepted = false
    @objc public var responseStatusCode : Int = 0
    @objc public var loggingLevel : QwikHttpLoggingLevel = QwikHttpConfig.loggingLevel
    
    //class params
    fileprivate var timeOut : Double!
    fileprivate var cachePolicy: URLRequest.CachePolicy!
    fileprivate var loadingTitle: String?
    
    /**** REQUIRED INITIALIZER*****/
    @objc public convenience init(url: String!, httpMethod: HttpRequestMethod)
    {
        self.init(url,httpMethod: httpMethod)
    }
    
    @objc public init(_ url: String!, httpMethod: HttpRequestMethod)
    {
        self.urlString = url
        self.httpMethod = httpMethod
        self.headers = [:]
        self.params = [:]
        
        //set defaults
        self.parameterType = QwikHttpConfig.defaultParameterType
        self.cachePolicy = QwikHttpConfig.defaultCachePolicy
        self.timeOut = QwikHttpConfig.defaultTimeOut
        self.loadingTitle = QwikHttpConfig.defaultLoadingTitle
        self.responseThread = QwikHttpConfig.defaultResponseThread
    }
}

// MARK: Request Configuration
// ALL RETURN SELF TO ENCOURAGE SINGLE LINE BUILDER STYLE SYNTAX
extension QwikHttp
{
    //add a parameter to the request
    @objc public func addParam(_ key : String!, value: String?) -> QwikHttp
    {
        if let v = value
        {
            params[key] = v as AnyObject?
        }
        
        return self
    }
    
    //add a header
    @objc public func addHeader(_ key : String!, value: String?) -> QwikHttp
    {
        if let v = value
        {
            headers[key] = v
        }
        return self
    }
    
    //set a title to the loading indicator. Set to nil for no indicator
    @objc public func setLoadingTitle(_ title: String?) -> QwikHttp
    {
        self.loadingTitle = title
        return self
    }
    
    //add a single optional URL parameter
    @objc public func addUrlParam(_ key: String!, value: String?) -> QwikHttp
    {
        guard let param = value else
        {
            return self
        }
        
        //start our URL Parameters
        if let _ = urlString.range(of: "?")
        {
            urlString = urlString + "&"
        }
        else
        {
            urlString = urlString + "?"
        }
        
        urlString = urlString + QwikHttp.paramStringFrom([key : param])
        return self
    }
    
    
    //add an array of URL parameters
    @objc public func addUrlParams(_ params: [String: String]!) -> QwikHttp
    {
        //start our URL Parameters
        if let _ = urlString.range(of: "?")
        {
            urlString = urlString + "&"
        }
        else
        {
            urlString = urlString + "?"
        }
        urlString = urlString + QwikHttp.paramStringFrom(params)
        return self
    }
    
    @objc public func removeUrlParam(_ key: String!)
    {
        //get our query items from the url
        if #available(OSX 10.10, *)
        {
            if var urlComponents = URLComponents(string: urlString), let items = urlComponents.queryItems
            {
                //get a new array of query items by removing any with the key we want
                let newItems = items.filter { $0.name == key }
                
                //reconstruct our url if we removed anything
                if(newItems.count != items.count)
                {
                    urlComponents.queryItems = newItems
                    urlString = urlComponents.string
                }
            }
        }
    }

    
    //set a quikJson into the request. Will serialize to json and set the content type.
    public func setLoggingLevel(_ level: QwikHttpLoggingLevel)  -> QwikHttp
    {
        self.loggingLevel = level
        return self
    }
    
    //set a quikJson into the request. Will serialize to json and set the content type.
    @objc public func setObject(_ object: QwikJson?)  -> QwikHttp
    {
        if let qwikJson = object,  let params = qwikJson.toDictionary() as? [String : AnyObject]
        {
            _ = self.addParams(params)
            _ = self.setParameterType(.json)
        }
        return self
    }
    
    //set an array of objects to the request body serialized as json objects.
    public func setObjects<Q : QwikJson>(_ objects: [Q]?, toModelClass modelClass: Q.Type)  -> QwikHttp
    {
        if let array = objects, let params = QwikJson.jsonArray(from: array, of: modelClass )
        {
            do{
                let data = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                _ = self.setBody(data)
                _ = self.addHeader("Content-Type", value: "application/json")
            }
            catch _ as NSError {}
        }
        return self
    }
    
    //add an list of parameters
    @objc public func addParams(_ params: [String: AnyObject]!) -> QwikHttp
    {
        self.params = combinedDictionary(self.params, with: params)
        return self
    }
    
    //add a list of headers
    @objc public func addHeaders(_ headers: [String: String]!) -> QwikHttp
    {
        self.headers = combinedDictionary(self.headers as [String : AnyObject]?, with: headers as [String : AnyObject]?) as? [String : String]
        return self
    }
    
    //set the body directly
    @objc public func setBody(_ body : Data!) -> QwikHttp
    {
        self.body = body
        return self;
    }
    
    //get the body as a string for debugging purposes, very useful for displaying the json after the request is sent
    @objc public func getBody(filterLogs : Bool = QwikHttpConfig.filterLogs) -> String?
    {
        guard let data = self.body else
        {
            return nil
        }
        
        var result = String(data: data, encoding: .utf8)
        
        if filterLogs && QwikHttpConfig.filterWords.count > 0
        {
            result = result?.filtered(sensitiveWords: QwikHttpConfig.filterWords)
        }
        
        return result
    }
    
    //set the parameter type
    @objc public func setParameterType(_ parameterType : ParameterType) -> QwikHttp
    {
        self.parameterType = parameterType
        return self;
    }
    
    //set the cache policy
    @objc public func setCachePolicy(_ policy: URLRequest.CachePolicy) -> QwikHttp
    {
        cachePolicy = policy
        return self
    }
    
    //do not add standard headers if this is set to true
    @objc public func setAvoidStandardHeaders(_ avoid: Bool) -> QwikHttp
    {
        self.avoidStandardHeaders = avoid
        return self
    }
    
    //set the request time out
    @objc public func setTimeOut(_ timeOut: Double) -> QwikHttp
    {
        self.timeOut = timeOut
        return self
    }
    @objc public func setResponseThread(_ responseThread: ResponseThread) -> QwikHttp
    {
        self.responseThread = responseThread
        return self
    }
    
    //a helper method to duck the response interceptor. Can be useful for cases like logout which
    //could lead to infinite recursion
    @objc public func setAvoidResponseInterceptor(_ avoid : Bool)  -> QwikHttp!
    {
        self.avoidResponseInterceptor = true
        return self
    }
    
    //a helper method to duck the request interceptor. Can be useful for cases like token refresh which
    //could lead to infinite recursion
    @objc public func setAvoidRequestInterceptor(_ avoid : Bool)  -> QwikHttp!
    {
        self.avoidRequestInterceptor = true
        return self
    }
    
    @objc public func setRequestSender(_ sender: QwikHttpRequestSender) -> QwikHttp
    {
        self.requestSender = sender
        return self
    }
}

// MARK: Request Creation
extension QwikHttp
{
    enum RequestConfigError: Error
    {
        case badUrl
    }
    
    @objc public func getConfiguredRequest() throws -> URLRequest
    {
        let requestParams = self
        
        guard let url = URL(string: requestParams.urlString) else {
            throw RequestConfigError.badUrl
        }
        
        //create our http request
        var request = URLRequest(url: url, cachePolicy: requestParams.cachePolicy, timeoutInterval: requestParams.timeOut)
        
        //add all of our standard headers if they are not yet added and the avoid flag is not set
        if requestParams.avoidStandardHeaders == false
        {
            for(key, value) in QwikHttpConfig.standardHeaders
            {
                if !requestParams.headers.keys.contains(key)
                {
                    _ = requestParams.addHeader(key, value: value)
                }
            }
        }
        
        //set up our http method and add headers
        request.httpMethod = requestParams.httpMethod.description
        for(key, value) in requestParams.headers
        {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        //set up our parameters
        if requestParams.parameterType == .formEncoded  && requestParams.params.count > 0
        {
            //convert parameters to form encoded values and set to body
            if let params = requestParams.params as? [String : String]
            {
                request.httpBody = QwikHttp.paramStringFrom(params).data(using: String.Encoding.utf8)
                
                //set our body so we can view it later for debug purposes
                _ = requestParams.setBody(request.httpBody)
                
                //set the request type headers
                //application/x-www-form-urlencoded
                _ = requestParams.addHeader("Content-Type", value: "application/x-www-form-urlencoded")
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
                
                //if we couldn't encode the values, then perhaps json was passed in unexpectedly, so try to parse it as json.
            else
            {
                _ = requestParams.setParameterType(.json)
            }
        }
            
            //try json parsing, note that formEncoding could have changed the type if there was an error, so don't use an else if
        else if requestParams.parameterType == .json && requestParams.params.count > 0
        {
            //convert parameters to json string and form and set to body
            do {
                let data = try JSONSerialization.data(withJSONObject: requestParams.params as Any, options: JSONSerialization.WritingOptions.prettyPrinted)
                request.httpBody = data
                
                //set our body so we can view it later for debug purposes
                _ = requestParams.setBody(request.httpBody)
            }
            catch {
                throw error
            }
            
            //set the request type headers
            _ = requestParams.addHeader("Content-Type", value: "application/json")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
            
            //set our body from data
        else if let body = requestParams.body
        {
            request.httpBody = body
        }
        
        return request
    }
}

// MARK: Response Handlers / Send methods
extension QwikHttp
{
    //get an an object of a generic type back
    public func getResponse<T : QwikDataConversion>(_ type: T.Type, _ handler :  @escaping (T?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            //check for an error
            if let e = error
            {
                self.determineThread({ () -> () in
                    handler(nil,e, self)
                })
            }
            else
            {
                //try to deserialize our object
                if let t : T = T.fromData(data)
                {
                    self.determineThread({ () -> () in
                        handler(t,nil,self)
                    })
                }
                    
                    //error if we could deserialize
                else
                {
                    self.determineThread({ () -> () in
                        
                        if self.loggingLevel.rawValue >= QwikHttpLoggingLevel.errors.rawValue
                        {
                            self.printDebugInfo()
                        }
                        
                        handler(nil,NSError(domain: "QwikHttp", code: 500, userInfo: ["Error" : "Could not parse response"]), self)
                    })
                }
            }
        }
    }
    
    @available(iOS 13.0.0, *)
    public func getResponse<T : QwikDataConversion>(_ type: T.Type) async -> Result<T, Error> {
        return await withCheckedContinuation({ continuation in
            self.getResponse(type) { result, error, request in
                if let result = result {
                    continuation.resume(returning: .success(result))
                }
                else if let error = error {
                    continuation.resume(returning: .failure(error))
                }
            }
        })
    }
    
    //get an array of a generic type back
    public func getArrayResponse<T : QwikDataConversion>(_ type: T.Type, _ handler :  @escaping ([T]?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            //check for error
            if let e = error
            {
                self.determineThread({ () -> () in
                    handler(nil,e, self)
                })
            }
            else
            {
                //convert the response to an array of T
                if let t : [T] = T.arrayFromData(data)
                {
                    self.determineThread({ () -> () in
                        handler(t,nil,self)
                    })
                }
                else
                {
                    //error if we could not deserialize
                    self.determineThread({ () -> () in
                        
                        if self.loggingLevel.rawValue >= QwikHttpLoggingLevel.errors.rawValue
                        {
                            self.printDebugInfo()
                        }
                        
                        handler(nil,NSError(domain: "QwikHttp", code: 500, userInfo: ["Error" : "Could not parse response"]), self)
                    })
                }
            }
        }
    }
    
    @available(iOS 13.0.0, *)
    public func getArrayResponse<T : QwikDataConversion>(_ type: T.Type) async -> Result<[T], Error> {
        return await withCheckedContinuation({ continuation in
            self.getArrayResponse(type) { result, error, request in
                if let result = result {
                    continuation.resume(returning: .success(result))
                }
                else if let error = error {
                    continuation.resume(returning: .failure(error))
                }
            }
        })
    }
    
    //Send the request with a simple boolean handler, which is optional
    @objc public func send( _ handler: QBooleanCompletionHandler? = nil)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            if let booleanHandler = handler
            {
                if let _ = error
                {
                    self.determineThread({ () -> () in
                        booleanHandler(false)
                    })
                }
                else
                {
                    self.determineThread({ () -> () in
                        booleanHandler(true)
                    })
                }
            }
        }
    }
    
    
    @objc public func getStringResponse(_ handler :  @escaping (String?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            if let e = error
            {
                self.determineThread({ () -> () in
                    handler(nil,e, self)
                })
            }
            else
            {
                if let t : String = String.fromData(data)
                {
                    self.determineThread({ () -> () in
                        handler(t,nil,self)
                    })
                }
            }
        }
    }
    
    @objc public func getDataResponse(_ handler :  @escaping (Data?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            self.determineThread({ () -> () in
                handler(data,error, self)
            })
        }
    }
    
    @objc public func getDictionaryResponse(_ handler :  @escaping (NSDictionary?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            if let e = error
            {
                self.determineThread({ () -> () in
                    handler(nil,e, self)
                })
            }
            else
            {
                if let d : NSDictionary = NSDictionary.fromData(data)
                {
                    self.determineThread({ () -> () in
                        handler(d,nil,self)
                    })
                }
            }
        }
    }
    
    @objc public func getArrayOfDictionariesResponse(_ handler :  @escaping ([NSDictionary]?, NSError?, QwikHttp) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
            if let e = error
            {
                self.determineThread({ () -> () in
                    handler(nil,e, self)
                })
            }
            else
            {
                if let d : [NSDictionary] = NSDictionary.arrayFromData(data)
                {
                    self.determineThread({ () -> () in
                        handler(d,nil,self)
                    })
                }
            }
        }
    }
    
    //this method is primarily used for the response interceptor as any easy way to restart the request
    @objc public func resend(_ handler: @escaping (Data?,URLResponse?, NSError? ) -> Void)
    {
        HttpRequestPooler.sendRequest(self, handler: handler)
    }
    
    //reset our completion handlers and response data
    @objc public func reset()
    {
        self.response = nil
        self.responseString = nil
        self.responseData = nil
        self.responseError = nil
        self.responseData = nil
        self.wasIntercepted = false
    }
}

// MARK: Populate Results
extension QwikHttp
{
    func readResult(data: Data?, urlResponse: URLResponse?, error: Error?)
    {
        let requestParams = self
        
        //set the values straight to the request object so we can read it if needed.
        requestParams.responseData = data
        requestParams.responseError = error as NSError?
        
        //set our response string
        if let responseString = QwikHttp.getResponseString(responseData)
        {
            requestParams.responseString = responseString as NSString
        }
        
        //check the responseCode to make sure its valid
        if let httpResponse = urlResponse as? HTTPURLResponse {
            
            requestParams.response = httpResponse
            requestParams.responseStatusCode = httpResponse.statusCode
            
            //if we didn't have an error from the http lib, but the response errored, then parse
            //and save the error response before we do intercept methods
            if httpResponse.statusCode / 100 != 2 && error == nil
            {
                //try to parse the result into an error dictionary of json, since some apis return this way
                //if that doesn't happen then we'll just return a generic user info dictionary
                var responseDict  = ["Error": "Error Response Code" as AnyObject]
                if let responseString = requestParams.responseString, responseString.description.count > 0
                {
                    if let errorDict = NSDictionary.fromJsonString(responseString as String) as? [String : AnyObject]
                    {
                        responseDict = errorDict
                    }
                    else {
                        responseDict["Error"] = responseString
                    }
                }
                
                let error = NSError(domain: "QwikHttp", code: httpResponse.statusCode, userInfo: responseDict )
                requestParams.responseError = error
                
                if self.loggingLevel.rawValue >= QwikHttpLoggingLevel.errors.rawValue
                {
                    requestParams.printDebugInfo()
                }
            }
            
            if let interceptor = QwikHttpConfig.responseInterceptor
            {
                interceptor.didSend?(requestParams)
            }
        }
    }
}

// MARK: Helpers
extension QwikHttp
{
    //a helper to to return an optional string from our ns data
    class func getResponseString(_ data : Data?) -> String?
    {
        if let d = data{
            return String(data: d, encoding: String.Encoding.utf8)
        }
        else
        {
            return nil
        }
    }
    
    //combine two dictionaries
    fileprivate func combinedDictionary(_ from: [String:AnyObject]!, with: [String:AnyObject]! ) -> [String:AnyObject]!
    {
        var result = from
        
        //ensure someone didn't pass us nil on accident
        if(with == nil)
        {
            return result
        }
        
        for(key, value) in with
        {
            result?[key] = value
        }
        return result
    }
    
    //create a url parameter string
    class func paramStringFrom(_ from: [String : String]!) -> String!
    {
        var string = ""
        var first = true
        for(key,value) in from
        {
            if !first
            {
                string = string + "&"
            }
            
            if let encoded = value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            {
                string = string + key + "=" + encoded
            }
            first = false
        }
        return string
    }
    
    //determine if we should run on the main or background thread and run it conditionally
    fileprivate func determineThread(_ code: @escaping () -> () )
    {
        if(self.responseThread == .main)
        {
            DispatchQueue.main.async {
                code()
            }
        }
        else
        {
            code()
        }
    }
    
    //run on the main thread
    fileprivate class func mainThread(_ code: @escaping () -> () )
    {
        DispatchQueue.main.async {
            code()
        }
    }
    
    @objc public func printDebugInfo(excludeResponse : Bool = false, filterLogs : Bool = QwikHttpConfig.filterLogs)
    {
        print(debugInfo(excludeResponse: excludeResponse, filterLogs: filterLogs))
    }
    
    @objc public func debugInfo(excludeResponse : Bool = false, filterLogs : Bool = QwikHttpConfig.filterLogs) -> String
    {
        var log = "----- QwikHttp Request -----\n"
        log = log + self.requestDescription()
        log = log + "HEADERS:\n"
        for (key, value) in self.headers
        {
            var filtered = false
            if filterLogs && QwikHttpConfig.filterWords.count > 0
            {
                if QwikHttpConfig.filterWords.contains(key)
                {
                    filtered = true
                }
            }
            
            if filtered
            {
                log = log + String(format: "%@: [FILTERED]\n", key)
            } else {
                log = log + String(format: "%@: %@\n", key, value)
            }
        }
        
        log = log + "BODY:\n"
        if let body = self.getBody(filterLogs: filterLogs)
        {
            log = log + String(format: "%@\n", body)
        }
        
        if excludeResponse == false
        {
            log = log + String(format: "RESPONSE: %@\n", String(self.responseStatusCode))
            if let responseData = self.responseData, let responseString = String(data: responseData, encoding: .utf8)
            {
                var loggedResponse = responseString
                if filterLogs && QwikHttpConfig.filterWords.count > 0
                {
                    loggedResponse = loggedResponse.filtered(sensitiveWords: QwikHttpConfig.filterWords)
                }
                log = log + loggedResponse + "\n"
            }
            if let error = responseError
            {
                log = log + String(format: "ERROR: %@\n",error.debugDescription)
            }
        }
        
        return log
    }
    
    @objc public func requestDescription() -> String
    {
        return String(format: "%@ to %@\n", self.httpMethod.description, self.urlString)
    }
}

// this class is used to pool our requests and also to avoid the need to retain our QwikRequest objects
// MARK: Request Pooler
private class HttpRequestPooler
{
    class func sendRequest(_ requestParams : QwikHttp!, handler: @escaping (Data?, URLResponse?, NSError?) -> Void)
    {
        //if the request has already been sent, then return
        guard requestParams.responseData == nil && requestParams.responseError == nil else
        {
            if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.debug.rawValue
            {
                print("QwikHttp: Request has already been sent. Returning.")
            }
            
            handler(requestParams.responseData, requestParams.response, requestParams.responseError)
            return
        }
        
        if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.debug.rawValue
        {
            print("QwikHttp: Preparing Request For Send")
        }
        
        let request: URLRequest
        do {
            request = try requestParams.getConfiguredRequest()
        }
        catch {
            if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.errors.rawValue
            {
                requestParams.printDebugInfo()
            }
            
            requestParams.responseError = error as NSError
            handler(nil, nil, error as NSError)
            return
        }
        
        //see if this request should be intercepted and if so call the interceptor.
        //don't worry about a completion handler since this should be called by the interceptor
        if let interceptor = QwikHttpConfig.requestInterceptor, requestParams.avoidRequestInterceptor == false , interceptor.shouldInterceptRequest(requestParams), requestParams.wasIntercepted == false
        {
            requestParams.wasIntercepted = true
            
            if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.requests.rawValue
            {
                print("QwikHttp: Request being intercepted")
            }
            
            interceptor.interceptRequest(requestParams, handler: handler)
            return
        }
        
        //show our spinner
        var showingSpinner = false
        if let title = requestParams.loadingTitle, let indicatorDelegate = QwikHttpConfig.loadingIndicatorDelegate
        {
            indicatorDelegate.showIndicator(title)
            showingSpinner = true
        }
        
        if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.debug.rawValue
        {
            print("QwikHttp: Starting Request Send")
        }
        
        //send our request and do a bunch of common stuff before calling our response handler
        requestParams.requestSender.sendRequest(request) { (responseData, urlResponse, error) in
            
            if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.debug.rawValue
            {
                print("QwikHttp: Request Returned")
            }
            
            //hide our spinner
            if let indicatorDelegate = QwikHttpConfig.loadingIndicatorDelegate , showingSpinner == true
            {
                indicatorDelegate.hideIndicator()
            }
            
            // read the result of the request into the QwikHttp Object
            requestParams.readResult(data: responseData, urlResponse: urlResponse, error: error)
            
            // if we got back a response, then call our interceptors if necessary.
            if let httpResponse = urlResponse as? HTTPURLResponse {
            
                if let interceptor = QwikHttpConfig.responseInterceptor
                {
                    interceptor.didSend?(requestParams)
                }
                
                //see if we are configured to use an interceptor and if so, check it to see if we should use it
                if let interceptor = QwikHttpConfig.responseInterceptor , !requestParams.wasIntercepted &&  interceptor.shouldInterceptResponse(httpResponse) && !requestParams.avoidResponseInterceptor
                {
                    if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.requests.rawValue
                    {
                        print("QwikHttp: Response being intercepted")
                        requestParams.printDebugInfo()
                    }
                    
                    //call the interceptor and return. The interceptor will call our handler.
                    requestParams.wasIntercepted = true
                    interceptor.interceptResponse(requestParams, handler: handler)
                    return
                }
                
                //error for invalid response
                //in order to be considered successful the response must be in the 200's
                if httpResponse.statusCode / 100 != 2 && error == nil
                {
                    handler(responseData, urlResponse, requestParams.responseError)
                    return
                }
            }
            
            if requestParams.loggingLevel.rawValue >= QwikHttpLoggingLevel.requests.rawValue
            {
                requestParams.printDebugInfo()
            }
            
            handler(responseData, urlResponse, error as NSError?)
        }
    }
}


// MARK: String helpers
extension String
{
    func filtered(sensitiveWords: [String]) -> String
    {
        var filterSearchRegex = ""
        for word in sensitiveWords
        {
            filterSearchRegex.append(word)
            if word != sensitiveWords.last
            {
                filterSearchRegex.append("|")
            }
        }
        
        let regexExpression = String(format: "\"(%@)\" *: *[^,}]*", filterSearchRegex)
        if let regex = try? NSRegularExpression(pattern: regexExpression, options: .caseInsensitive)
        {
            //let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: string.length))
            return regex.stringByReplacingMatches(in: self, options: [], range: NSRange(location: 0, length: self.count), withTemplate: "$1: [FILTERED]")
        }
        
        return self
    }
}
