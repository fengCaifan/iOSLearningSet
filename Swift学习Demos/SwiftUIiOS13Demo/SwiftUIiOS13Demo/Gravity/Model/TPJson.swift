//
//  TPJson.swift
//  Chat
//
//  Created by chengqifan on 2021/7/2.
//  Copyright © 2021 Baidu. All rights reserved.
//

import Foundation

public protocol TPJson: Codable {}

public extension TPJson {
    var jsonData: Data? {
        let json = try? JSONEncoder().encode(self)
        return json
    }
    
    var jsonObject: Any? {
        guard let jsonData = jsonData,
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) else {
            return nil
        }
        return jsonObject
    }
    
    var dictionary: [String: Any]? {
        return jsonObject as? [String: Any]
    }
    
    var jsonString: String? {
        guard let jsonData = jsonData else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    var base64String: String? {
        guard let jsonObject = jsonObject else { return nil }
        guard JSONSerialization.isValidJSONObject(jsonObject) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions(rawValue: 0)).base64EncodedString()
    }
}

public extension TPJson {
    static func decodeBase64(_ stringValue: String) -> Self? {
        if let data = Data(base64Encoded: stringValue).flatMap({ String(data: $0, encoding: .utf8) }) {
            return self.decodeModelFromString(data)
        }
        return nil
    }
    
    static func decodeModel(of jsonObjc: Any?) -> Self? {
        guard let json = jsonObjc else { return nil }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else { return nil }
        return decodeModelWith(data: jsonData)
    }
    
    static func decodeModelWith(data: Data) -> Self? {
        guard let model = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return model
    }
    
    static func decodeModelFromString(_ jsonString: String) -> Self? {
        guard let data = jsonString.data(using: .utf8) else {
            print("jsonString is invalid!")
            return nil
        }
        return decodeModelWith(data: data)
    }
    
    static func decodeModel(of jsonArry: [Any]) -> [Self] {
        var models = [Self]()
        jsonArry.forEach { item in
            if let model = decodeModel(of: item) {
                models.append(model)
            }
        }
        return models
    }
    
    static func decodeModels(of data: Any?) -> [Self] {
        guard let array = data as? [Any] else { return [] }
        return decodeModel(of: array)
    }
    
    /// 最外层就是数组，如：["key": "value"]
    static func decodeModelsFromString(_ jsonString: String) -> [Self] {
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }
        return decodeModelsFromArrayData(data)
    }
    
    // 最外层就是数组，如：["key": "value"]
    static func decodeModelsFromArrayData(_ data: Data) -> [Self] {
        guard let models = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return models
    }
}


public extension TPJson {
    static func dictToJsonString(_ dictionary: [String: Any]) -> String {
        return TPJsonParser.dictToJsonString(dictionary) ?? ""
    }
    
    /// data 必须是Codable
    static func dataToJsonString(_ data: Any) -> String? {
        return TPJsonParser.dataToJsonString(data)
    }
    
    static func arrayToJsonString(_ array: [Codable]) -> String? {
        return TPJsonParser.arrayToJsonString(array)
    }
}


public struct TPJsonParser {
    // MARK: - jsonString -> objct
    public static func jsonStringToDir(_ jsonString: String) -> [String: Any]? {
        guard let dir = jsonStringToObject(jsonString) as? [String: Any] else {
            return nil
        }
        return dir
    }
    
    public static func jsonStringToObject(_ jsonString: String) -> Any? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        guard let objct = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) else { return nil }
        return objct
    }
    
    // MARK: - objct -> jsonString
    /// data 必须是Codable
    public static func dataToJsonString(_ data: Any) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    public static func arrayToJsonString(_ array: [Codable]) -> String? {
        guard !array.isEmpty else {
            return ""
        }
        return dataToJsonString(array)
    }
    
    public static func dictToJsonString(_ dictionary: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
}
