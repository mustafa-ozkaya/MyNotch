//
//  LauncherConfig+Editing.swift
//  boringNotch
//

import Foundation

/// Which item list an edit applies to: the standalone items or a mode's items.
enum LauncherListTarget: Hashable {
    case standalone
    case mode(UUID)
}

extension LauncherConfig {
    /// The items of a list. Setting a mode that doesn't exist is ignored.
    subscript(items target: LauncherListTarget) -> [LauncherItem] {
        get {
            switch target {
            case .standalone:
                return items
            case .mode(let modeID):
                return modes.first(where: { $0.id == modeID })?.items ?? []
            }
        }
        set {
            switch target {
            case .standalone:
                items = newValue
            case .mode(let modeID):
                guard let index = modes.firstIndex(where: { $0.id == modeID }) else { return }
                modes[index].items = newValue
            }
        }
    }

    mutating func append(_ item: LauncherItem, to target: LauncherListTarget) {
        self[items: target].append(item)
    }

    mutating func removeItem(id: UUID, from target: LauncherListTarget) {
        self[items: target].removeAll { $0.id == id }
    }

    mutating func moveItem(id: UUID, by offset: Int, in target: LauncherListTarget) {
        self[items: target].move(id: id, by: offset)
    }

    mutating func updateItem(id: UUID, in target: LauncherListTarget, _ change: (inout LauncherItem) -> Void) {
        var list = self[items: target]
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        change(&list[index])
        self[items: target] = list
    }

    mutating func moveMode(id: UUID, by offset: Int) {
        modes.move(id: id, by: offset)
    }
}

extension Array where Element: Identifiable {
    /// Moves the element with `id` by `offset` positions, clamped to the array bounds.
    mutating func move(id: Element.ID, by offset: Int) {
        guard let from = firstIndex(where: { $0.id == id }) else { return }
        let to = Swift.min(Swift.max(from + offset, 0), count - 1)
        guard to != from else { return }
        insert(remove(at: from), at: to)
    }
}
