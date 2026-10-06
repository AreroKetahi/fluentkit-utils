import MacroTesting
import Testing
@testable import FluentKitUtilsMacros

@Suite(
    .macros(["SiblingIntermediate": SiblingIntermediateMacro.self])
)
struct SiblingIntermediateMacroTests {
    @Test
    func generatesStableAlphabeticalIntermediateModel() {
        assertMacro {
            """
            #SiblingIntermediate(between: Tag.self, Planet.self)
            """
        } expansion: {
            """
            @FluentModel
            final class $_FluentSibling_Planet_Tag {
                var id: UUID?

                @Relationship(kind: .parent, for: Planet.self)
                var planet: Planet

                @Relationship(kind: .parent, for: Tag.self)
                var tag: Tag
            }
            """
        }
    }
}
