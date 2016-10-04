//
//  QwikHttp.swift
//  oAuthExample
//
//  Created by Logan Sease on 1/26/16.
//  Copyright © 2016 Logan Sease. All rights reserved.
//

import Foundation
import QwikJson


//a response interceptor specific to objective c requests.
//this is used to conditionally intercept the response. See the read me doc for more info
@objc public protocol QwikHttpObjcResponseInterceptor
{
    @objc func shouldInterceptResponse(_ response: URLResponse!) -> Bool
    @objc func interceptResponseObjc(_ request : QwikHttpObjc!, handler: (Data?, URLResponse?, NSError?) -> Void)
}

//the request interceptor can be used to intercept requests before they are sent out.
@objc public protocol QwikHttpObjcRequestInterceptor
{
    @objc func shouldInterceptRequest(_ request: QwikHttpObjc!) -> Bool
    @objc func interceptRequest(_ request : QwikHttpObjc!,  handler: (Data?, URLResponse?, NSError?) -> Void)
}


//the main request object
@objc open class QwikHttpObjc : NSObject {
    
    /***** REQUEST VARIABLES ******/
    fileprivate var urlString : String!
    fileprivate var httpMethod : HttpRequestMethod!
    fileprivate var headers : [String : String]!
    fileprivate var params : [String : AnyObject]!
    fileprivate var body: Data?
    fileprivate var parameterType : ParameterType!
    fileprivate var responseThread : ResponseThread!
    
    //response variables
    open var responseError : NSError?
    open var responseData : Data?
    open var response: URLResponse?
    open var responseString : NSString?
    open var wasIntercepted = false
    open var avoidResponseInterceptor = false
    
    //class params
    fileprivate var timeOut : Double!
    fileprivate var cachePolicy: NSURLRequest.CachePolicy!
    fileprivate var loadingTitle: String?
    
    /**** REQUIRED INITIALIZER*****/
    public convenience init(url: String!, httpMethod: HttpRequestMethod!)
    {
        self.init(url,httpMethod: httpMethod)
    }
    
    @objc public init(_ url: String!, httpMethod: HttpRequestMethod)
    {
        super.init()
        
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
    
    /**** ADD / SET VARIABLES. ALL RETURN SELF TO ENCOURAGE SINGLE LINE BUILDER TYPE SYNTAX *****/
    @objc open func addParam(_ key : String!, value: String!) -> QwikHttpObjc
    {
        params[key] = value as AnyObject?
        return self
    }
    @objc open func addHeader(_ key : String!, value: String!) -> QwikHttpObjc
    {
        headers[key] = value
        return self
    }
    
    @objc open func setLoadingTitle(_ title: String?) -> QwikHttpObjc
    {
        self.loadingTitle = title
        return self
    }
    
    @objc open func addUrlParams(_ params: [String: String]!) -> QwikHttpObjc
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
    
    @objc open func setObject(_ object: QwikJson?)  -> QwikHttpObjc
    {
        if let qwikJson = object,  let params = qwikJson.toDictionary() as? [String : AnyObject]
        {
            self.addParams(params)
            self.setParameterType(.json)
        }
        return self
    }
    
    @objc open func addParams(_ params: [String: AnyObject]!) -> QwikHttpObjc
    {
        self.params = combinedDictionary(self.params, with: params)
        return self
    }
    
    @objc open func addHeaders(_ headers: [String: String]!) -> QwikHttpObjc
    {
        self.headers = combinedDictionary(self.headers as [String : AnyObject]!, with: headers as [String : AnyObject]!) as! [String : String]
        return self
    }
    @objc open func setBody(_ body : Data!) -> QwikHttpObjc
    {
        self.body = body
        return self;
    }
    @objc open func setParameterType(_ parameterType : ParameterType) -> QwikHttpObjc
    {
        self.parameterType = parameterType
        return self;
    }
    
    @objc open func setCachePolicy(_ policy: NSURLRequest.CachePolicy) -> QwikHttpObjc
    {
        cachePolicy = policy
        return self
    }
    
    @objc open func setTimeOut(_ timeOut: Double) -> QwikHttpObjc
    {
        self.timeOut = timeOut
        return self
    }
    @objc open func setResponseThread(_ responseThread: ResponseThread) -> QwikHttpObjc
    {
        self.responseThread = responseThread
        return self
    }
    
    /********* RESPONSE HANDLERS / SENDING METHODS *************/
    
    
    @objc open func getStringResponse(_ handler :  @escaping (String?, NSError?, QwikHttpObjc?) -> Void)
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
    
    @objc open func getDataResponse(_ handler :  @escaping (Data?, NSError?, QwikHttpObjc?) -> Void)
    {
        HttpRequestPooler.sendRequest(self) { (data, response, error) -> Void in
            
                self.determineThread({ () -> () in
                    handler(data,error, self)
                })
        }
    }
    
    @objc open func getDictionaryResponse(_ handler :  @escaping (NSDictionary?, NSError?, QwikHttpObjc?) -> Void)
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
    
    @objc open func getArrayResponse(_ handler :  @escaping ([NSDictionary]?, NSError?, QwikHttpObjc?) -> Void)
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
    
    //Send the request!
    @objc open func send( _ handler: BooleanCompletionHandler? = nil)
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
    
    //a helper method to duck the response interceptor. Can be useful for cases like logout which
    //could lead to infinite recursion
    open func setAvoidResponseInterceptor(_ avoid : Bool!)  -> QwikHttpObjc!
    {
        self.avoidResponseInterceptor = true
        return self
    }
    
    //this method is primarily used for the response interceptor as any easy way to restart the request
    @objc open func resend(_ handler: @escaping (Data?,URLResponse?, NSError? ) -> Void)
    {
        HttpRequestPooler.sendRequest(self, handler: handler)
    }
    
    //reset our completion handlers and response data
    @objc open func reset()
    {
        self.response = nil
        self.responseString = nil
        self.responseData = nil
        self.responseError = nil
        self.responseData = nil
        self.wasIntercepted = false
    }
    
    /**** HELPERS ****/
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

    //conditionally run on the main or background thread
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

}

//this class is used to pool our requests and also to avoid the need to retain our QwikRequest objects
private class HttpRequestPooler
{
    
    fileprivate class func paramTypeToString(_ type: HttpRequestMethod) -> String!
    {
        switch(type)
        {
        case HttpRequestMethod.post:
            return "POST"
        case HttpRequestMethod.put:
            return "PUT"
        case HttpRequestMethod.get:
            return "GET"
        case HttpRequestMethod.delete:
            return "DELETE"
        }
    }
    
    class func sendRequest(_ requestParams : QwikHttpObjc!, handler: @escaping (Data?, URLResponse?, NSError?) -> Void)
    {
        //make sure our request url is valid
        guard let url = URL(string: requestParams.urlString)
            else
        {
            handler(nil,nil,NSError(domain: "QwikHTTP", code: 500, userInfo:["Error" : "Invalid URL"]))
            return
        }
        
        //see if this request should be intercepted and if so call the interceptor.
        //don't worry about a completion handler since this should be called by the interceptor
        if let interceptor = QwikHttpConfig.requestInterceptorObjc , interceptor.shouldInterceptRequest(requestParams) && !requestParams.wasIntercepted
        {
            requestParams.wasIntercepted = true
            interceptor.interceptRequest(requestParams, handler: handler)
            return
        }
        
        //create our http request
        let request = NSMutableURLRequest(url: url, cachePolicy: requestParams.cachePolicy, timeoutInterval: requestParams.timeOut)
        
        //set up our http method and add headers
        request.httpMethod = paramTypeToString(requestParams.httpMethod)
        for(key, value) in requestParams.headers
        {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        //set up our parameters
        if let body = requestParams.body
        {
            request.httpBody = body
        }
        else if requestParams.parameterType == .formEncoded  && requestParams.params.count > 0
        {
            //convert parameters to form encoded values and set to body
            if let params = requestParams.params as? [String : String]
            {
                request.httpBody = QwikHttp.paramStringFrom(params).data(using: String.Encoding.utf8)
                
                //set the request type headers
                //application/x-www-form-urlencoded
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
                
                //if we couldn't encode the values, then perhaps json was passed in unexpectedly, so try to parse it as json.
            else
            {
                requestParams.setParameterType(.json)
            }
        }
        
        //try json parsing, note that formEncoding could have changed the type if there was an error, so don't use an else if
        if requestParams.parameterType == .json && requestParams.params.count > 0
        {
            //convert parameters to json string and form and set to body
            do {
                let data = try JSONSerialization.data(withJSONObject: requestParams.params, options: JSONSerialization.WritingOptions(rawValue: 0))
                request.httpBody = data
            }
            catch let JSONError as NSError {
                handler(nil,nil,JSONError)
                return
            }
            
            //set the request type headers
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        //show our spinner
        var showingSpinner = false
        if let title = requestParams.loadingTitle, let indicatorDelegate = QwikHttpConfig.loadingIndicatorDelegate
        {
             indicatorDelegate.showIndicator(title)
            showingSpinner = true
        }
        
        //send our request and do a bunch of common stuff before calling our response handler
        URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (responseData, urlResponse, error) -> Void in
            
            //set the values straight to the request object so we can read it if needed.
            requestParams.responseData = responseData
            requestParams.responseError = error as NSError?

            //set our response string
            if let responseString = self.getResponseString(responseData)
            {
                requestParams.responseString = responseString as NSString
            }
            
            //hide our spinner
            if let indicatorDelegate = QwikHttpConfig.loadingIndicatorDelegate , showingSpinner
            {
                indicatorDelegate.hideIndicator()
            }
            
            //check the responseCode to make sure its valid
            if let httpResponse = urlResponse as? HTTPURLResponse {
            
                requestParams.response = httpResponse
            
                //see if we are configured to use an interceptor and if so, check it to see if we should use it
                if let interceptor = QwikHttpConfig.responseInterceptorObjc , !requestParams.wasIntercepted && interceptor.shouldInterceptResponse(httpResponse) && !requestParams.avoidResponseInterceptor
                {
                    //call the interceptor and return. The interceptor will call our handler.
                    requestParams.wasIntercepted = true
                    interceptor.interceptResponseObjc(requestParams, handler: handler)
                    return
                }
                
                //error for invalid response
                //in order to be considered successful the response must be in the 200's
                if httpResponse.statusCode / 100 != 2 && error == nil{
                    handler(responseData, urlResponse, NSError(domain: "QwikHttp", code: httpResponse.statusCode, userInfo: ["Error": "Error Response Code"]))
                    return
                }
            }
            
            handler(responseData, urlResponse, error as NSError?)
        }).resume()
    }
    
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
    
}


        


