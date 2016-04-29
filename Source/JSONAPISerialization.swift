//
//  JSONAPISerialization.swift
//  KakapoExample
//
//  Created by Alex Manzella on 28/04/16.
//  Copyright © 2016 devlucky. All rights reserved.
//

import Foundation

/// A protocol to serialzie entities conforming to JSON API.
public protocol JSONAPISerializable {
    /**
     Builds the `data` field conforming to JSON API
     
     - parameter includeRelationships: Defines if it should include the `relationships` field
     - parameter includeAttributes:    Defines if it should include the `attributes` field
     
     - returns: Return an object representing the `data` field conforming to JSON API
     */
    func data(includeRelationships includeRelationships: Bool, includeAttributes: Bool) -> AnyObject?
}

/**
 *  A JSON API entity, conforming to this protocol will change the behavior of serialization, `CustomSerializable` cannot use this protocol because their custom serialization would be used instead.
 *  Relationships of an entity should also conform to this protocol, relationships are automatically recognized using the staic type of the property. For example an Array of `JSONAPIEntity` would be recognized as a relationship, also when empty, as soon as is static type at compile time is inferred correctly.
 
    ```swift
        struct User: JSONAPIEntity {
            let friends: [Friend] // correct if friend is JSONAPIEntity
            let enemies: [Any] // incorrect, Any is not JSONAPIEntity so this property is an attribute instead of a relationship
        }
    ```
 */
public protocol JSONAPIEntity: CustomSerializable, JSONAPISerializable {
    /// The type of this entity, by default the lowercase class name is used.
    var type: String { get }
    /// The id of the entity
    var id: String { get }
}

/**
 *  An object responsible to serialize a `JSONAPIEntity` or an array of `JSONAPIEntity` conforming to JSON API
 */
public struct JSONAPISerializer<T: JSONAPIEntity>: CustomSerializable {
    
    private let data: AnyObject
    
    /**
     Initialize a serializer with a single `JSONAPIEntity`
     
     - parameter object: A `JSONAPIEntities`
     
     - returns: A serializable object that serializes a `JSONAPIEntity` conforming to JSON API
     */
    public init(_ object: T) {
        data = object.serialize()
    }
    
    /**
     Initialize a serializer with an array of `JSONAPIEntity`
     
     - parameter objects: An array of `JSONAPIEntity`
     
     - returns: A serializable object that serializes an array of `JSONAPIEntity` conforming to JSON API
     */
    public init(_ objects: [T]) {
        data = objects.serialize()
    }
    
    // MARK: CustomSerializable

    public func customSerialize() -> AnyObject {
        return ["data": data]
    }
}

// MARK: - Extensions

extension Array: JSONAPISerializable {
    
    // MARK: JSONAPISerializable
    
    public func data(includeRelationships includeRelationships: Bool, includeAttributes: Bool) -> AnyObject? {
        return Element.self is JSONAPISerializable.Type ? flatMap { ($0 as? JSONAPISerializable)?.data(includeRelationships: includeRelationships, includeAttributes: includeAttributes) } : nil
    }
}

public extension JSONAPIEntity {
    
    // MARK: JSONAPIEntity

    var type: String {
        return String(self.dynamicType).lowercaseString
    }
    
    // MARK: CustomSerializable

    public func customSerialize() -> AnyObject {
        return data(includeRelationships: true, includeAttributes: true)!
    }
    
    // MARK: JSONAPISerializable

    public func data(includeRelationships includeRelationships: Bool, includeAttributes: Bool) -> AnyObject? {
        var data = [String: AnyObject]()
        
        data["id"] = id
        data["type"] = type
        
        let mirror = Mirror(reflecting: self)
        
        var attributes = [String: AnyObject]()
        var relationships = [String: AnyObject]()
        
        for child in mirror.children {
            if let label = child.label {
                if let value = child.value as? JSONAPISerializable, let data = value.data(includeRelationships: false, includeAttributes: false) {
                    relationships[label] =  ["data": data]
                } else if let value = child.value as? Serializable {
                    attributes[label] = value.serialize()
                } else if label != "id" {
                    assert(child.value is AnyObject)
                    attributes[label] = child.value as? AnyObject
                }
            }
        }
        
        if includeAttributes && attributes.count > 0 {
            data["attributes"] = attributes
        }
        
        if includeRelationships && relationships.count > 0 {
            data["relationships"] = relationships
        }

        return data
    }
}
