//
//  ViewController.swift
//  QwikHttp
//
//  Created by Logan Sease on 01/27/2016.
//  Copyright (c) 2016 Logan Sease. All rights reserved.
//

import UIKit
import QwikHttp
import SeaseAssist

class ViewController: UIViewController {

    //an index variable to keep track of the # of requests we've sent
    var i = -1
    
    override func viewDidLoad() {
        QwikHelper.shared().configure()
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sendRequest()
    }
    
    @IBAction func sendRequest()
    {
        i += 1
        
        if(i == 0)
        {
            //call a get to the itunes search api and find our top overall paid apps on the US Store.
            QwikHttp(url: "http://ax.itunes.apple.com/WebObjects/MZStoreServices.woa/ws/RSS/toppaidapplications/sf=143441/limit=10/json",
                     httpMethod: HttpRequestMethod.get)
                .getResponse(NSDictionary.self,  { (result, error, request) -> Void in
                
                request.printDebugInfo(excludeResponse: true)
                
                //parse our feed object from the response
                if let dict = result, let feed = dict["feed"] as? NSDictionary, let entries = feed["entry"] as? NSArray
                {
                    //note, this handy helper comes from seaseAssist pod
                    UIAlertController.showAlert(withTitle: "Success", andMessage: String(format: "We Found %li",entries.count), from: self)
                }
                    
                //show an error if we could parse through our dictionary
                else
                {
                    UIAlertController.showAlert(withTitle: "Failure", andMessage: "Error parsing the result", from: self)
                }
                
            })
        }
        else if (i == 1)
        {            
            let r = Restaurant()
            r.name = String(format: "Rest Test %i", arc4random() % 1000)
            
            //create a new restaurant
            QwikHttp("https://resttest2016.herokuapp.com/restaurants", httpMethod: .post)
                .setLoadingTitle("Creating")
                .setObject(r)
                .addUrlParams(["format" : "json"])
                .getResponse(Restaurant.self, { (results, error, request) -> Void in
                
                //get the restaurant from the response
                if let restaurant = results, let name = restaurant.name
                {
                    UIAlertController.showAlert(withTitle: "Success", andMessage: String(format: "We Found %@",name ), from: self)
                }
                else
                {
                    UIAlertController.showAlert(withTitle: "Failure", andMessage: String(format: "Load error"), from: self)
                }
                
            })
        }
            
        else if (i == 2)
        {
            if #available(iOS 13, *) {
                //get an array of restaurants with async
                Task {
                    let request = QwikHttp("https://resttest2016.herokuapp.com/restaurants", httpMethod: .get).addUrlParams(["format" : "json"])
                    let response = await request.getArrayResponse(Restaurant.self)
                    switch response {
                    case .success(let result):
                        UIAlertController.showAlert(withTitle: "Success", andMessage: "We Found \(result.count) with async, response code: \(request.responseStatusCode)", from: self)
                    case .failure(let error):
                        UIAlertController.showAlert(withTitle: "Failure", andMessage: String(format: "Load error \(error)"), from: self)
                    }
                }
            } else {
                i += 1
                sendRequest()
            }
        }
        
        else if (i == 3)
        {
            //call a get with a specific restaurant. This is an example of the basic boolean result handler
            //no response info is available, but you can quickly determine if the response was successful or not.
            QwikHttp("https://resttest2016.herokuapp.com/restaurants/1", httpMethod: .get)
                .addUrlParams(["format" : "json"]).send({ (success) -> Void in
                
                if success
                {
                    UIAlertController.showAlert(withTitle: "Load Successful", andMessage:"Good work. You're awesome.", from: self)
                }
                else
                {
                    UIAlertController.showAlert(withTitle: "Failure", andMessage: String(format: "Load error"), from: self)
                }
            })
        }
        
        else if (i == 4)
        {
            let r = Restaurant()
            r.name = String(format: "Rest Test %i", arc4random() % 1000)
            r.secret = "HIDE THIS PLEASE"
            
            //create a new restaurant
            QwikHttp("https://resttest2016.herokuapp.com/restaurants", httpMethod: .post)
                .setLoadingTitle("Creating")
                .addHeader("Authorization", value: "Bearer TEST")
                .setObject(r)
                .addUrlParams(["format" : "json"])
                .getResponse(Restaurant.self, { (results, error, request) -> Void in
                    
                    UIAlertController.showAlert(withTitle: "Filtered Request Sent", andMessage: request.debugInfo(excludeResponse: true, filterLogs: true), from: self)
                    
            })
        }
        
        else if (i == 5)
        {
            //get an array of restaurants
            QwikHttp("https://resttest2016.herokuapp.com/restaurants", httpMethod: .get)
                .addUrlParams(["format" : "json"])
                .setRequestSender(UrlSessionRequestSender(urlSession: URLSession.shared))
                .getArrayResponse(Restaurant.self, { (results, error, request) -> Void in
                    
                    //display the restaurant count
                    if let resultsArray = results
                    {
                        UIAlertController.showAlert(withTitle: "Success", andMessage: String(format: "We Found %li",resultsArray.count), from: self)
                    }
                    else
                    {
                        UIAlertController.showAlert(withTitle: "Failure", andMessage: String(format: "Load error"), from: self)
                    }
            })
            
            //reset our request counter
            i = -1;
        }
        
    }

}

