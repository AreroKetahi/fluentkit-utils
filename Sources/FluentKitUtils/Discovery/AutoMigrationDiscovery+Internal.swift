//
//  AutoMigrationDiscovery+Internal.swift
//  fluentkit-utils
//
//  Created by Codex on 28/05/2026
//

import FluentKit

public struct _MigrationDescriptor {
    public let modelName: String
    public let version: Int
    public let makeMigration: @Sendable () -> any FluentKit.Migration
    public let makeMetadata: @Sendable () -> AutoMigrationMetadata

    public init(
        modelName: String,
        version: Int,
        makeMigration: @Sendable @escaping () -> any FluentKit.Migration,
        makeMetadata: @Sendable @escaping () -> AutoMigrationMetadata
    ) {
        self.modelName = modelName
        self.version = version
        self.makeMigration = makeMigration
        self.makeMetadata = makeMetadata
    }
}

public typealias _MigrationRegisterAccessor = @convention(c) (
    _ outValue: UnsafeMutableRawPointer,
    _ type: UnsafeRawPointer,
    _ hint: UnsafeRawPointer?,
    _ reserved: UInt
) -> CBool

public typealias _MigrationRegisterRecord = (
    kind: UInt32,
    version: UInt32,
    accessor: _MigrationRegisterAccessor,
    context: UInt,
    reserved: UInt
)
