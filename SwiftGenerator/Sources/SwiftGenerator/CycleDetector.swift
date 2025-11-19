import Foundation

/// Detects circular type dependencies in Lexicon definitions
class CycleDetector {
    private var typeGraph: [String: Set<String>] = [:]
    private var indirectTypes: Set<String> = []

    /// Register all types from a lexicon
    func registerLexicon(_ lexicon: Lexicon) {
        for (defName, def) in lexicon.defs {
            let fullName = defName == "main" ? lexicon.id : "\(lexicon.id)#\(defName)"
            registerDef(fullName: fullName, def: def, lexiconID: lexicon.id)
        }
    }

    private func registerDef(fullName: String, def: LexiconDef, lexiconID: String) {
        var dependencies = Set<String>()

        // Extract dependencies based on type
        switch def.type {
        case "object", "record":
            if let properties = def.properties {
                dependencies.formUnion(extractPropertyDependencies(properties, lexiconID: lexiconID))
            }
            if let record = def.record, let properties = record.properties {
                dependencies.formUnion(extractPropertyDependencies(properties, lexiconID: lexiconID))
            }
        case "union":
            if let refs = def.refs {
                dependencies.formUnion(refs.map { resolveRef($0, from: lexiconID) })
            }
        case "array":
            if let items = def.items {
                dependencies.formUnion(extractTypeDependencies(items, lexiconID: lexiconID))
            }
        default:
            break
        }

        typeGraph[fullName] = dependencies
    }

    private func extractPropertyDependencies(_ properties: [String: LexiconProperty], lexiconID: String) -> Set<String> {
        var deps = Set<String>()
        for (_, property) in properties {
            switch property {
            case .type(let type):
                deps.formUnion(extractTypeDependencies(type, lexiconID: lexiconID))
            case .object:
                // Inline objects don't create external dependencies
                break
            }
        }
        return deps
    }

    private func extractTypeDependencies(_ type: LexiconType, lexiconID: String) -> Set<String> {
        var deps = Set<String>()

        switch type.type {
        case "ref":
            if let ref = type.ref {
                deps.insert(resolveRef(ref, from: lexiconID))
            }
        case "union":
            if let refs = type.refs {
                deps.formUnion(refs.map { resolveRef($0, from: lexiconID) })
            }
        case "array":
            if let items = type.items {
                deps.formUnion(extractTypeDependencies(items.value, lexiconID: lexiconID))
            }
        case "object":
            if let properties = type.properties {
                deps.formUnion(extractPropertyDependencies(properties, lexiconID: lexiconID))
            }
        default:
            break
        }

        return deps
    }

    private func resolveRef(_ ref: String, from lexiconID: String) -> String {
        if ref.hasPrefix("#") {
            return "\(lexiconID)\(ref)"
        }
        return ref
    }

    /// Detect cycles and mark types that need indirection
    func detectCycles() {
        var visited = Set<String>()
        var recursionStack = Set<String>()
        var cycleTypes = Set<String>()

        for type in typeGraph.keys {
            if !visited.contains(type) {
                detectCyclesDFS(type: type, visited: &visited, stack: &recursionStack, cycleTypes: &cycleTypes)
            }
        }

        // Mark cycle types as needing indirection
        indirectTypes = cycleTypes
    }

    private func detectCyclesDFS(type: String, visited: inout Set<String>, stack: inout Set<String>, cycleTypes: inout Set<String>) {
        visited.insert(type)
        stack.insert(type)

        if let dependencies = typeGraph[type] {
            for dep in dependencies {
                if !visited.contains(dep) {
                    detectCyclesDFS(type: dep, visited: &visited, stack: &stack, cycleTypes: &cycleTypes)
                } else if stack.contains(dep) {
                    // Found a cycle
                    cycleTypes.insert(type)
                    cycleTypes.insert(dep)
                }
            }
        }

        stack.remove(type)
    }

    /// Check if a type needs indirection
    func needsIndirection(for typeID: String) -> Bool {
        return indirectTypes.contains(typeID)
    }

    /// Check if a union should be marked as indirect
    func unionNeedsIndirection(lexiconID: String, propertyName: String) -> Bool {
        let unionID = "\(lexiconID)#\(propertyName)Union"
        return indirectTypes.contains(unionID)
    }
}
