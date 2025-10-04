//
//  File 2.swift
//  PicoResponses
//
//  Created by Ronald Mannak on 10/4/25.
//

import Foundation

// MARK: - Generic Value Containers

public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let int64 = try? container.decode(Int64.self) {
            self.value = int64
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value in AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var unwrapped: Any = value
        while let wrapped = unwrapped as? AnyCodable {
            unwrapped = wrapped.value
        }
        switch unwrapped {
        case _ as NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int64 as Int64:
            try container.encode(int64)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(unwrapped, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value in AnyCodable"))
        }
    }

    public var stringValue: String? {
        value as? String
    }

    public var boolValue: Bool? {
        value as? Bool
    }

    public var intValue: Int? {
        switch value {
        case let int as Int:
            return int
        case let int64 as Int64:
            return Int(exactly: int64)
        case let double as Double:
            return Int(double)
        default:
            return nil
        }
    }

    public var int64Value: Int64? {
        switch value {
        case let int64 as Int64:
            return int64
        case let int as Int:
            return Int64(int)
        case let double as Double:
            return Int64(double)
        case let number as NSNumber:
            return number.int64Value
        case let string as String:
            return Int64(string)
        default:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let int64 as Int64:
            return Double(int64)
        default:
            return nil
        }
    }

    public var dictionaryValue: [String: AnyCodable]? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }
        var result: [String: AnyCodable] = [:]
        for (key, value) in dictionary {
            result[key] = AnyCodable(value)
        }
        return result
    }

    public var arrayValue: [AnyCodable]? {
        guard let array = value as? [Any] else {
            return nil
        }
        return array.map { AnyCodable($0) }
    }

    var jsonObject: Any {
        var unwrapped: Any = value
        while let wrapped = unwrapped as? AnyCodable {
            unwrapped = wrapped.value
        }
        if let dictionary = unwrapped as? [String: Any] {
            var converted: [String: Any] = [:]
            for (key, value) in dictionary {
                converted[key] = AnyCodable(value).jsonObject
            }
            return converted
        }
        if let array = unwrapped as? [Any] {
            return array.map { AnyCodable($0).jsonObject }
        }
        return unwrapped
    }
}

public func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
    switch (lhs.value, rhs.value) {
    case (_ as NSNull, _ as NSNull):
        return true
    case let (l as Bool, r as Bool):
        return l == r
    case let (l as Int, r as Int):
        return l == r
    case let (l as Int64, r as Int64):
        return l == r
    case let (l as Int, r as Int64):
        return Int64(l) == r
    case let (l as Int64, r as Int):
        return l == Int64(r)
    case let (l as Double, r as Double):
        return l == r
    case let (l as String, r as String):
        return l == r
    case let (l as [String: Any], r as [String: Any]):
        return NSDictionary(dictionary: l).isEqual(to: r)
    case let (l as [Any], r as [Any]):
        return NSArray(array: l).isEqual(to: r)
    default:
        return false
    }
}

extension Dictionary where Key == String, Value == AnyCodable {
    func jsonObject() -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in self {
            result[key] = value.jsonObject
        }
        return result
    }

    func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject()) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}

extension Array where Element == AnyCodable {
    fileprivate func jsonObject() -> [Any] {
        map { $0.jsonObject }
    }
}

// MARK: - JSON Schema

// MARK: - JSON Schema

public indirect enum JSONSchema: Codable, Sendable, Equatable {
    public enum PrimitiveType: String, Codable, Sendable {
        case string
        case number
        case integer
        case object
        case array
        case boolean
        case null
    }

    public enum AdditionalProperties: Codable, Sendable, Equatable {
        case boolean(Bool)
        case schema(JSONSchema)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                self = .boolean(bool)
            } else {
                self = .schema(try JSONSchema(from: decoder))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .boolean(let value):
                try container.encode(value)
            case .schema(let schema):
                try container.encode(schema)
            }
        }
    }

    case document(root: JSONSchema, definitions: [String: JSONSchema] = [:])
    case null(description: String? = nil)
    case boolean(description: String? = nil)
    case string(minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil, format: String? = nil, description: String? = nil)
    case number(
        multipleOf: Double? = nil,
        minimum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMaximum: Double? = nil,
        description: String? = nil
    )
    case integer(
        multipleOf: Int64? = nil,
        minimum: Int64? = nil,
        exclusiveMinimum: Int64? = nil,
        maximum: Int64? = nil,
        exclusiveMaximum: Int64? = nil,
        description: String? = nil
    )
    case array(items: JSONSchema, minItems: Int? = nil, maxItems: Int? = nil, description: String? = nil)
    case tuple(prefixItems: [JSONSchema], items: JSONSchema? = nil, minItems: Int? = nil, maxItems: Int? = nil, description: String? = nil)
    case object(
        properties: [String: JSONSchema],
        patternProperties: [String: JSONSchema]? = nil,
        required: Set<String> = [],
        additionalProperties: AdditionalProperties = .boolean(true),
        description: String? = nil
    )
    case enumeration([AnyCodable], description: String? = nil)
    case not(JSONSchema, description: String? = nil)
    case anyOf([JSONSchema], description: String? = nil)
    case allOf([JSONSchema], description: String? = nil)
    case oneOf([JSONSchema], description: String? = nil)
    case conditional(if: JSONSchema, then: JSONSchema?, else: JSONSchema?, description: String? = nil)
    case union([PrimitiveType], description: String? = nil)
    case constant(AnyCodable, description: String? = nil)
    case reference(String, description: String? = nil)
    case raw([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self = JSONSchema.parse(raw: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let dictionary = dictionaryRepresentation()
        try container.encode(dictionary.mapValues { AnyCodable($0) })
    }

    public static func makeRaw(_ value: [String: AnyCodable]) -> JSONSchema {
        .raw(value)
    }

    private static func parse(raw: [String: AnyCodable]) -> JSONSchema {
        if let defsDictionary = raw["$defs"]?.dictionaryValue, !defsDictionary.isEmpty {
            var remainder = raw
            remainder["$defs"] = nil
            let definitions = parseDefinitions(defsDictionary)
            let root = JSONSchema.parse(raw: remainder)
            return .document(root: root, definitions: definitions)
        }

        if raw["prefixItems"] != nil {
            // TODO: Support tuple schemas expressed with prefixItems.
            return .raw(raw)
        }

        let description = raw["description"]?.stringValue

        if let notDictionary = raw["not"]?.dictionaryValue {
            return .not(JSONSchema.parse(raw: notDictionary), description: description)
        }

        if let ifDictionary = raw["if"]?.dictionaryValue {
            let thenSchema = raw["then"]?.dictionaryValue.map { JSONSchema.parse(raw: $0) }
            let elseSchema = raw["else"]?.dictionaryValue.map { JSONSchema.parse(raw: $0) }
            return .conditional(if: JSONSchema.parse(raw: ifDictionary), then: thenSchema, else: elseSchema, description: description)
        }

        if let ref = raw["$ref"]?.stringValue {
            return .reference(ref, description: description)
        }

        if let schemas = decodeSchemas(key: "anyOf", from: raw) {
            return .anyOf(schemas, description: description)
        }
        if let schemas = decodeSchemas(key: "allOf", from: raw) {
            return .allOf(schemas, description: description)
        }
        if let schemas = decodeSchemas(key: "oneOf", from: raw) {
            return .oneOf(schemas, description: description)
        }

        if let constValue = raw["const"] {
            return .constant(constValue, description: description)
        }

        if let enumValues = raw["enum"]?.arrayValue, !enumValues.isEmpty {
            return .enumeration(enumValues, description: description)
        }

        if let typeArray = raw["type"]?.arrayValue {
            let primitive = typeArray.compactMap { $0.stringValue }.compactMap(PrimitiveType.init(rawValue:) )
            if !primitive.isEmpty {
                return .union(primitive, description: description)
            }
        }

        if raw["type"] == nil, raw["properties"]?.dictionaryValue != nil {
            return parseObject(from: raw, description: description)
        }

        if let typeName = raw["type"]?.stringValue {
            switch typeName {
            case "null":
                return .null(description: description)
            case "boolean":
                return .boolean(description: description)
            case "string":
                return .string(
                    minLength: raw["minLength"]?.intValue,
                    maxLength: raw["maxLength"]?.intValue,
                    pattern: raw["pattern"]?.stringValue,
                    format: raw["format"]?.stringValue,
                    description: description
                )
            case "number":
                return .number(
                    multipleOf: raw["multipleOf"]?.doubleValue,
                    minimum: raw["minimum"]?.doubleValue,
                    exclusiveMinimum: raw["exclusiveMinimum"]?.doubleValue,
                    maximum: raw["maximum"]?.doubleValue,
                    exclusiveMaximum: raw["exclusiveMaximum"]?.doubleValue,
                    description: description
                )
            case "integer":
                return .integer(
                    multipleOf: raw["multipleOf"]?.int64Value,
                    minimum: raw["minimum"]?.int64Value,
                    exclusiveMinimum: raw["exclusiveMinimum"]?.int64Value,
                    maximum: raw["maximum"]?.int64Value,
                    exclusiveMaximum: raw["exclusiveMaximum"]?.int64Value,
                    description: description
                )
            case "array":
                if let items = raw["items"]?.dictionaryValue {
                    return .array(
                        items: JSONSchema.parse(raw: items),
                        minItems: raw["minItems"]?.intValue,
                        maxItems: raw["maxItems"]?.intValue,
                        description: description
                    )
                }
            case "object":
                return parseObject(from: raw, description: description)
            default:
                break
            }
        }

        if raw["properties"]?.dictionaryValue != nil {
            return parseObject(from: raw, description: description)
        }

        return .raw(raw)
    }

    private static func parseDefinitions(_ dictionary: [String: AnyCodable]) -> [String: JSONSchema] {
        var definitions: [String: JSONSchema] = [:]
        for (key, value) in dictionary {
            guard let schemaDictionary = value.dictionaryValue else {
                continue
            }
            definitions[key] = JSONSchema.parse(raw: schemaDictionary)
        }
        return definitions
    }

    private static func parseObject(from raw: [String: AnyCodable], description: String?) -> JSONSchema {
        let propertiesDictionary = raw["properties"]?.dictionaryValue ?? [:]
        var properties: [String: JSONSchema] = [:]
        for (key, value) in propertiesDictionary {
            guard let schemaDictionary = value.dictionaryValue else {
                continue
            }
            properties[key] = JSONSchema.parse(raw: schemaDictionary)
        }

        var patternProperties: [String: JSONSchema]?
        if let patternDictionary = raw["patternProperties"]?.dictionaryValue, !patternDictionary.isEmpty {
            var parsed: [String: JSONSchema] = [:]
            for (pattern, value) in patternDictionary {
                guard let schemaDictionary = value.dictionaryValue else {
                    continue
                }
                parsed[pattern] = JSONSchema.parse(raw: schemaDictionary)
            }
            patternProperties = parsed.isEmpty ? nil : parsed
        }

        let required = Set(raw["required"]?.arrayValue?.compactMap { $0.stringValue } ?? [])
        let additional: AdditionalProperties
        if let bool = raw["additionalProperties"]?.boolValue {
            additional = .boolean(bool)
        } else if let dictionary = raw["additionalProperties"]?.dictionaryValue {
            additional = .schema(JSONSchema.parse(raw: dictionary))
        } else {
            additional = .boolean(true)
        }

        return .object(
            properties: properties,
            patternProperties: patternProperties,
            required: required,
            additionalProperties: additional,
            description: description
        )
    }

    private static func decodeSchemas(key: String, from raw: [String: AnyCodable]) -> [JSONSchema]? {
        guard let array = raw[key]?.arrayValue else {
            return nil
        }
        let schemas = array.compactMap { element -> JSONSchema? in
            guard let dictionary = element.dictionaryValue else {
                return nil
            }
            return JSONSchema.parse(raw: dictionary)
        }
        return schemas.isEmpty ? nil : schemas
    }

    private func dictionaryRepresentation() -> [String: Any] {
        switch self {
        case .document(let root, let definitions):
            var result = root.dictionaryRepresentation()
            if !definitions.isEmpty {
                var encoded: [String: Any] = [:]
                for (key, schema) in definitions {
                    encoded[key] = schema.dictionaryRepresentation()
                }
                result["$defs"] = encoded
            }
            return result
        case .null(let description):
            return base(type: "null", description: description)
        case .boolean(let description):
            return base(type: "boolean", description: description)
        case .string(let minLength, let maxLength, let pattern, let format, let description):
            var result = base(type: "string", description: description)
            if let minLength { result["minLength"] = minLength }
            if let maxLength { result["maxLength"] = maxLength }
            if let pattern { result["pattern"] = pattern }
            if let format { result["format"] = format }
            return result
        case .number(let multipleOf, let minimum, let exclusiveMinimum, let maximum, let exclusiveMaximum, let description):
            var result = base(type: "number", description: description)
            if let multipleOf { result["multipleOf"] = multipleOf }
            if let minimum { result["minimum"] = minimum }
            if let exclusiveMinimum { result["exclusiveMinimum"] = exclusiveMinimum }
            if let maximum { result["maximum"] = maximum }
            if let exclusiveMaximum { result["exclusiveMaximum"] = exclusiveMaximum }
            return result
        case .integer(let multipleOf, let minimum, let exclusiveMinimum, let maximum, let exclusiveMaximum, let description):
            var result = base(type: "integer", description: description)
            if let multipleOf { result["multipleOf"] = multipleOf }
            if let minimum { result["minimum"] = minimum }
            if let exclusiveMinimum { result["exclusiveMinimum"] = exclusiveMinimum }
            if let maximum { result["maximum"] = maximum }
            if let exclusiveMaximum { result["exclusiveMaximum"] = exclusiveMaximum }
            return result
        case .array(let items, let minItems, let maxItems, let description):
            var result = base(type: "array", description: description)
            result["items"] = items.dictionaryRepresentation()
            if let minItems { result["minItems"] = minItems }
            if let maxItems { result["maxItems"] = maxItems }
            return result
        case .tuple(let prefixItems, let items, let minItems, let maxItems, let description):
            var result = base(type: "array", description: description)
            result["prefixItems"] = prefixItems.map { $0.dictionaryRepresentation() }
            if let items { result["items"] = items.dictionaryRepresentation() }
            if let minItems { result["minItems"] = minItems }
            if let maxItems { result["maxItems"] = maxItems }
            return result
        case .object(let properties, let patternProperties, let required, let additionalProperties, let description):
            var result = base(type: "object", description: description)
            if !properties.isEmpty {
                var encoded: [String: Any] = [:]
                for (key, schema) in properties {
                    encoded[key] = schema.dictionaryRepresentation()
                }
                result["properties"] = encoded
            }
            if let patternProperties, !patternProperties.isEmpty {
                var encoded: [String: Any] = [:]
                for (pattern, schema) in patternProperties {
                    encoded[pattern] = schema.dictionaryRepresentation()
                }
                result["patternProperties"] = encoded
            }
            if !required.isEmpty {
                result["required"] = required.sorted()
            }
            switch additionalProperties {
            case .boolean(let value):
                result["additionalProperties"] = value
            case .schema(let schema):
                result["additionalProperties"] = schema.dictionaryRepresentation()
            }
            return result
        case .enumeration(let values, let description):
            var result: [String: Any] = ["enum": values.map { $0.jsonObject }]
            if let primitive = JSONSchema.commonPrimitiveType(for: values) {
                result["type"] = primitive.rawValue
            }
            if let description { result["description"] = description }
            return result
        case .not(let schema, let description):
            var result: [String: Any] = ["not": schema.dictionaryRepresentation()]
            if let description { result["description"] = description }
            return result
        case .anyOf(let schemas, let description):
            return compose(key: "anyOf", schemas: schemas, description: description)
        case .allOf(let schemas, let description):
            return compose(key: "allOf", schemas: schemas, description: description)
        case .oneOf(let schemas, let description):
            return compose(key: "oneOf", schemas: schemas, description: description)
        case .conditional(let ifSchema, let thenSchema, let elseSchema, let description):
            var result: [String: Any] = ["if": ifSchema.dictionaryRepresentation()]
            if let thenSchema { result["then"] = thenSchema.dictionaryRepresentation() }
            if let elseSchema { result["else"] = elseSchema.dictionaryRepresentation() }
            if let description { result["description"] = description }
            return result
        case .union(let primitives, let description):
            var result: [String: Any] = ["type": primitives.map { $0.rawValue }]
            if let description { result["description"] = description }
            return result
        case .constant(let value, let description):
            var result: [String: Any] = ["const": value.jsonObject]
            if let primitive = JSONSchema.commonPrimitiveType(for: [value]) {
                result["type"] = primitive.rawValue
            }
            if let description { result["description"] = description }
            return result
        case .reference(let ref, let description):
            var result: [String: Any] = ["$ref": ref]
            if let description { result["description"] = description }
            return result
        case .raw(let raw):
            return raw.jsonObject()
        }
    }

    private func base(type: String, description: String?) -> [String: Any] {
        var result: [String: Any] = ["type": type]
        if let description {
            result["description"] = description
        }
        return result
    }

    private func compose(key: String, schemas: [JSONSchema], description: String?) -> [String: Any] {
        var result: [String: Any] = [
            key: schemas.map { $0.dictionaryRepresentation() }
        ]
        if let description {
            result["description"] = description
        }
        return result
    }

    private static func commonPrimitiveType(for values: [AnyCodable]) -> PrimitiveType? {
        guard let first = values.first else { return nil }
        func primitiveType(for value: Any) -> PrimitiveType? {
            switch value {
            case is String: return .string
            case is Int: return .integer
            case is Int64: return .integer
            case is Double, is Float: return .number
            case is Bool: return .boolean
            case is NSNumber: return .number
            case is [Any]: return .array
            case is [String: Any]: return .object
            case is NSNull: return .null
            default: return nil
            }
        }
        guard let primitive = primitiveType(for: first.jsonObject) else { return nil }
        return values.allSatisfy { primitiveType(for: $0.jsonObject) == primitive } ? primitive : nil
    }
}
