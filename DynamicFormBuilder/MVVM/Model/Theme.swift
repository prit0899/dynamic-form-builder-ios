//
//  Theme.swift
//  Serverless
//
//  Created by prit on 27/05/26.
//

import SwiftUI

struct UIElements: Decodable {
    var theme: Theme
    var form_title: String
    var fields: [Field]

    var orderedFields: [Field] {
        fields.sorted { $0.order < $1.order }
    }

    var renderableFields: [Field] {
        orderedFields.filter { $0.type.isRenderable }
    }

    enum CodingKeys: String, CodingKey {
        case theme
        case form_title
        case formTitle
        case fields
    }

    enum AlternateCodingKeys: String, CodingKey {
        case formTitle = "form title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternateContainer = try decoder.container(keyedBy: AlternateCodingKeys.self)

        theme = try container.decode(Theme.self, forKey: .theme)
        form_title = try container.decodeIfPresent(String.self, forKey: .form_title)
            ?? container.decodeIfPresent(String.self, forKey: .formTitle)
            ?? alternateContainer.decodeIfPresent(String.self, forKey: .formTitle)
            ?? "Dynamic Form"
        fields = try container.decodeIfPresent([Field].self, forKey: .fields) ?? []
    }

    static func loadFromBundle() throws -> UIElements {
        guard let url = Bundle.main.url(forResource: "UI", withExtension: "json") else {
            throw FormLoadError.missingResource
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UIElements.self, from: data)
    }
}

struct Theme: Decodable {
    var background_color: String
    var text_color: String
    var border_color: String
    var error_color: String

    var backgroundColor: Color {
        Color.formHex(background_color, fallback: Color(red: 0.07, green: 0.07, blue: 0.07))
    }

    var textColor: Color {
        Color.formHex(text_color, fallback: Color(red: 0.88, green: 0.88, blue: 0.88))
    }

    var borderColor: Color {
        Color.formHex(border_color, fallback: Color(red: 0.2, green: 0.2, blue: 0.2))
    }

    var errorColor: Color {
        Color.formHex(error_color, fallback: Color(red: 0.81, green: 0.4, blue: 0.47))
    }
}

struct OptionField: Identifiable, Decodable {
    var id: String
    var label: String
}

enum FieldDefaultValue: Decodable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool:
            return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }

        return nil
    }
}

enum FormLoadError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        "UI.json was not found in the app bundle."
    }
}

struct Field: Identifiable, Decodable {
    var id: String
    var order: Int
    var type: FieldType
    var subtype: Subtype?
    var label: String
    var allow_multiple: Bool
    var error_message: String?
    var required: Bool
    var options: [OptionField]
    var clickable_text_color: String?
    var max_length: Int?
    var placeholder: String?
    var default_value: FieldDefaultValue?
    var default_values: [String]
    var supporting_text: String?
    var metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case order
        case type
        case subtype
        case label
        case allow_multiple
        case error_message
        case required
        case options
        case clickable_text_color
        case max_length
        case placeholder
        case default_value
        case default_values
        case supporting_text
        case supportingText
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? Int.max
        type = try container.decodeIfPresent(FieldType.self, forKey: .type) ?? .unknown("MISSING")
        subtype = try container.decodeIfPresent(Subtype.self, forKey: .subtype)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? id
        allow_multiple = try container.decodeIfPresent(Bool.self, forKey: .allow_multiple) ?? false
        error_message = try container.decodeIfPresent(String.self, forKey: .error_message)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        options = try container.decodeIfPresent([OptionField].self, forKey: .options) ?? []
        clickable_text_color = try container.decodeIfPresent(String.self, forKey: .clickable_text_color)
        if let decodedMaxLength = try container.decodeIfPresent(Int.self, forKey: .max_length), decodedMaxLength > 0 {
            max_length = decodedMaxLength
        } else {
            max_length = nil
        }
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        default_value = try container.decodeIfPresent(FieldDefaultValue.self, forKey: .default_value)
        default_values = try container.decodeIfPresent([String].self, forKey: .default_values) ?? []
        supporting_text = try container.decodeIfPresent(String.self, forKey: .supporting_text)
            ?? container.decodeIfPresent(String.self, forKey: .supportingText)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    var clickableTextColor: Color {
        Color.formHex(clickable_text_color, fallback: Color(red: 0.55, green: 0.8, blue: 1.0))
    }
}

extension Color {
    static func formHex(_ value: String?, fallback: Color) -> Color {
        guard var hex = value?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
            return fallback
        }

        hex = hex
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "Е", with: "E")
            .replacingOccurrences(of: "е", with: "e")
            .uppercased()

        let hexDigits = CharacterSet(charactersIn: "0123456789ABCDEF")

        guard [6, 8].contains(hex.count),
              CharacterSet(charactersIn: hex).isSubset(of: hexDigits) else {
            return fallback
        }

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        if hex.count == 8 {
            red = (int >> 24) & 0xff
            green = (int >> 16) & 0xff
            blue = (int >> 8) & 0xff
            alpha = int & 0xff
        } else {
            red = (int >> 16) & 0xff
            green = (int >> 8) & 0xff
            blue = int & 0xff
            alpha = 255
        }

        return Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
