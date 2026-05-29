import FluentKit
import Testing
@testable import FluentKitUtils

private struct TestMigration: FluentKit.Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.eventLoop.makeSucceededFuture(())
    }

    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.eventLoop.makeSucceededFuture(())
    }
}

@Suite
struct AutoMigrationRegistrationTests {
    @Test
    func ordersMigrationsByDependenciesAndVersion() throws {
        let descriptors = [
            descriptor(model: "SessionSchema", version: 1, required: [.init(modelName: "UserSchema", key: "id")]),
            descriptor(model: "UserSchema", version: 1),
            descriptor(model: "UserSchema", version: 2),
        ]

        let ordered = try Migrations._orderedAutoMigrationDescriptors(descriptors)
            .map { "\($0.modelName).\($0.version)" }

        #expect(ordered == ["UserSchema.1", "SessionSchema.1", "UserSchema.2"])
    }

    @Test
    func reportsMissingReference() throws {
        let descriptors = [
            descriptor(model: "SessionSchema", version: 1, required: [.init(modelName: "UserSchema", key: "id")]),
        ]

        #expect(throws: AutoMigrationRegistrationError.self) {
            try Migrations._orderedAutoMigrationDescriptors(descriptors)
        }
    }

    private func descriptor(
        model: String,
        version: Int,
        provided: [MigrationReference] = [],
        required: [MigrationReference] = []
    ) -> _MigrationDescriptor {
        _MigrationDescriptor(
            modelName: model,
            version: version,
            makeMigration: { TestMigration() },
            makeMetadata: {
                AutoMigrationMetadata(
                    modelName: model,
                    version: version,
                    providedReferences: provided.isEmpty ? [.init(modelName: model, key: "id")] : provided,
                    requiredReferences: required
                )
            }
        )
    }
}
