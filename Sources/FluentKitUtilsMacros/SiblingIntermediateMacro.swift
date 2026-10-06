import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum SiblingIntermediateMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard node.arguments.count == 2,
              let first = modelName(from: node.arguments[node.arguments.startIndex].expression),
              let second = modelName(from: node.arguments[node.arguments.index(after: node.arguments.startIndex)].expression)
        else {
            throw MacroExpansionErrorMessage(
                "#SiblingIntermediate requires two simple model types, such as Planet.self and Tag.self."
            )
        }

        guard first != second else {
            throw MacroExpansionErrorMessage(
                "#SiblingIntermediate requires two different model types."
            )
        }

        let models = [first, second].sorted()
        let typeName = "$_FluentSibling_\(models[0])_\(models[1])"
        let firstProperty = FluentModelMacro.defaultModelPropertyName(for: models[0])
        let secondProperty = FluentModelMacro.defaultModelPropertyName(for: models[1])

        return [
            """
            @FluentModel
            final class \(raw: typeName) {
                var id: UUID?

                @Relationship(kind: .parent, for: \(raw: models[0]).self)
                var \(raw: firstProperty): \(raw: models[0])

                @Relationship(kind: .parent, for: \(raw: models[1]).self)
                var \(raw: secondProperty): \(raw: models[1])
            }
            """
        ]
    }

    private static func modelName(from expression: ExprSyntax) -> String? {
        guard let memberAccess = expression.as(MemberAccessExprSyntax.self),
              memberAccess.declName.baseName.tokenKind == .keyword(.`self`),
              let base = memberAccess.base?.as(DeclReferenceExprSyntax.self)
        else {
            return nil
        }

        return base.baseName.text
    }

}
