//
//  AutoMigrationRegistration.swift
//  fluentkit-utils
//
//  Created by Codex on 28/05/2026
//

import FluentKit
import Foundation

public enum AutoMigrationRegistrationError: Error, CustomStringConvertible, Sendable {
    case duplicateMigration(modelName: String, version: Int)
    case versionsMustStartAtOne(modelName: String)
    case versionsMustBeContinuous(modelName: String, expected: Int, actual: Int)
    case missingReference(modelName: String, version: Int, reference: MigrationReference)
    case dependencyCycle([String])

    public var description: String {
        switch self {
        case let .duplicateMigration(modelName, version):
            return "Duplicate auto migration descriptor for \(modelName) version \(version)."
        case let .versionsMustStartAtOne(modelName):
            return "Auto migration versions for \(modelName) must start at 1."
        case let .versionsMustBeContinuous(modelName, expected, actual):
            return "Auto migration versions for \(modelName) must be continuous. Expected \(expected), found \(actual)."
        case let .missingReference(modelName, version, reference):
            return "Auto migration \(modelName) version \(version) requires missing reference \(reference.modelName).\(reference.key)."
        case let .dependencyCycle(nodes):
            return "Auto migration dependency cycle detected: \(nodes.joined(separator: " -> "))."
        }
    }
}

private struct RuntimeMigrationNode: Hashable, Sendable {
    let modelName: String
    let version: Int

    var id: String { "\(modelName):v\(version)" }
}

private struct RuntimeMigrationMetadata: Sendable {
    let metadata: AutoMigrationMetadata
    let isPlaceholder: Bool
    let sourceVersion: Int
}

extension Migrations {
    public func autoRegisterMigrations(
        to id: DatabaseID? = nil
    ) throws {
        let logger = Logger(label: "com.fluentkit-util.auto-migration-registration")
        logger.info("Starting automatic migration discovery.")

        let descriptors = _MigrationDiscovery._discover()
        logger.info("Discovered \(descriptors.count) auto migration records.")

        logger.info("Computing auto migration dependency order.")
        let ordered = try Self._orderedAutoMigrationDescriptors(descriptors)

        for descriptor in ordered {
            logger.info("Registering auto migration: \(descriptor.modelName):\(descriptor.version).")
            self.add(descriptor.makeMigration(), to: id)
        }

        logger.info("Completed auto migration registration with \(ordered.count) migrations.")
    }

    static func _orderedAutoMigrationDescriptors(
        _ descriptors: [_MigrationDescriptor]
    ) throws -> [_MigrationDescriptor] {
        var descriptorsByNode = [RuntimeMigrationNode: _MigrationDescriptor]()
        for descriptor in descriptors {
            let node = RuntimeMigrationNode(modelName: descriptor.modelName, version: descriptor.version)
            guard descriptorsByNode[node] == nil else {
                throw AutoMigrationRegistrationError.duplicateMigration(
                    modelName: descriptor.modelName,
                    version: descriptor.version
                )
            }
            descriptorsByNode[node] = descriptor
        }

        try validateVersionSequences(descriptorsByNode.keys)
        let runtimeTable = try buildRuntimeMetadataTable(from: descriptorsByNode)
        let orderedNodes = try topologicallySortedNodes(
            descriptorsByNode: descriptorsByNode,
            runtimeTable: runtimeTable
        )

        return orderedNodes.compactMap { descriptorsByNode[$0] }
    }

    private static func validateVersionSequences(
        _ nodes: Dictionary<RuntimeMigrationNode, _MigrationDescriptor>.Keys
    ) throws {
        let grouped = Dictionary(grouping: nodes, by: \.modelName)

        for (modelName, modelNodes) in grouped {
            let versions = modelNodes.map(\.version).sorted()
            guard versions.first == 1 else {
                throw AutoMigrationRegistrationError.versionsMustStartAtOne(modelName: modelName)
            }

            for (offset, version) in versions.enumerated() {
                let expected = offset + 1
                guard version == expected else {
                    throw AutoMigrationRegistrationError.versionsMustBeContinuous(
                        modelName: modelName,
                        expected: expected,
                        actual: version
                    )
                }
            }
        }
    }

    private static func buildRuntimeMetadataTable(
        from descriptorsByNode: [RuntimeMigrationNode: _MigrationDescriptor]
    ) throws -> [String: [Int: RuntimeMigrationMetadata]] {
        let maxVersion = descriptorsByNode.keys.map(\.version).max() ?? 0
        let grouped = Dictionary(grouping: descriptorsByNode.keys, by: \.modelName)
        var table = [String: [Int: RuntimeMigrationMetadata]]()

        for (modelName, nodes) in grouped {
            let descriptors = Dictionary(uniqueKeysWithValues: nodes.map { node in
                (node.version, descriptorsByNode[node]!)
            })
            var previous: RuntimeMigrationMetadata?
            var modelTable = [Int: RuntimeMigrationMetadata]()

            for version in 1...maxVersion {
                if let descriptor = descriptors[version] {
                    let metadata = descriptor.makeMetadata()
                    let runtimeMetadata = RuntimeMigrationMetadata(
                        metadata: metadata,
                        isPlaceholder: false,
                        sourceVersion: version
                    )
                    modelTable[version] = runtimeMetadata
                    previous = runtimeMetadata
                } else if let previous {
                    let metadata = AutoMigrationMetadata(
                        modelName: previous.metadata.modelName,
                        version: version,
                        providedReferences: previous.metadata.providedReferences,
                        requiredReferences: []
                    )
                    modelTable[version] = RuntimeMigrationMetadata(
                        metadata: metadata,
                        isPlaceholder: true,
                        sourceVersion: previous.sourceVersion
                    )
                }
            }

            table[modelName] = modelTable
        }

        return table
    }

    private static func topologicallySortedNodes(
        descriptorsByNode: [RuntimeMigrationNode: _MigrationDescriptor],
        runtimeTable: [String: [Int: RuntimeMigrationMetadata]]
    ) throws -> [RuntimeMigrationNode] {
        let nodes = Set(descriptorsByNode.keys)
        var outgoing = Dictionary(uniqueKeysWithValues: nodes.map { ($0, Set<RuntimeMigrationNode>()) })
        var incomingCount = Dictionary(uniqueKeysWithValues: nodes.map { ($0, 0) })

        func addEdge(from source: RuntimeMigrationNode, to target: RuntimeMigrationNode) {
            guard source != target, nodes.contains(source), nodes.contains(target) else {
                return
            }
            if outgoing[source, default: []].insert(target).inserted {
                incomingCount[target, default: 0] += 1
            }
        }

        for node in nodes {
            if node.version > 1 {
                addEdge(
                    from: RuntimeMigrationNode(modelName: node.modelName, version: node.version - 1),
                    to: node
                )
            }

            let metadata = descriptorsByNode[node]!.makeMetadata()
            for reference in metadata.requiredReferences {
                guard let targetMetadata = runtimeTable[reference.modelName]?[node.version],
                      targetMetadata.metadata.providedReferences.contains(reference)
                else {
                    throw AutoMigrationRegistrationError.missingReference(
                        modelName: node.modelName,
                        version: node.version,
                        reference: reference
                    )
                }

                addEdge(
                    from: RuntimeMigrationNode(
                        modelName: reference.modelName,
                        version: targetMetadata.sourceVersion
                    ),
                    to: node
                )
            }
        }

        var ready = nodes
            .filter { incomingCount[$0, default: 0] == 0 }
            .sorted(by: nodeSort)
        var ordered = [RuntimeMigrationNode]()

        while let node = ready.first {
            ready.removeFirst()
            ordered.append(node)

            for next in outgoing[node, default: []].sorted(by: nodeSort) {
                incomingCount[next, default: 0] -= 1
                if incomingCount[next, default: 0] == 0 {
                    ready.append(next)
                    ready.sort(by: nodeSort)
                }
            }
        }

        guard ordered.count == nodes.count else {
            let cyclicNodes = nodes
                .filter { !ordered.contains($0) }
                .sorted(by: nodeSort)
                .map(\.id)
            throw AutoMigrationRegistrationError.dependencyCycle(cyclicNodes)
        }

        if dependencyComputingTestingEnabled {
            printDependencyComputingResult(
                nodes: nodes,
                outgoing: outgoing,
                runtimeTable: runtimeTable,
                ordered: ordered
            )
        }

        return ordered
    }

    private static var dependencyComputingTestingEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["FLUENTKIT_UTILS_DEPENDENCY_COMPUTING_TESTING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private static func printDependencyComputingResult(
        nodes: Set<RuntimeMigrationNode>,
        outgoing: [RuntimeMigrationNode: Set<RuntimeMigrationNode>],
        runtimeTable: [String: [Int: RuntimeMigrationMetadata]],
        ordered: [RuntimeMigrationNode]
    ) {
        let nodeIDs = nodes
            .sorted(by: nodeSort)
            .map(\.id)
            .joined(separator: ", ")
        let edges = outgoing
            .flatMap { source, targets in
                targets.sorted(by: nodeSort).map { "\(source.id) -> \($0.id)" }
            }
            .sorted()
        let metadataRows = runtimeTable
            .flatMap { modelName, versions in
                versions.keys.sorted().compactMap { version -> String? in
                    guard let metadata = versions[version] else {
                        return nil
                    }

                    let placeholder = metadata.isPlaceholder ? "placeholder" : "real"
                    let provided = metadata.metadata.providedReferences
                        .map { "\($0.modelName).\($0.key)" }
                        .sorted()
                        .joined(separator: ", ")
                    return "\(modelName):v\(version) [\(placeholder), source:v\(metadata.sourceVersion), provides:[\(provided)]]"
                }
            }
            .sorted()
        let orderedIDs = ordered
            .map(\.id)
            .joined(separator: " -> ")
        
        let edgesDebugText = if !edges.isEmpty {
            """
            [DependencyComputingTesting] edges:
            \(edges.map { "[DependencyComputingTesting]   \($0)" }.joined(separator: "\n"))
            """
        } else {
            "[DependencyComputingTesting] edges: no edge."
        }

        print(
            """
            [DependencyComputingTesting] nodes: \(nodeIDs)
            \(edgesDebugText)
            [DependencyComputingTesting] runtime metadata:
            \(metadataRows.map { "[DependencyComputingTesting]   \($0)" }.joined(separator: "\n"))
            [DependencyComputingTesting] ordered: \(orderedIDs)
            """
        )
    }

    private static func nodeSort(_ lhs: RuntimeMigrationNode, _ rhs: RuntimeMigrationNode) -> Bool {
        if lhs.version != rhs.version {
            return lhs.version < rhs.version
        }
        return lhs.modelName < rhs.modelName
    }
}
