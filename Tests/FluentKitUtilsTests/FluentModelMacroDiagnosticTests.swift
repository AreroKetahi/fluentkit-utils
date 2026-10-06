import Testing
import MacroTesting

@Suite
struct FluentModelMacroDiagnosticTests {
    @Test(.macros(testMacros))
    func childRelationshipRequiresKeyPath() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                @Relationship(kind: .child)
                var sessions: [SessionSchema]
            }
            """
        } diagnostics: {
            """
            @FluentModel("users")
            final class UserSchema {
                @Relationship(kind: .child)
                ┬──────────────────────────
                ╰─ 🛑 @Relationship(.child, ...) requires a relationship key path.
                var sessions: [SessionSchema]
            }
            """
        }
    }

    @Test(.macros(testMacros))
    func migrationVersionsMustStartAtOne() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String

                #Migration(version: 2, for: .add(\\UserSchema.name))
            }
            """
        } diagnostics: {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String

                #Migration(version: 2, for: .add(\\UserSchema.name))
                ┬──────────────────────────────────────────────────
                ╰─ 🛑 #Migration versions must start at 1.
            }
            """
        }
    }

    @Test(.macros(testMacros))
    func migrationVersionsMustBeContinuous() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                var age: Int?

                #Migration(version: 1, for: \\UserSchema.name)
                #Migration(version: 3, for: .add(\\UserSchema.age))
            }
            """
        } diagnostics: {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                var age: Int?

                #Migration(version: 1, for: \\UserSchema.name)
                #Migration(version: 3, for: .add(\\UserSchema.age))
                ┬─────────────────────────────────────────────────
                ╰─ 🛑 #Migration versions must be continuous.
            }
            """
        }
    }

    @Test(.macros(testMacros))
    func migrationVersionGreaterThanOneRequiresEvolution() throws {
        assertMacro {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                var age: Int?

                #Migration(version: 1, for: \\UserSchema.name)
                #Migration(version: 2, for: \\UserSchema.age)
            }
            """
        } diagnostics: {
            """
            @FluentModel("users")
            final class UserSchema {
                var id: UUID?
                var name: String
                var age: Int?

                #Migration(version: 1, for: \\UserSchema.name)
                #Migration(version: 2, for: \\UserSchema.age)
                ┬───────────────────────────────────────────
                ╰─ 🛑 #Migration with version greater than 1 must use ModelEvolution values.
            }
            """
        }
    }
}
