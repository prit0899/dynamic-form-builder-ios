//
//  DynamicFormViewModel.swift
//  Serverless
//
//  Created by prit on 27/05/26.
//

import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DynamicFormViewModel: ObservableObject {
    @Published var uiElements: UIElements?
    @Published var loadError: String?
    @Published var textValues: [String: String] = [:]
    @Published var toggleValues: [String: Bool] = [:]
    @Published var checkboxValues: [String: Bool] = [:]
    @Published var selectedOptions: [String: Set<String>] = [:]
    @Published var colorValues: [String: Color] = [:]
    @Published var submitted = false
    @Published var didSubmitSuccessfully = false
    @Published var showConfirmation = false

    let fallbackAccentColor = Color(red: 0.13, green: 0.56, blue: 0.9)

    func loadFormIfNeeded() {
        guard uiElements == nil else {
            return
        }

        do {
            let elements = try UIElements.loadFromBundle()
            seedValues(from: elements)
            uiElements = elements
        } catch {
            loadError = error.localizedDescription
        }
    }

    func seedValues(from elements: UIElements) {
        for field in elements.renderableFields {
            switch field.type {
            case .text:
                updateText(field.default_value?.stringValue ?? "", for: field)
            case .toggle:
                toggleValues[field.id] = field.default_value?.boolValue ?? false
            case .checkbox:
                checkboxValues[field.id] = field.default_value?.boolValue ?? false
            case .dropdown:
                seedDropdownValue(for: field)
            case .colorPicker:
                colorValues[field.id] = Color.formHex(field.default_value?.stringValue, fallback: fallbackAccentColor)
            case .unknown:
                break
            }
        }
    }

    func updateText(_ newValue: String, for field: Field) {
        var value = newValue

        if field.subtype == .number {
            value = value.filter { "0123456789.".contains($0) }
        }

        textValues[field.id] = limited(value, to: field.max_length)
        didSubmitSuccessfully = false
    }

    func updateToggle(_ newValue: Bool, for field: Field) {
        toggleValues[field.id] = newValue
        didSubmitSuccessfully = false
    }

    func updateCheckbox(_ newValue: Bool, for field: Field) {
        checkboxValues[field.id] = newValue
        didSubmitSuccessfully = false
    }

    func updateColor(_ newValue: Color, for field: Field) {
        colorValues[field.id] = newValue
        didSubmitSuccessfully = false
    }

    func selectSingleOption(_ option: OptionField, for field: Field) {
        selectedOptions[field.id] = [option.id]
        didSubmitSuccessfully = false
    }

    func toggleOption(_ option: OptionField, for field: Field) {
        var selection = selectedOptions[field.id, default: []]

        if selection.contains(option.id) {
            selection.remove(option.id)
        } else {
            selection.insert(option.id)
        }

        selectedOptions[field.id] = selection
        didSubmitSuccessfully = false
    }

    func validationMessage(for field: Field) -> String? {
        guard submitted else {
            return nil
        }

        if isMissingRequiredValue(for: field) {
            return field.error_message ?? "This field is required."
        }

        if hasInvalidFormat(for: field) {
            return invalidFormatMessage(for: field)
        }

        return nil
    }

    func isMissingRequiredValue(for field: Field) -> Bool {
        guard field.required else {
            return false
        }

        switch field.type {
        case .text:
            return textValues[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dropdown:
            // When the JSON marks a dropdown as required but ships no options,
            // the schema contradicts itself: the user cannot select a value
            // that does not exist. Honour the data (no options) over the
            // schema (required) so the form is not deadlocked, and let the
            // server enforce business rules over the empty submitted value.
            guard !field.options.isEmpty else {
                return false
            }
            return selectedOptions[field.id, default: []].isEmpty
        case .checkbox:
            return checkboxValues[field.id, default: false] == false
        case .toggle, .colorPicker, .unknown:
            return false
        }
    }

    func hasInvalidFormat(for field: Field) -> Bool {
        guard field.type == .text, field.subtype == .uri else {
            return false
        }

        let value = textValues[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty values are handled by the required check; an empty optional
        // URI field is fine.
        guard !value.isEmpty else {
            return false
        }

        return !isValidURL(value)
    }

    func invalidFormatMessage(for field: Field) -> String {
        switch field.subtype {
        case .uri:
            return "Enter a valid URL (e.g. https://example.com)."
        default:
            return "Invalid value."
        }
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              // Require at least one dot in the host so single-label inputs
              // like "https://abc" do not pass.
              host.contains(".") else {
            return false
        }

        return true
    }

    func selectedOptionLabel(for field: Field) -> String? {
        guard let selectedID = selectedOptions[field.id]?.first else {
            return nil
        }

        return field.options.first { $0.id == selectedID }?.label
    }

    func submit(_ elements: UIElements) {
        withAnimation(.easeInOut(duration: 0.2)) {
            submitted = true
            didSubmitSuccessfully = elements.renderableFields.allSatisfy {
                !isMissingRequiredValue(for: $0) && !hasInvalidFormat(for: $0)
            }
        }

        guard didSubmitSuccessfully else {
            triggerHaptic(.error)
            return
        }

        triggerHaptic(.success)
        printFinalPayload(for: elements)
        showConfirmation = true
    }

    private func triggerHaptic(_ type: HapticType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .error:
            generator.notificationOccurred(.error)
        }
        #endif
    }

    private enum HapticType {
        case success
        case error
    }

    func fieldAccentColor(_ elements: UIElements) -> Color {
        if let brandField = elements.fields.first(where: { $0.type == .colorPicker }) {
            return colorValues[brandField.id, default: fallbackAccentColor]
        }

        return fallbackAccentColor
    }

    func limited(_ value: String, to maxLength: Int?) -> String {
        guard let maxLength, value.count > maxLength else {
            return value
        }

        return String(value.prefix(maxLength))
    }

    private func seedDropdownValue(for field: Field) {
        let optionIDs = Set(field.options.map(\.id))
        var defaults = field.default_values

        if let singleDefault = field.default_value?.stringValue {
            defaults.append(singleDefault)
        }

        if optionIDs.isEmpty {
            selectedOptions[field.id] = []
        } else {
            selectedOptions[field.id] = Set(defaults.filter { optionIDs.contains($0) })
        }
    }

    private func printFinalPayload(for elements: UIElements) {
        print("Final form values:")

        for field in elements.renderableFields {
            print("\(field.id): \(printableValue(for: field))")
        }
    }

    private func printableValue(for field: Field) -> Any {
        switch field.type {
        case .text:
            return textValues[field.id, default: ""]
        case .dropdown:
            let values = selectedOptions[field.id, default: []].sorted()
            return field.allow_multiple ? values : (values.first ?? "")
        case .toggle:
            return toggleValues[field.id, default: false]
        case .checkbox:
            return checkboxValues[field.id, default: false]
        case .colorPicker:
            return colorValues[field.id, default: fallbackAccentColor].hexString
        case .unknown:
            return ""
        }
    }
}

private extension Color {
    var hexString: String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(
                format: "#%02X%02X%02X",
                Int(red * 255),
                Int(green * 255),
                Int(blue * 255)
            )
        }
        #endif

        return "#000000"
    }
}
