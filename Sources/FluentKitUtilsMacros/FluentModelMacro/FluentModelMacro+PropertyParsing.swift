//
//  FluentModelMacro+PropertyParsing.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension FluentModelMacro {
    static func schemaName(from node: AttributeSyntax, defaultingTo modelName: String) -> SchemaResolution {
        let defaultSchema = pluralizedSchemaName(for: modelName)

        guard case let .argumentList(arguments) = node.arguments else {
            return .value(defaultSchema)
        }

        guard let firstArgument = arguments.first else {
            return .value(defaultSchema)
        }

        if firstArgument.expression.is(NilLiteralExprSyntax.self) {
            return .value(defaultSchema)
        }

        guard let schema = stringLiteralValue(from: firstArgument.expression) else {
            return .invalid
        }

        return .value(schema)
    }

    static func extractProperties(
        from declaration: ClassDeclSyntax,
        context: some MacroExpansionContext
    ) -> [PropertyMetadata] {
        declaration.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                return nil
            }

            guard variable.bindings.count == 1, let binding = variable.bindings.first else {
                context.diagnose(Diagnostic(node: Syntax(variable), message: ModelDiagnostic.requiresSingleBinding))
                return nil
            }

            guard binding.accessorBlock == nil else {
                context.diagnose(Diagnostic(node: Syntax(variable), message: ModelDiagnostic.unsupportedProperty))
                return nil
            }

            guard let namePattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                context.diagnose(Diagnostic(node: Syntax(variable), message: ModelDiagnostic.unsupportedProperty))
                return nil
            }

            guard let typeAnnotation = binding.typeAnnotation else {
                context.diagnose(Diagnostic(node: Syntax(variable), message: ModelDiagnostic.requiresExplicitType))
                return nil
            }

            let attributes = attributeOptions(from: variable.attributes)
            if attributes.ignored {
                return nil
            }

            let rawType = typeAnnotation.type.trimmedDescription
            if hasRelationshipAttribute(variable.attributes) {
                return relationshipMetadata(
                    from: variable.attributes,
                    modelName: declaration.name.text,
                    propertyName: namePattern.identifier.text,
                    rawType: rawType,
                    context: context
                )
            }

            return scalarMetadata(
                propertyName: namePattern.identifier.text,
                rawType: rawType,
                attributes: attributes,
                context: context,
                node: Syntax(variable)
            )
        }
    }

    static func scalarMetadata(
        propertyName: String,
        rawType: String,
        attributes: AttributeOptions,
        context: some MacroExpansionContext,
        node: Syntax
    ) -> PropertyMetadata? {
        let isOptional = optionalWrappedType(from: rawType) != nil
        let baseType = optionalWrappedType(from: rawType) ?? rawType
        let key = attributes.key ?? defaultKey(for: propertyName)

        if propertyName == "id", normalizedTypeName(baseType) == "UUID", isOptional {
            return PropertyMetadata(
                name: propertyName,
                type: rawType,
                kind: .id,
                key: key,
                isUnique: false,
                scalarType: "UUID",
                relatedType: nil,
                relatedKeyPath: nil,
                isOptional: true
            )
        }

        if let timestamp = attributes.timestamp ?? inferredTimestamp(for: propertyName, type: baseType, isOptional: isOptional) {
            return PropertyMetadata(
                name: propertyName,
                type: rawType,
                kind: .timestamp(timestamp),
                key: key,
                isUnique: false,
                scalarType: "Date",
                relatedType: nil,
                relatedKeyPath: nil,
                isOptional: true
            )
        }

        guard fluentSchemaType(for: baseType) != nil else {
            context.diagnose(Diagnostic(node: node, message: ModelDiagnostic.unsupportedScalarType))
            return nil
        }

        return PropertyMetadata(
            name: propertyName,
            type: rawType,
            kind: .field,
            key: key,
            isUnique: attributes.unique,
            scalarType: baseType,
            relatedType: nil,
            relatedKeyPath: nil,
            isOptional: isOptional
        )
    }

    static func relationshipMetadata(
        from attributes: AttributeListSyntax,
        modelName: String,
        propertyName: String,
        rawType: String,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool = true
    ) -> PropertyMetadata? {
        guard let attribute = attributes.compactMap({ $0.as(AttributeSyntax.self) }).first(where: {
            attributeName(of: $0) == "Relationship"
        }) else {
            return nil
        }

        guard case let .argumentList(arguments) = attribute.arguments,
              let kindExpression = arguments.first?.expression,
              let kind = relationshipKind(from: kindExpression)
        else {
            if emitDiagnostics {
                context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipMissingKind))
            }
            return nil
        }

        switch kind {
        case .parent:
            guard arguments.count <= 2 else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipUnexpectedKeyPath))
                }
                return nil
            }

            let isOptional = optionalWrappedType(from: rawType) != nil
            let baseType = optionalWrappedType(from: rawType) ?? rawType
            guard arrayElementType(from: baseType) == nil else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipInvalidParentType))
                }
                return nil
            }

            return PropertyMetadata(
                name: propertyName,
                type: rawType,
                kind: .parent,
                key: defaultKey(for: propertyName) + "_id",
                isUnique: false,
                scalarType: "UUID",
                relatedType: baseType,
                relatedKeyPath: nil,
                isOptional: isOptional
            )
        case .child:
            guard let targetType = arguments.dropFirst().first.flatMap({ modelTypeName(from: $0.expression) }) else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipMissingKeyPath))
                }
                return nil
            }

            let isOptionalChild = optionalWrappedType(from: rawType) != nil
            guard arrayElementType(from: rawType) != nil || isOptionalChild else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipInvalidChildType))
                }
                return nil
            }

            return PropertyMetadata(
                name: propertyName,
                type: rawType,
                kind: .child,
                key: defaultKey(for: propertyName),
                isUnique: false,
                scalarType: nil,
                relatedType: targetType,
                relatedKeyPath: "\\\(targetType).$\(defaultModelPropertyName(for: modelName))",
                isOptional: isOptionalChild
            )
        case .siblings:
            guard let targetType = arguments.dropFirst().first.flatMap({ modelTypeName(from: $0.expression) }) else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipMissingKeyPath))
                }
                return nil
            }

            guard arrayElementType(from: rawType) != nil else {
                if emitDiagnostics {
                    context.diagnose(Diagnostic(node: Syntax(attribute), message: ModelDiagnostic.relationshipInvalidChildType))
                }
                return nil
            }

            let models = [modelName, targetType].sorted()
            let intermediate = "$_FluentSibling_\(models[0])_\(models[1])"
            let from = defaultModelPropertyName(for: modelName)
            let to = defaultModelPropertyName(for: targetType)

            return PropertyMetadata(
                name: propertyName,
                type: rawType,
                kind: .siblings,
                key: defaultKey(for: propertyName),
                isUnique: false,
                scalarType: nil,
                relatedType: targetType,
                relatedKeyPath: "through: \(intermediate).self, from: \\\(intermediate).$\(from), to: \\\(intermediate).$\(to)",
                isOptional: false
            )
        }
}
}
