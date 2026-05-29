//
//  ModelEvolution.swift
//  fluentkit-utils
//
//  Created by Arkivili Collindort on 01/05/2026
//

public enum ModelEvolution<T> {
    case add(PartialKeyPath<T>)
    case rename(PartialKeyPath<T>, from: String)
    case delete(PartialKeyPath<T>)
}
