//
//  Restaurant.swift
//  QwikHttp
//
//  Created by Logan Sease on 2/26/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import QwikJson

class Restaurant : QwikJson{
    @objc var image_url : String?
    @objc var name : String?
    @objc var createdAt : DBTimeStamp?
    @objc var secret: String?
}
