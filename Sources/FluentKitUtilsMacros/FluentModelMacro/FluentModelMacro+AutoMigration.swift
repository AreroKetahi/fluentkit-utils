//
//  FluentModelMacro+AutoMigration.swift
//  fluentkit-utils
//
//  Split from FluentModelMacro.swift.
//

import SwiftSyntax

extension FluentModelMacro {
    static func autoMigrationMetadataEntries(
        modelName: String,
        migrations: [MigrationMetadata]
    ) -> [AutoMigrationMetadataEntry] {
        var state = [String: PropertyMetadata]()

        return migrations.sorted { $0.version < $1.version }.map { migration in
            let changedProperties: [PropertyMetadata]

            switch migration.kind {
            case let .initial(properties):
                state = Dictionary(uniqueKeysWithValues: properties.map { ($0.name, $0) })
                changedProperties = properties
            case let .evolution(evolutions):
                changedProperties = evolutions.compactMap { evolution in
                    switch evolution {
                    case let .add(property):
                        state[property.name] = property
                        return property
                    case let .rename(property, _):
                        state[property.name] = property
                        return property
                    case let .delete(property):
                        state[property.name] = nil
                        return nil
                    }
                }
            }

            let providedReferences = state.values
                .filter { $0.kind == .id }
                .sorted { $0.key < $1.key }
                .map { migrationReference(modelName: modelName, key: $0.key) }

            let requiredReferences = changedProperties
                .compactMap(requiredReference)
                .sorted()

            return AutoMigrationMetadataEntry(
                version: migration.version,
                providedReferences: providedReferences,
                requiredReferences: requiredReferences
            )
        }
    }

    static func requiredReference(for property: PropertyMetadata) -> String? {
        guard property.kind == .parent,
              let relatedType = property.relatedType
        else {
            return nil
        }

        return migrationReference(modelName: relatedType, key: "id")
    }

    static func migrationReference(modelName: String, key: String) -> String {
        #"FluentKitUtils.MigrationReference(modelName: "\#(modelName)", key: "\#(key)")"#
    }

    static func arrayLiteral(_ expressions: [String]) -> String {
        guard !expressions.isEmpty else {
            return "[]"
        }

        return "[\(expressions.joined(separator: ", "))]"
    }
}
