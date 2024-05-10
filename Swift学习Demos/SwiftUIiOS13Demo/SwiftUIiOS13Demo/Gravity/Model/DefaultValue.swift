//
//  DefaultValue.swift
//  Chat
//
//  Created by chengqifan on 2021/8/12.
//  Copyright © 2021 Baidu. All rights reserved.
//

import Foundation

public protocol DefaultValue {
    associatedtype Value: Codable
    static var defaultValue: Value { get }
}

@propertyWrapper
public struct Default<T: DefaultValue>: Codable {
    public var wrappedValue: T.Value
    private var mapperKey: String?
    
    public init() {
        self.wrappedValue = T.defaultValue
    }
    
    public init(default defaultValue: T.Value) {
        self.wrappedValue = defaultValue
    }
    
    public init(_ type: T.Type, value: T.Value) {
        self.wrappedValue = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var value = try? container.decode(T.Value.self)
        if value == nil, T.defaultValue is Bool {
            if let intValue = try? container.decode(Int.self) {
                value = (intValue > 0) as? T.Value
            } else if let stringValue = try? container.decode(String.self) {
                if stringValue == "true" || stringValue == "True" {
                    value = true as? T.Value
                } else if stringValue == "false" || stringValue == "False" {
                    value = false as? T.Value
                }
            }
        } else if value == nil, T.defaultValue is Int {
            if let stringValue = try? container.decode(String.self) { // convert json String to model Int
                value = Int(stringValue) as? T.Value
            } else if let boolValue = try? container.decode(Bool.self) { // convert json Bool to model Int
                value = (boolValue ? 1 : 0) as? T.Value
            }
        } else if value == nil, T.defaultValue is String {
            // convert json Int to model String
            if let intValue = try? container.decode(Int.self) {
                value = String("\(intValue)") as? T.Value
            } else if let doubleValue = try? container.decode(Double.self) {
                value = String("\(doubleValue)") as? T.Value
            }
        } else if value == nil {
            assert(true, "TPJson: error type of json key")
        }
        wrappedValue = value ?? T.defaultValue
    }
}

// extension Default: Equatable where T.Value: Equatable {}
// extension Default: Hashable where T.Value: Hashable {}

public extension KeyedDecodingContainer {
    func decode<T>(
        _ type: Default<T>.Type,
        forKey key: Key
    ) throws -> Default<T> where T: DefaultValue {
        try decodeIfPresent(type, forKey: key) ?? Default(default: T.defaultValue)
    }
}

public extension KeyedEncodingContainer {
    mutating func encode<T>(_ value: Default<T>, forKey key: Key) throws {
        try encode(value.wrappedValue, forKey: key)
    }
}

public enum False: DefaultValue {
    public static let defaultValue = false
}

public enum True: DefaultValue {
    public static let defaultValue = true
}

public enum Empty<A>: DefaultValue where A: Codable, A: RangeReplaceableCollection {
    public static var defaultValue: A { A() }
}

public enum EmptyArray<A>: DefaultValue where A: Codable, A: RangeReplaceableCollection {
    public static var defaultValue: [A] { [] }
}

public enum EmptyDictionary<K, V>: DefaultValue where K: Hashable & Codable, V: Codable {
    public static var defaultValue: [K: V] { [:] }
}

public enum FirstCase<A>: DefaultValue where A: Codable, A: CaseIterable {
    public static var defaultValue: A { A.allCases.first! }
}

public enum Zero: DefaultValue {
    public static let defaultValue = 0
}

public enum One: DefaultValue {
    public static let defaultValue = 1
}

/// negative 1
public enum NegOne: DefaultValue {
    public static let defaultValue = -1
}

public enum ZeroDouble: DefaultValue {
    public static let defaultValue: Double = 0
}

public enum ZeroInt64: DefaultValue {
    public static let defaultValue: Int64 = 0
}

public enum ZeroUInt64: DefaultValue {
    public static let defaultValue: UInt64 = 0
}

public enum ZeroTimeInterval: DefaultValue {
    public static let defaultValue: TimeInterval = 0
}

public struct DataEmpty: DefaultValue {
    public static let defaultValue: Data = Data()
}

public extension Default {
    typealias TrueValue = Default<True>
    typealias FalseValue = Default<False>
    typealias EmptyString = Default<Empty<String>>
    typealias IntZero = Default<Zero>
    typealias IntOne = Default<One>
    typealias IntNegOne = Default<NegOne>
    typealias Int64Zero = Default<ZeroInt64>
    typealias UInt64Zero = Default<ZeroUInt64>
    typealias DoubleZero = Default<ZeroDouble>
    typealias TimeIntervalZero = Default<ZeroTimeInterval>
    typealias DataEmptyValue = Default<DataEmpty>
}

// 下列方法用于辅助自定义默认值，使用init(_ type: T.Type, value: T.Value)方法
public struct DefaultString: DefaultValue {
    public static let defaultValue: String = ""
}

public struct DefaultBool: DefaultValue {
    public static let defaultValue: Bool = false
}

public struct DefaultInt: DefaultValue {
    public static let defaultValue: Int = 0
}

public struct DefaultDouble: DefaultValue {
    public static let defaultValue: Double = 0
}
