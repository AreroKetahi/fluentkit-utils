//
//  Entrypoint.swift
//  fluentkit-utils
//
//  Created by Arkivili Collindort on 01/05/2026
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct FluentKitUtilsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FluentModelMacro.self,
        EmptyMacro.self,
        SiblingIntermediateMacro.self,
    ]
}
