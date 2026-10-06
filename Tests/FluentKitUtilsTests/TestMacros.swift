import SwiftSyntaxMacros
import FluentKitUtilsMacros

let testMacros: [String: Macro.Type] = [
    "FluentModel": FluentModelMacro.self,
    "AutoMigratable": EmptyMacro.self,
    "Attribute": EmptyMacro.self,
    "Relationship": EmptyMacro.self,
    "Migration": EmptyMacro.self,
    "SiblingIntermediate": SiblingIntermediateMacro.self,
]
