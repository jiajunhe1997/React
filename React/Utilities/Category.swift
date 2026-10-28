//
//  Category.swift
//  React
//
//  Created by 何佳駿 on 2024/10/19.
//

import Foundation
struct Category: Identifiable, Codable {
    var id = UUID()
    var name: String
    var imagePaths: [String] = []
    var isTrash: Bool = false
    var lastModified: Date = Date()
}

struct BoardOrdering {
    static func apply(_ ids: [UUID], to categories: [Category]) -> [Category] {
        var remaining = categories.filter { !$0.isTrash }
        var ordered: [Category] = []
        for id in ids {
            if let index = remaining.firstIndex(where: { $0.id == id }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        return ordered + remaining + categories.filter(\.isTrash)
    }
}

struct PhotoOrdering {
    static func move(_ source: String, to destination: String, in paths: [String]) -> [String] {
        guard source != destination, let from = paths.firstIndex(of: source),
              let to = paths.firstIndex(of: destination) else { return paths }
        var result = paths
        result.insert(result.remove(at: from), at: to)
        return result
    }
}
