//
//  FluentModelMacro+MigrationParsing.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension FluentModelMacro {
    static func explicitMigrations(
        from declaration: ClassDeclSyntax,
        properties: [PropertyMetadata],
        context: some MacroExpansionContext
    ) -> [MigrationMetadata] {
        let propertyLookup = Dictionary(uniqueKeysWithValues: properties.map { ($0.name, $0) })

        let parsedMigrations = declaration.memberBlock.members.compactMap { member -> ParsedMigration? in
            guard let macro = member.decl.as(MacroExpansionDeclSyntax.self),
                  macro.macroName.text == "Migration"
            else {
                return nil
            }

            guard let metadata = migrationMetadata(from: macro, propertyLookup: propertyLookup) else {
                return nil
            }

            return ParsedMigration(node: macro, metadata: metadata)
        }

        diagnoseMigrationVersionSequence(parsedMigrations, context: context)
        diagnoseMigrationEvolutionUsage(parsedMigrations, context: context)

        return parsedMigrations.map(\.metadata)
    }

    static func migrationMetadata(
        from macro: MacroExpansionDeclSyntax,
        propertyLookup: [String: PropertyMetadata]
    ) -> MigrationMetadata? {
        var version: Int?
        var payloadExpressions = [ExprSyntax]()

        for argument in macro.arguments {
            if argument.label?.text == "version" {
                version = integerLiteralValue(from: argument.expression)
            } else {
                payloadExpressions.append(argument.expression)
            }
        }

        guard let version else {
            return nil
        }

        let evolutions = payloadExpressions.compactMap {
            evolution(from: $0, propertyLookup: propertyLookup)
        }

        if evolutions.count == payloadExpressions.count, !evolutions.isEmpty {
            return MigrationMetadata(version: version, kind: .evolution(evolutions))
        }

        let initialProperties = payloadExpressions.compactMap {
            propertyName(fromKeyPathExpression: $0).flatMap { propertyLookup[$0] }
        }
        return MigrationMetadata(version: version, kind: .initial(initialProperties))
    }

    static func evolution(
        from expression: ExprSyntax,
        propertyLookup: [String: PropertyMetadata]
    ) -> Evolution? {
        guard let call = expression.as(FunctionCallExprSyntax.self),
              let callee = call.calledExpression.as(MemberAccessExprSyntax.self)
        else {
            return nil
        }

        let firstPropertyName = call.arguments.first.flatMap {
            propertyName(fromKeyPathExpression: $0.expression)
        }
        let firstProperty = firstPropertyName.flatMap { propertyLookup[$0] }

        switch callee.declName.baseName.text {
        case "add":
            return firstProperty.map(Evolution.add)
        case "delete":
            return firstProperty.map(Evolution.delete)
        case "rename":
            guard let property = firstProperty,
                  let oldKeyExpression = call.arguments.first(where: { $0.label?.text == "from" })?.expression,
                  let oldKey = stringLiteralValue(from: oldKeyExpression)
            else {
                return nil
            }
            return .rename(property, from: oldKey)
        default:
            return nil
        }
    }

    static func diagnoseMigrationVersionSequence(
        _ migrations: [ParsedMigration],
        context: some MacroExpansionContext
    ) {
        guard !migrations.isEmpty else {
            return
        }

        let sortedMigrations = migrations.sorted { lhs, rhs in
            lhs.metadata.version < rhs.metadata.version
        }

        guard sortedMigrations.first?.metadata.version == 1 else {
            if let first = sortedMigrations.first {
                context.diagnose(Diagnostic(
                    node: Syntax(first.node),
                    message: ModelDiagnostic.migrationVersionsMustStartAtOne
                ))
            }
            return
        }

        for (offset, migration) in sortedMigrations.enumerated() {
            let expectedVersion = offset + 1
            guard migration.metadata.version == expectedVersion else {
                context.diagnose(Diagnostic(
                    node: Syntax(migration.node),
                    message: ModelDiagnostic.migrationVersionsMustBeContinuous
                ))
                return
            }
        }
    }

    static func diagnoseMigrationEvolutionUsage(
        _ migrations: [ParsedMigration],
        context: some MacroExpansionContext
    ) {
        for migration in migrations where migration.metadata.version > 1 {
            guard case .evolution = migration.metadata.kind else {
                context.diagnose(Diagnostic(
                    node: Syntax(migration.node),
                    message: ModelDiagnostic.migrationVersionGreaterThanOneRequiresEvolution
                ))
                continue
            }
        }
    }
}
