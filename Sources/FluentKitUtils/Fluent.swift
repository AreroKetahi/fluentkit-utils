//
//  Fluent.swift
//  fluentkit-utils
//
//  Created by Arkivili Collindort on 01/05/2026
//

@_exported import FluentKit

public enum RelationshipKind: Sendable {
    case parent
    case child
    case siblings
}

public enum ModelAttributeOption: Sendable {
    case key(String)
    case unique
    case timestamp(TimestampTrigger)
    case ignore
}

public enum TimestampTrigger: Sendable {
    case create
    case update
    case delete
}

@attached(peer)
public macro AutoMigratable() =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

@attached(
    member,
    names: named(schema),
    named(init),
    named($migrations),
    arbitrary
)
@attached(memberAttribute)
@attached(extension, conformances: Model, Sendable)
@attached(peer, names: prefixed(`$`))
public macro FluentModel(_ schema: StaticString? = nil) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "FluentModelMacro"
    )

@attached(peer)
public macro Attribute(_ options: ModelAttributeOption...) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

@attached(peer)
public macro Relationship(
    kind: RelationshipKind
) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

@attached(peer)
public macro Relationship<M: Model>(
    kind: RelationshipKind,
    for relationship: M.Type? = nil
) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

@freestanding(declaration)
public macro Migration<T: Model>(
    version: Int,
    for: PartialKeyPath<T>...
) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

@freestanding(declaration)
public macro Migration<T: Model>(
    version: Int,
    for: ModelEvolution<T>...
) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "EmptyMacro"
    )

// MARK: - Siblings

@freestanding(declaration, names: prefixed($_FluentSibling_))
public macro SiblingIntermediate<L: Model, R: Model>(
    between first: L.Type,
    _ second: R.Type
) =
    #externalMacro(
        module: "FluentKitUtilsMacros",
        type: "SiblingIntermediateMacro"
    )
