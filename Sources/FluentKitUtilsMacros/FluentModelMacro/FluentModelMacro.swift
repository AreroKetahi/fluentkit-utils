//
//  FluentModelMacro.swift
//  fluentkit-utils
//
//  Created by Arkivili Collindort on 01/05/2026
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct FluentModelMacro {
    enum DiagnosticDomain {
        static let domain = "VaporKit.FluentModelMacro"
    }

    enum ModelDiagnostic: String, DiagnosticMessage {
        case requiresClass = "@FluentModel can only be attached to a class declaration."
        case requiresExplicitSchema = "@FluentModel requires a static string schema name."
        case requiresSingleBinding = "@FluentModel only supports stored properties with a single binding."
        case requiresExplicitType = "@FluentModel properties must declare an explicit type."
        case unsupportedProperty = "@FluentModel only supports stored properties."
        case unsupportedScalarType = "@FluentModel could not map this property type to a Fluent field."
        case relationshipMissingKind = "@Relationship requires a relationship kind."
        case relationshipMissingKeyPath = "@Relationship(.child, ...) requires a relationship key path."
        case relationshipUnexpectedKeyPath = "@Relationship(.parent) does not accept a relationship key path."
        case relationshipInvalidParentType = "@Relationship(.parent) requires a non-collection model type."
        case relationshipInvalidChildType = "@Relationship(.child, ...) requires an array property type."
        case migrationVersionsMustStartAtOne = "#Migration versions must start at 1."
        case migrationVersionsMustBeContinuous = "#Migration versions must be continuous."
        case migrationVersionGreaterThanOneRequiresEvolution = "#Migration with version greater than 1 must use ModelEvolution values."

        var message: String { rawValue }
        var diagnosticID: MessageID { .init(domain: DiagnosticDomain.domain, id: rawValue) }
        var severity: SwiftDiagnostics.DiagnosticSeverity { .error }
    }

    enum TimestampKind: String, Equatable {
        case create
        case update
        case delete

        var fluentExpression: String { ".\(rawValue)" }
    }

    enum RelationshipKind: String {
        case parent
        case child
    }

    enum FieldKind: Equatable {
        case id
        case field
        case timestamp(TimestampKind)
        case parent
        case child
    }

    struct AttributeOptions {
        var key: String?
        var unique = false
        var timestamp: TimestampKind?
        var ignored = false
    }

    struct PropertyMetadata {
        let name: String
        let type: String
        let kind: FieldKind
        let key: String
        let isUnique: Bool
        let scalarType: String?
        let relatedType: String?
        let relatedKeyPath: String?
        let isOptional: Bool
    }

    struct MigrationMetadata {
        enum Kind {
            case initial([PropertyMetadata])
            case evolution([Evolution])
        }

        let version: Int
        let kind: Kind
    }

    struct ParsedMigration {
        let node: MacroExpansionDeclSyntax
        let metadata: MigrationMetadata
    }

    struct GeneratedMigration {
        let name: TokenSyntax
        let declaration: DeclSyntax
    }

    enum Evolution {
        case add(PropertyMetadata)
        case rename(PropertyMetadata, from: String)
        case delete(PropertyMetadata)
    }

    struct AutoMigrationMetadataEntry {
        let version: Int
        let providedReferences: [String]
        let requiredReferences: [String]
    }

    static let fluentWrapperAttributes: Set<String> = [
        "ID", "Field", "OptionalField", "Timestamp", "Parent", "OptionalParent", "Children",
    ]
}
