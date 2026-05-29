//
//  FluentModelMacro+SyntaxHelpers.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftSyntax
import Foundation

extension FluentModelMacro {
    static func attributeOptions(from attributes: AttributeListSyntax) -> AttributeOptions {
        var options = AttributeOptions()

        for attribute in attributes.compactMap({ $0.as(AttributeSyntax.self) }) where attributeName(of: attribute) == "Attribute" {
            guard case let .argumentList(arguments) = attribute.arguments else {
                continue
            }

            for argument in arguments {
                if let member = argument.expression.as(MemberAccessExprSyntax.self) {
                    switch member.declName.baseName.text {
                    case "unique":
                        options.unique = true
                    case "ignore":
                        options.ignored = true
                    default:
                        break
                    }
                }

                if let call = argument.expression.as(FunctionCallExprSyntax.self),
                   let callee = call.calledExpression.as(MemberAccessExprSyntax.self) {
                    switch callee.declName.baseName.text {
                    case "key":
                        if let first = call.arguments.first?.expression {
                            options.key = stringLiteralValue(from: first)
                        }
                    case "timestamp":
                        if let first = call.arguments.first?.expression,
                           let member = first.as(MemberAccessExprSyntax.self) {
                            options.timestamp = TimestampKind(rawValue: member.declName.baseName.text)
                        }
                    default:
                        break
                    }
                }
            }
        }

        return options
    }

    static func hasRelationshipAttribute(_ attributes: AttributeListSyntax) -> Bool {
        attributes.compactMap { $0.as(AttributeSyntax.self) }.contains {
            attributeName(of: $0) == "Relationship"
        }
    }

    static func hasAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
        attributes.compactMap { $0.as(AttributeSyntax.self) }.contains {
            attributeName(of: $0) == name
        }
    }

    static func hasGeneratedFluentAttribute(_ attributes: AttributeListSyntax) -> Bool {
        attributes.compactMap { $0.as(AttributeSyntax.self) }.contains {
            guard let name = attributeName(of: $0) else { return false }
            return fluentWrapperAttributes.contains(name)
        }
    }

    static func attributeName(of attribute: AttributeSyntax) -> String? {
        if let identifierType = attribute.attributeName.as(IdentifierTypeSyntax.self) {
            return identifierType.name.text
        }

        return attribute.attributeName.as(MemberTypeSyntax.self)?.name.text
    }

    static func stringLiteralValue(from expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self),
              literal.segments.count == 1,
              case let .stringSegment(segment)? = literal.segments.first
        else {
            return nil
        }

        return segment.content.text
    }

    static func integerLiteralValue(from expression: ExprSyntax) -> Int? {
        guard let literal = expression.as(IntegerLiteralExprSyntax.self) else {
            return nil
        }

        return Int(literal.literal.text.replacingOccurrences(of: "_", with: ""))
    }

    static func propertyName(fromKeyPathExpression expression: ExprSyntax) -> String? {
        let text = expression.trimmedDescription
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")

        guard text.hasPrefix("\\"),
              let lastComponent = text.split(separator: ".").last
        else {
            return nil
        }

        let rawName = lastComponent.trimmingCharacters(in: CharacterSet(charactersIn: "$"))
        guard rawName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            return nil
        }

        return rawName
    }

    static func optionalWrappedType(from type: String) -> String? {
        guard type.hasSuffix("?") else {
            return nil
        }

        return String(type.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func arrayElementType(from type: String) -> String? {
        guard type.hasPrefix("["),
              type.hasSuffix("]")
        else {
            return nil
        }

        return String(type.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedTypeName(_ type: String) -> String {
        type.split(separator: ".").last.map(String.init) ?? type
    }

    static func fluentSchemaType(for type: String) -> String? {
        switch normalizedTypeName(type) {
        case "String":
            return "DatabaseSchema.DataType.string"
        case "Int":
            return "DatabaseSchema.DataType.int"
        case "Double":
            return "DatabaseSchema.DataType.double"
        case "Float":
            return "DatabaseSchema.DataType.float"
        case "Bool":
            return "DatabaseSchema.DataType.bool"
        case "Date":
            return "DatabaseSchema.DataType.datetime"
        case "UUID":
            return "DatabaseSchema.DataType.uuid"
        case "Data":
            return "DatabaseSchema.DataType.data"
        default:
            return nil
        }
    }

    static func relationshipKind(from expression: ExprSyntax) -> RelationshipKind? {
        guard let member = expression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        return RelationshipKind(rawValue: member.declName.baseName.text)
    }

    static func inferredTimestamp(for propertyName: String, type: String, isOptional: Bool) -> TimestampKind? {
        guard normalizedTypeName(type) == "Date", isOptional else {
            return nil
        }

        switch propertyName {
        case "createdAt":
            return .create
        case "updatedAt":
            return .update
        case "deletedAt":
            return .delete
        default:
            return nil
        }
    }

    static func defaultKey(for propertyName: String) -> String {
        propertyName.enumerated().reduce(into: "") { result, item in
            let (index, character) = item
            if character.isUppercase {
                if index != 0 {
                    result.append("_")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
