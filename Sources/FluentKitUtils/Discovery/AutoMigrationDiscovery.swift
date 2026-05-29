//
//  AutoMigrationDiscovery.swift
//  fluentkit-utils
//
//  Created by Codex on 28/05/2026
//

public enum _MigrationDiscovery {
    public static let kind: UInt32 = 0x666B_6D67 // fkmg -> FluentKit MiGration
    public static let version: UInt32 = 1

    public static func _discover() -> [_MigrationDescriptor] {
        unsafe _findMigrationRecordSections().flatMap { buffer in
            unsafe buffer.withMemoryRebound(to: _MigrationRegisterRecord.self) { records in
                unsafe records.compactMap(__loadDescriptor)
            }
        }
    }

    private static func __loadDescriptor(
        _ record: _MigrationRegisterRecord
    ) -> _MigrationDescriptor? {
        guard unsafe record.kind == kind else { return nil }
        guard unsafe record.version == version else { return nil }
        let accessor = unsafe record.accessor

        return unsafe withUnsafeTemporaryAllocation(of: _MigrationDescriptor.self, capacity: 1) { buffer in
            let initialized = unsafe withUnsafePointer(to: _MigrationDescriptor.self) { type in
                unsafe accessor(buffer.baseAddress!, UnsafeRawPointer(type), nil, 0)
            }

            guard initialized else { return nil }
            return unsafe buffer.baseAddress!.move()
        }
    }
}

