//
//  QwikCodable.swift
//
//  Created by lsease on 7/13/17.
//  This is a protocol that extends Codable and adds simple serialization
//  and deserialization methods

import Foundation

//MARK: Serialization Helpers
public protocol QwikCodable : Codable, QwikDataConversion {
    func serialize() -> Data?
    static func deserialize(from data : Data?) -> Self?
    static func deserializeArray(from data : Data?) -> [Self]?
    func toDictionary() -> [AnyHashable : Any]?
    static func fromDictionary(_ dictionary : [AnyHashable : Any]) -> Self?
    static func arrayFromDictionary(_ dictionary : [[AnyHashable : Any]]) -> [Self]?
}

extension QwikCodable
{
    public static func fromData<T>(_ data : Data?) -> T?{
        return deserialize(from: data) as? T
    }
    
    public static func arrayFromData<T>(_ data : Data?) -> [T]?
    {
        return deserializeArray(from: data) as? [T]
    }
}

extension QwikCodable
{
    public func toDictionary() -> [AnyHashable : Any]?
    {
        if let data = serialize()
        {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable : Any]
            {
                return json
            }
        }
        return nil
    }
    
    public static func fromDictionary(_ dictionary : [AnyHashable : Any]) -> Self?
    {
        if let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
        {
            return Self.deserialize(from: data)
        }
        return nil
    }
    
    public static func arrayFromDictionary(_ dictionaries : [[AnyHashable : Any]]) -> [Self]?
    {
        var results : [Self] = []
        for (dict) in dictionaries
        {
            if let object = fromDictionary(dict)
            {
                results.append(object)
            }
        }
        return results
    }
    
    public func serialize() -> Data?
    {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
    
    public static func deserialize(from data : Data?) -> Self?
    {
        guard let data = data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(Self.self, from: data)
    }
    
    public static func deserializeArray(from data : Data?) -> [Self]?
    {
        guard let data = data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([Self].self, from: data)
    }
}
