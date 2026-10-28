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
