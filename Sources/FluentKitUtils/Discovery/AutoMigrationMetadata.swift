//
//  AutoMigrationMetadata.swift
//  fluentkit-utils
//
//  Created by Codex on 28/05/2026
//

public struct MigrationReference: Sendable, Hashable {
    public let modelName: String
    public let key: String

    public init(modelName: String, key: String) {
        self.modelName = modelName
        self.key = key
    }
}

public struct AutoMigrationMetadata: Sendable {
    public let modelName: String
    public let version: Int
    public let providedReferences: [MigrationReference]
    public let requiredReferences: [MigrationReference]

    public init(
        modelName: String,
        version: Int,
        providedReferences: [MigrationReference],
        requiredReferences: [MigrationReference]
    ) {
        self.modelName = modelName
        self.version = version
        self.providedReferences = providedReferences
        self.requiredReferences = requiredReferences
    }
}

