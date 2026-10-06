//
//  FluentModelMacro+Expansion.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension FluentModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: ModelDiagnostic.requiresClass))
            return []
        }

        let modelName = classDecl.name.text
        let schema: String
        switch schemaName(from: node, defaultingTo: modelName) {
        case let .value(resolvedSchema):
            schema = resolvedSchema
        case .invalid:
            context.diagnose(Diagnostic(node: Syntax(node), message: ModelDiagnostic.invalidSchema))
            return []
        }

        let properties = extractProperties(from: classDecl, context: context)
        let explicitMigrations = explicitMigrations(from: classDecl, properties: properties, context: context)
        let migrations = explicitMigrations.isEmpty
            ? [
                migrationDeclaration(
                    modelName: modelName,
                    schema: schema,
                    properties: properties,
                    name: .identifier(stableMigrationTypeIdentifier(modelName: modelName, version: 1))
                )
            ]
            : migrationDeclarations(modelName: modelName, schema: schema, migrations: explicitMigrations, context: context)

        return [
            DeclSyntax(stringLiteral: "static let schema = \"\(schema)\""),
            DeclSyntax(stringLiteral: "init() {}"),
            migrationsArrayDeclaration(names: migrations.map(\.name)),
        ] + migrations.map(\.declaration)
    }
}

extension FluentModelMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            return []
        }

        guard let variable = member.as(VariableDeclSyntax.self),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              binding.accessorBlock == nil,
              let namePattern = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation
        else {
            return []
        }

        if hasGeneratedFluentAttribute(variable.attributes) {
            return []
        }

        let attributes = attributeOptions(from: variable.attributes)
        if attributes.ignored {
            return []
        }

        let rawType = typeAnnotation.type.trimmedDescription
        let metadata: PropertyMetadata?
        if hasRelationshipAttribute(variable.attributes) {
            metadata = relationshipMetadata(
                from: variable.attributes,
                modelName: declaration.as(ClassDeclSyntax.self)!.name.text,
                propertyName: namePattern.identifier.text,
                rawType: rawType,
                context: context,
                emitDiagnostics: false
            )
        } else {
            metadata = scalarMetadata(
                propertyName: namePattern.identifier.text,
                rawType: rawType,
                attributes: attributes,
                context: context,
                node: Syntax(variable)
            )
        }

        guard let metadata,
              let attribute = fieldAttribute(for: metadata)
        else {
            return []
        }

        return [AttributeSyntax(stringLiteral: attribute)]
    }
}

extension FluentModelMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            return []
        }

        return try [
            ExtensionDeclSyntax("extension \(type): Model, @unchecked Sendable {}")
        ]
    }
}
