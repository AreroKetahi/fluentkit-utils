//
//  FluentModelMacro+MigrationCodegen.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension FluentModelMacro {
    static func migrationDeclaration(
        modelName: String,
        schema: String,
        properties: [PropertyMetadata],
        name: TokenSyntax
    ) -> GeneratedMigration {
        let schemaLines = (
            properties.compactMap(migrationFieldLine(for:)) +
            properties.compactMap(migrationUniqueLine(for:))
        ).joined(separator: "\n")

        let declaration = migrationStructDeclaration(
            name: name,
            migrationName: stableMigrationName(modelName: modelName, version: 1),
            prepare: """
            var schemaBuilder = database.schema("\(schema)")
            schemaBuilder = schemaBuilder.id()
            \(schemaLines)
            try await schemaBuilder.create()
            """,
            revert: """
            try await database.schema("\(schema)").delete()
            """
        )

        return GeneratedMigration(name: name, declaration: declaration)
    }

    static func migrationDeclarations(
        modelName: String,
        schema: String,
        migrations: [MigrationMetadata],
        context: some MacroExpansionContext
    ) -> [GeneratedMigration] {
        migrations
            .sorted { $0.version < $1.version }
            .map {
                migrationDeclaration(
                    modelName: modelName,
                    schema: schema,
                    migration: $0,
                    name: .identifier(stableMigrationTypeIdentifier(modelName: modelName, version: $0.version))
                )
            }
    }

    static func migrationDeclaration(
        modelName: String,
        schema: String,
        migration: MigrationMetadata,
        name: TokenSyntax
    ) -> GeneratedMigration {
        let declaration: DeclSyntax
        switch migration.kind {
        case let .initial(properties):
            let schemaLines = (
                properties.compactMap(migrationFieldLine(for:)) +
                properties.compactMap(migrationUniqueLine(for:))
            ).joined(separator: "\n")

            declaration = migrationStructDeclaration(
                name: name,
                migrationName: stableMigrationName(modelName: modelName, version: migration.version),
                prepare: """
                var schemaBuilder = database.schema("\(schema)")
                schemaBuilder = schemaBuilder.id()
                \(schemaLines)
                try await schemaBuilder.create()
                """,
                revert: """
                try await database.schema("\(schema)").delete()
                """
            )
        case let .evolution(evolutions):
            let prepareLines = evolutions.flatMap(migrationPrepareLines(for:)).joined(separator: "\n")
            let revertLines = evolutions.reversed().flatMap(migrationRevertLines(for:)).joined(separator: "\n")

            declaration = migrationStructDeclaration(
                name: name,
                migrationName: stableMigrationName(modelName: modelName, version: migration.version),
                prepare: """
                var schemaBuilder = database.schema("\(schema)")
                \(prepareLines)
                try await schemaBuilder.update()
                """,
                revert: """
                var schemaBuilder = database.schema("\(schema)")
                \(revertLines)
                try await schemaBuilder.update()
                """
            )
        }

        return GeneratedMigration(name: name, declaration: declaration)
    }

    static func stableMigrationName(modelName: String, version: Int) -> String {
        let migrationName = "MigrationV\(version)"
        return "$s\(modelName.count)\(modelName)\(migrationName.count)\(migrationName)V"
    }

    static func stableMigrationTypeIdentifier(modelName: String, version: Int) -> String {
        stableMigrationName(modelName: modelName, version: version)
    }

    static func migrationStructDeclaration(
        name: TokenSyntax,
        migrationName: String,
        prepare: String,
        revert: String
    ) -> DeclSyntax {
        DeclSyntax(StructDeclSyntax(
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: name,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: TypeSyntax("AsyncMigration"))
            }
        ) {
            DeclSyntax(stringLiteral: """
            var name: String {
                "\(migrationName)"
            }
            """)
            DeclSyntax(stringLiteral: """
            func prepare(on database: any Database) async throws {
            \(prepare)
            }
            """)
            DeclSyntax(stringLiteral: """
            func revert(on database: any Database) async throws {
            \(revert)
            }
            """)
        })
    }

    static func migrationsArrayDeclaration(names: [TokenSyntax]) -> DeclSyntax {
        let migrations = names
            .map { "\($0.text)()" }
            .joined(separator: ", ")

        return DeclSyntax(VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))],
            bindingSpecifier: .keyword(.let, trailingTrivia: .space)
        ) {
            PatternBindingSyntax(
                pattern: PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("$migrations"))),
                typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax("[any FluentKit.Migration]")),
                initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: "[\(migrations)]"))
            )
        })
    }

    static func fieldAttribute(for property: PropertyMetadata) -> String? {
        switch property.kind {
        case .id:
            return "@ID(key: .id)"
        case .field:
            let wrapper = property.isOptional ? "OptionalField" : "Field"
            return "@\(wrapper)(key: \"\(property.key)\")"
        case let .timestamp(kind):
            return "@Timestamp(key: \"\(property.key)\", on: \(kind.fluentExpression))"
        case .parent:
            let wrapper = property.isOptional ? "OptionalParent" : "Parent"
            return "@\(wrapper)(key: \"\(property.key)\")"
        case .child:
            let wrapper = property.isOptional ? "OptionalChild" : "Children"
            return "@\(wrapper)(for: \(property.relatedKeyPath!))"
        case .siblings:
            return "@Siblings(\(property.relatedKeyPath!))"
        }
    }

    static func migrationFieldLine(for property: PropertyMetadata) -> String? {
        switch property.kind {
        case .id, .child, .siblings:
            return nil
        case .parent:
            let required = property.isOptional ? "" : ", DatabaseSchema.FieldConstraint.required"
            return "schemaBuilder = schemaBuilder.field(\"\(property.key)\", DatabaseSchema.DataType.uuid\(required))"
        case .field:
            guard let schemaType = fluentSchemaType(for: property.scalarType!) else {
                return nil
            }
            let required = property.isOptional ? "" : ", DatabaseSchema.FieldConstraint.required"
            return "schemaBuilder = schemaBuilder.field(\"\(property.key)\", \(schemaType)\(required))"
        case .timestamp:
            return "schemaBuilder = schemaBuilder.field(\"\(property.key)\", DatabaseSchema.DataType.datetime)"
        }
    }

    static func migrationUniqueLine(for property: PropertyMetadata) -> String? {
        guard property.kind == .field, property.isUnique else {
            return nil
        }

        return "schemaBuilder = schemaBuilder.unique(on: \"\(property.key)\")"
    }

    static func migrationDeleteUniqueLine(for property: PropertyMetadata) -> String? {
        guard property.kind == .field, property.isUnique else {
            return nil
        }

        return "schemaBuilder = schemaBuilder.deleteUnique(on: \"\(property.key)\")"
    }

    static func migrationPrepareLines(for evolution: Evolution) -> [String] {
        switch evolution {
        case let .add(property):
            return [migrationFieldLine(for: property), migrationUniqueLine(for: property)].compactMap { $0 }
        case let .rename(property, oldKey):
            var lines = [String]()
            if let deleteUnique = migrationDeleteUniqueLine(for: property, overridingKey: oldKey) {
                lines.append(deleteUnique)
            }
            lines.append("schemaBuilder = schemaBuilder.deleteField(\"\(oldKey)\")")
            lines.append(contentsOf: migrationFieldLines(for: property))
            return lines
        case let .delete(property):
            return [migrationDeleteUniqueLine(for: property), "schemaBuilder = schemaBuilder.deleteField(\"\(property.key)\")"].compactMap { $0 }
        }
    }

    static func migrationRevertLines(for evolution: Evolution) -> [String] {
        switch evolution {
        case let .add(property):
            return [migrationDeleteUniqueLine(for: property), "schemaBuilder = schemaBuilder.deleteField(\"\(property.key)\")"].compactMap { $0 }
        case let .rename(property, oldKey):
            var lines = [String]()
            if let deleteUnique = migrationDeleteUniqueLine(for: property) {
                lines.append(deleteUnique)
            }
            lines.append("schemaBuilder = schemaBuilder.deleteField(\"\(property.key)\")")
            lines.append(contentsOf: migrationFieldLines(for: property, overridingKey: oldKey))
            return lines
        case let .delete(property):
            return [migrationFieldLine(for: property), migrationUniqueLine(for: property)].compactMap { $0 }
        }
    }

    static func migrationFieldLines(for property: PropertyMetadata, overridingKey key: String) -> [String] {
        let fieldLine: String?
        switch property.kind {
        case .id, .child, .siblings:
            fieldLine = nil
        case .parent:
            let required = property.isOptional ? "" : ", DatabaseSchema.FieldConstraint.required"
            fieldLine = "schemaBuilder = schemaBuilder.field(\"\(key)\", DatabaseSchema.DataType.uuid\(required))"
        case .field:
            guard let schemaType = fluentSchemaType(for: property.scalarType!) else {
                return []
            }
            let required = property.isOptional ? "" : ", DatabaseSchema.FieldConstraint.required"
            fieldLine = "schemaBuilder = schemaBuilder.field(\"\(key)\", \(schemaType)\(required))"
        case .timestamp:
            fieldLine = "schemaBuilder = schemaBuilder.field(\"\(key)\", DatabaseSchema.DataType.datetime)"
        }

        var lines = [fieldLine].compactMap { $0 }
        if property.kind == .field, property.isUnique {
            lines.append("schemaBuilder = schemaBuilder.unique(on: \"\(key)\")")
        }
        return lines
    }

    static func migrationFieldLines(for property: PropertyMetadata) -> [String] {
        migrationFieldLines(for: property, overridingKey: property.key)
    }

    static func migrationDeleteUniqueLine(for property: PropertyMetadata, overridingKey key: String) -> String? {
        guard property.kind == .field, property.isUnique else {
            return nil
        }

        return "schemaBuilder = schemaBuilder.deleteUnique(on: \"\(key)\")"
    }
}
