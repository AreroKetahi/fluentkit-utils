import Testing
import MacroTesting
@testable import FluentKitUtilsMacros

@Suite(.macros(testMacros))
struct FluentModelMacroExpansionTests {
    @Test
    func generatesMembersAttributesAndMigration() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                @Attribute(.unique)
                var email: String
                @Attribute(.key("avatar_url"))
                var avatarURL: String?
                @Relationship(.child, \\SessionSchema.$user)
                var sessions: [SessionSchema]
                var createdAt: Date?
            }
            """
        } expansion: {
            """
            final class UserSchema {
                @ID(key: .id)
                var id: UUID?
                @Field(key: "name")
                var name: String
                @Field(key: "email")
                var email: String
                @OptionalField(key: "avatar_url")
                var avatarURL: String?
                @Children(for: \\SessionSchema.$user)
                var sessions: [SessionSchema]
                @Timestamp(key: "created_at", on: .create)
                var createdAt: Date?
            
                static let schema = "users"
            
                init() {
                }
            
                static let $migrations: [any FluentKit.Migration] = [$s10UserSchema11MigrationV1V()]
            
                struct $s10UserSchema11MigrationV1V: AsyncMigration {
                    var name: String {
                        "$s10UserSchema11MigrationV1V"
                    }
                    func prepare(on database: any Database) async throws {
                        var schemaBuilder = database.schema("users")
                        schemaBuilder = schemaBuilder.id()
                        schemaBuilder = schemaBuilder.field("name", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.field("email", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.field("avatar_url", DatabaseSchema.DataType.string)
                        schemaBuilder = schemaBuilder.field("created_at", DatabaseSchema.DataType.datetime)
                        schemaBuilder = schemaBuilder.unique(on: "email")
                        try await schemaBuilder.create()
                    }
                    func revert(on database: any Database) async throws {
                        try await database.schema("users").delete()
                    }
                }
            }
            
            extension UserSchema: Model, @unchecked Sendable {
            }
            """
        }
    }

    @Test
    func testGeneratesExplicitVersionedMigrations() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                @Attribute(.unique)
                var email: String
                var age: Int?
            
                #Migration(version: 1, for: \\UserSchema.name, \\UserSchema.email)
                #Migration(version: 2, for: .add(\\UserSchema.age), .rename(\\UserSchema.email, from: "login_email"), .delete(\\UserSchema.name))
            }
            """
        } expansion: {
            """
            final class UserSchema {
                @ID(key: .id)
                var id: UUID?
                @Field(key: "name")
                var name: String
                @Field(key: "email")
                var email: String
                @OptionalField(key: "age")
                var age: Int?
            
                static let schema = "users"
            
                init() {
                }
            
                static let $migrations: [any FluentKit.Migration] = [$s10UserSchema11MigrationV1V(), $s10UserSchema11MigrationV2V()]
            
                struct $s10UserSchema11MigrationV1V: AsyncMigration {
                    var name: String {
                        "$s10UserSchema11MigrationV1V"
                    }
                    func prepare(on database: any Database) async throws {
                        var schemaBuilder = database.schema("users")
                        schemaBuilder = schemaBuilder.id()
                        schemaBuilder = schemaBuilder.field("name", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.field("email", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.unique(on: "email")
                        try await schemaBuilder.create()
                    }
                    func revert(on database: any Database) async throws {
                        try await database.schema("users").delete()
                    }
                }
            
                struct $s10UserSchema11MigrationV2V: AsyncMigration {
                    var name: String {
                        "$s10UserSchema11MigrationV2V"
                    }
                    func prepare(on database: any Database) async throws {
                        var schemaBuilder = database.schema("users")
                        schemaBuilder = schemaBuilder.field("age", DatabaseSchema.DataType.int)
                        schemaBuilder = schemaBuilder.deleteUnique(on: "login_email")
                        schemaBuilder = schemaBuilder.deleteField("login_email")
                        schemaBuilder = schemaBuilder.field("email", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.unique(on: "email")
                        schemaBuilder = schemaBuilder.deleteField("name")
                        try await schemaBuilder.update()
                    }
                    func revert(on database: any Database) async throws {
                        var schemaBuilder = database.schema("users")
                        schemaBuilder = schemaBuilder.field("name", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.deleteUnique(on: "email")
                        schemaBuilder = schemaBuilder.deleteField("email")
                        schemaBuilder = schemaBuilder.field("login_email", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.unique(on: "login_email")
                        schemaBuilder = schemaBuilder.deleteField("age")
                        try await schemaBuilder.update()
                    }
                }
            }
            
            extension UserSchema: Model, @unchecked Sendable {
            }
            """
        }
    }

    @Test
    func supportsExplicitGenericMigrationWithInferredRootKeyPaths() throws {
        assertMacro {
            """
            @FluentModel("v_chat_users")
            final class VChatUsers {
                var id: UUID?
                var username: String
                var passwordDigest: String

                #Migration<VChatUsers>(version: 1, for: \\.id, \\.username, \\.passwordDigest)
            }
            """
        } expansion: {
            """
            final class VChatUsers {
                @ID(key: .id)
                var id: UUID?
                @Field(key: "username")
                var username: String
                @Field(key: "password_digest")
                var passwordDigest: String
            
                static let schema = "v_chat_users"
            
                init() {
                }
            
                static let $migrations: [any FluentKit.Migration] = [$s10VChatUsers11MigrationV1V()]
            
                struct $s10VChatUsers11MigrationV1V: AsyncMigration {
                    var name: String {
                        "$s10VChatUsers11MigrationV1V"
                    }
                    func prepare(on database: any Database) async throws {
                        var schemaBuilder = database.schema("v_chat_users")
                        schemaBuilder = schemaBuilder.id()
                        schemaBuilder = schemaBuilder.field("username", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        schemaBuilder = schemaBuilder.field("password_digest", DatabaseSchema.DataType.string, DatabaseSchema.FieldConstraint.required)
                        try await schemaBuilder.create()
                    }
                    func revert(on database: any Database) async throws {
                        try await database.schema("v_chat_users").delete()
                    }
                }
            }
            
            extension VChatUsers: Model, @unchecked Sendable {
            }
            """
        }
    }

    @Test
    func autoMigratableEmitsRuntimeDiscoveryRecords() throws {
        assertMacro {
            """
            @AutoMigratable
            @FluentModel("sessions")
            final class SessionSchema {
                var id: UUID?
                @Relationship(.parent)
                var user: UserSchema
            }
            """
        } expansion: {
            """
            final class SessionSchema {
                @ID(key: .id)
                var id: UUID?
                @Parent(key: "user_id")
                var user: UserSchema
            
                static let schema = "sessions"
            
                init() {
                }
            
                static let $migrations: [any FluentKit.Migration] = [$s13SessionSchema11MigrationV1V()]
            
                struct $s13SessionSchema11MigrationV1V: AsyncMigration {
                    var name: String {
                        "$s13SessionSchema11MigrationV1V"
                    }
                    func prepare(on database: any Database) async throws {
                        var schemaBuilder = database.schema("sessions")
                        schemaBuilder = schemaBuilder.id()
                        schemaBuilder = schemaBuilder.field("user_id", DatabaseSchema.DataType.uuid, DatabaseSchema.FieldConstraint.required)
                        try await schemaBuilder.create()
                    }
                    func revert(on database: any Database) async throws {
                        try await database.schema("sessions").delete()
                    }
                }
            }
            
            @available(*, deprecated, message: "This property is an implementation detail of FluentKitUtils. Do not use it directly.")
            private nonisolated let __macro_local_36FluentKitUtilsAutoMigration_accessorfMu_: FluentKitUtils._MigrationRegisterAccessor = { outValue, type, _, _ in
                guard unsafe type.load(as: Any.Type.self) == FluentKitUtils._MigrationDescriptor.self else {
                    return false
                }
            
                unsafe outValue.initializeMemory(
                    as: FluentKitUtils._MigrationDescriptor.self,
                    to: FluentKitUtils._MigrationDescriptor(
                        modelName: "SessionSchema",
                        version: 1,
                        makeMigration: {
                            SessionSchema.$s13SessionSchema11MigrationV1V()
                        },
                        makeMetadata: {
                            FluentKitUtils.AutoMigrationMetadata(
                                modelName: "SessionSchema",
                                version: 1,
                                providedReferences: [FluentKitUtils.MigrationReference(modelName: "SessionSchema", key: "id")],
                                requiredReferences: [FluentKitUtils.MigrationReference(modelName: "UserSchema", key: "id")]
                            )
                        }
                    )
                )
            
                return true
            }
            
            #if objectFormat(MachO)
            @section("__DATA_CONST,__swift5_fkmg")
            #elseif objectFormat(ELF)
            @section("swift5_fkmg")
            #elseif objectFormat(COFF)
            @section(".sw5fkmg")
            #endif
            @used
            @available(*, deprecated, message: "This property is an implementation detail of FluentKitUtils. Do not use it directly.")
            private let __macro_local_34FluentKitUtilsAutoMigration_recordfMu_: FluentKitUtils._MigrationRegisterRecord = (
                0x666B_6D67,
                1,
                {
                    unsafe __macro_local_36FluentKitUtilsAutoMigration_accessorfMu_($0, $1, $2, $3)
                },
                0,
                0
            )
            
            extension SessionSchema: Model, @unchecked Sendable {
            }
            """
        }
    }
}
