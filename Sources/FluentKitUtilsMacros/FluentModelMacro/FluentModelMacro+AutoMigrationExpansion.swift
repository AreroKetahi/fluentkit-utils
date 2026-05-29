//
//  FluentModelMacro+AutoMigrationExpansion.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftSyntax
import SwiftSyntaxMacros

extension FluentModelMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard schemaName(from: node) != nil else {
            return []
        }

        guard let classDecl = declaration.as(ClassDeclSyntax.self),
              hasAttribute(named: "AutoMigratable", in: classDecl.attributes)
        else {
            return []
        }

        let modelName = classDecl.name.text
        let properties = extractProperties(from: classDecl, context: context)
        let explicitMigrations = explicitMigrations(from: classDecl, properties: properties, context: context)
        let migrations = explicitMigrations.isEmpty
            ? [MigrationMetadata(version: 1, kind: .initial(properties))]
            : explicitMigrations.sorted { $0.version < $1.version }
        let metadataEntries = autoMigrationMetadataEntries(
            modelName: modelName,
            migrations: migrations
        )

        return metadataEntries.flatMap { entry in
            autoMigrationRecordDeclarations(
                modelName: modelName,
                metadata: entry,
                context: context
            )
        }
    }

    static func autoMigrationRecordDeclarations(
        modelName: String,
        metadata: AutoMigrationMetadataEntry,
        context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let accessorName = context.makeUniqueName("FluentKitUtilsAutoMigration_accessor")
        let recordName = context.makeUniqueName("FluentKitUtilsAutoMigration_record")
        let providedReferences = arrayLiteral(metadata.providedReferences)
        let requiredReferences = arrayLiteral(metadata.requiredReferences)
        let migrationTypeName = stableMigrationTypeIdentifier(modelName: modelName, version: metadata.version)

        return [
            """
            @available(*, deprecated, message: "This property is an implementation detail of FluentKitUtils. Do not use it directly.")
            private nonisolated let \(accessorName): FluentKitUtils._MigrationRegisterAccessor = { outValue, type, _, _ in
                guard unsafe type.load(as: Any.Type.self) == FluentKitUtils._MigrationDescriptor.self else {
                    return false
                }

                unsafe outValue.initializeMemory(
                    as: FluentKitUtils._MigrationDescriptor.self,
                    to: FluentKitUtils._MigrationDescriptor(
                        modelName: \(literal: modelName),
                        version: \(raw: metadata.version),
                        makeMigration: {
                            \(raw: modelName).\(raw: migrationTypeName)()
                        },
                        makeMetadata: {
                            FluentKitUtils.AutoMigrationMetadata(
                                modelName: \(literal: modelName),
                                version: \(raw: metadata.version),
                                providedReferences: \(raw: providedReferences),
                                requiredReferences: \(raw: requiredReferences)
                            )
                        }
                    )
                )

                return true
            }
            """,
            """
            #if objectFormat(MachO)
            @section("__DATA_CONST,__swift5_fkmg")
            #elseif objectFormat(ELF)
            @section("swift5_fkmg")
            #elseif objectFormat(COFF)
            @section(".sw5fkmg")
            #endif
            @used
            @available(*, deprecated, message: "This property is an implementation detail of FluentKitUtils. Do not use it directly.")
            private let \(recordName): FluentKitUtils._MigrationRegisterRecord = (
                0x666B_6D67,
                1,
                { unsafe \(accessorName)($0, $1, $2, $3) },
                0,
                0
            )
            """
        ]
    }
}
