//
//  ViewType.swift
//  Serverless
//
//  Created by prit on 27/05/26.
//

import Foundation

enum FieldType: Equatable, Decodable {
    case text
    case dropdown
    case toggle
    case checkbox
    case colorPicker
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(String.self).uppercased()) ?? "UNKNOWN"

        switch value {
        case "TEXT":
            self = .text
        case "DROPDOWN":
            self = .dropdown
        case "TOGGLE":
            self = .toggle
        case "CHECKBOX":
            self = .checkbox
        case "COLOR_PICKER":
            self = .colorPicker
        default:
            self = .unknown(value)
        }
    }

    var isRenderable: Bool {
        if case .unknown = self {
            return false
        }

        return true
    }
}

enum Subtype: Equatable, Decodable {
    case plain
    case multiline
    case number
    case uri
    case secure
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(String.self).uppercased()) ?? "UNKNOWN"

        switch value {
        case "PLAIN":
            self = .plain
        case "MULTILINE":
            self = .multiline
        case "NUMBER":
            self = .number
        case "URI", "URL":
            self = .uri
        case "SECURE":
            self = .secure
        default:
            self = .unknown(value)
        }
    }
}
