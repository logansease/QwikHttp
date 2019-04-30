//
//  QwikHttpRequestSender.swift
//  QwikHttp
//
//  Created by lsease on 4/30/19.
//

import Foundation

@objc public protocol QwikHttpRequestSender {
    @objc func sendRequest(_ request: URLRequest, handler: @escaping (Data?, URLResponse?, Error?) -> Void)
}

// MARK: Session Request Sender

@objc public class UrlSessionRequestSender: NSObject, QwikHttpRequestSender {
    
    private let customSession: URLSession?
    
    static var defaultSender: UrlSessionRequestSender {
        struct Singleton {
            static let instance = UrlSessionRequestSender()
        }
        return Singleton.instance
    }
    
    @objc public init(urlSession: URLSession? = nil)
    {
        self.customSession = urlSession
    }
    
    public func sendRequest(_ request: URLRequest, handler: @escaping (Data?, URLResponse?, Error?) -> Void)
    {
        let session = customSession ?? QwikHttpConfig.urlSession
        
        //send our request and do a bunch of common stuff before calling our response handler
        session.dataTask(with: request as URLRequest, completionHandler: { (responseData, urlResponse, error) -> Void in
            handler(responseData, urlResponse, error)
        }).resume()
    }
}
