//
//  DynamicFormBuilderTests.swift
//  DynamicFormBuilderTests
//
//  Created by prit on 28/05/26.
//

import XCTest
@testable import DynamicFormBuilder

// MARK: - DecoderTests
//
// Verifies that the JSON -> UIElements pipeline maps the polymorphic
// `type` and `subtype` fields correctly and stays defensive against
// payloads that contain unknown values. This is the "Unit Tests for
// Polymorphic Parsing" optional enhancement called out by the brief.

final class DecoderTests: XCTestCase {

    // MARK: Helpers

    /// Decode a JSON string into a `UIElements`. Throws if decoding fails,
    /// so the call site can rely on either receiving a value or having the
    /// test fail with the underlying decoding error.
    private func decode(_ json: String) throws -> UIElements {
        try JSONDecoder().decode(UIElements.self, from: Data(json.utf8))
    }

    /// A theme block that satisfies the `theme` requirement on every
    /// payload; the colour values themselves are not asserted in this file.
    private let themeBlock = """
    "theme": {
        "background_color": "#000000",
        "text_color": "#FFFFFF",
        "border_color": "#888888",
        "error_color": "#FF0000"
    }
    """

    // MARK: 1. All supported field types decode to their FieldType cases

    func test_decodesAllSupportedFieldTypes() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Types",
            "fields": [
                {"id": "t", "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "T"},
                {"id": "d", "order": 2, "type": "DROPDOWN", "label": "D"},
                {"id": "g", "order": 3, "type": "TOGGLE", "label": "G"},
                {"id": "c", "order": 4, "type": "CHECKBOX", "label": "C"},
                {"id": "p", "order": 5, "type": "COLOR_PICKER", "label": "P"}
            ]
        }
        """

        let model = try decode(json)
        let types = model.fields.map { $0.type }

        XCTAssertEqual(types, [.text, .dropdown, .toggle, .checkbox, .colorPicker])
    }

    // MARK: 2. All text subtypes decode to their Subtype cases

    func test_decodesAllTextSubtypes() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Subtypes",
            "fields": [
                {"id": "a", "order": 1, "type": "TEXT", "subtype": "PLAIN",     "label": "A"},
                {"id": "b", "order": 2, "type": "TEXT", "subtype": "MULTILINE", "label": "B"},
                {"id": "c", "order": 3, "type": "TEXT", "subtype": "NUMBER",    "label": "C"},
                {"id": "d", "order": 4, "type": "TEXT", "subtype": "URI",       "label": "D"},
                {"id": "e", "order": 5, "type": "TEXT", "subtype": "SECURE",    "label": "E"}
            ]
        }
        """

        let model = try decode(json)
        let subtypes = model.fields.compactMap(\.subtype)

        XCTAssertEqual(subtypes, [.plain, .multiline, .number, .uri, .secure])
    }

    // MARK: 3. "URL" is accepted as an alias for "URI"
    //
    // The brief uses "URI" but the all-in-one fixture happens to use
    // "URL". The decoder treats both as the same subtype.

    func test_subtypeURLAliasIsAcceptedAsURI() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Alias",
            "fields": [
                {"id": "u", "order": 1, "type": "TEXT", "subtype": "URL", "label": "URL"}
            ]
        }
        """

        let model = try decode(json)

        XCTAssertEqual(model.fields.first?.subtype, .uri)
    }

    // MARK: 4. Unknown field type decodes as .unknown (defensive parsing)

    func test_unknownFieldTypeDecodesAsUnknownCase() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Unknown type",
            "fields": [
                {"id": "x", "order": 1, "type": "DATE_PICKER", "label": "X"}
            ]
        }
        """

        // The whole payload must still decode successfully - an unknown
        // type is not a hard error.
        let model = try decode(json)

        XCTAssertEqual(model.fields.first?.type, .unknown("DATE_PICKER"))
    }

    // MARK: 5. Unknown text subtype decodes as .unknown (defensive parsing)

    func test_unknownTextSubtypeDecodesAsUnknownCase() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Unknown subtype",
            "fields": [
                {"id": "x", "order": 1, "type": "TEXT", "subtype": "RICHTEXT", "label": "X"}
            ]
        }
        """

        let model = try decode(json)

        XCTAssertEqual(model.fields.first?.subtype, .unknown("RICHTEXT"))
    }

    // MARK: 6. renderableFields filters out unknown types

    func test_renderableFieldsExcludesUnknownTypes() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Renderable filter",
            "fields": [
                {"id": "ok",  "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "OK"},
                {"id": "bad", "order": 2, "type": "DATE_PICKER",              "label": "Bad"}
            ]
        }
        """

        let model = try decode(json)

        // Both fields should decode (defensive parsing keeps the data),
        // but renderableFields drops the unknown so the UI never sees it.
        XCTAssertEqual(model.fields.count, 2)
        XCTAssertEqual(model.renderableFields.count, 1)
        XCTAssertEqual(model.renderableFields.first?.id, "ok")
    }

    // MARK: 7. orderedFields sorts by `order` integer, not array index
    //
    // The brief specifically calls this out: "Sort components based on
    // their order integer before rendering. Do not rely on array indexes."

    func test_orderedFieldsSortsByOrderInteger() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Ordering",
            "fields": [
                {"id": "c", "order": 3, "type": "TEXT", "subtype": "PLAIN", "label": "C"},
                {"id": "a", "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "A"},
                {"id": "b", "order": 2, "type": "TEXT", "subtype": "PLAIN", "label": "B"}
            ]
        }
        """

        let model = try decode(json)

        XCTAssertEqual(model.orderedFields.map(\.id), ["a", "b", "c"])
    }

    // MARK: 8. Missing `fields` array decodes to empty, not throw

    func test_missingFieldsArrayDecodesAsEmpty() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "No fields key"
        }
        """

        let model = try decode(json)

        XCTAssertEqual(model.fields.count, 0)
        XCTAssertEqual(model.renderableFields.count, 0)
    }

    // MARK: 9. Missing `form_title` falls back to a default

    func test_missingFormTitleFallsBackToDefault() throws {
        let json = """
        {
            \(themeBlock),
            "fields": []
        }
        """

        let model = try decode(json)

        XCTAssertEqual(model.form_title, "Dynamic Form")
    }

    // MARK: 10. Negative or zero `max_length` is treated as no constraint
    //
    // The README's Product Decisions documents this: nonsensical max_length
    // values are coerced to nil so the UI does not block on `"" -> max(0)`
    // or behave strangely with a negative limit.

    func test_negativeOrZeroMaxLengthIsTreatedAsNil() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Max length",
            "fields": [
                {"id": "neg",  "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "Neg",  "max_length": -5},
                {"id": "zero", "order": 2, "type": "TEXT", "subtype": "PLAIN", "label": "Zero", "max_length": 0},
                {"id": "pos",  "order": 3, "type": "TEXT", "subtype": "PLAIN", "label": "Pos",  "max_length": 30}
            ]
        }
        """

        let model = try decode(json)
        let byID = Dictionary(uniqueKeysWithValues: model.fields.map { ($0.id, $0) })

        XCTAssertNil(byID["neg"]?.max_length)
        XCTAssertNil(byID["zero"]?.max_length)
        XCTAssertEqual(byID["pos"]?.max_length, 30)
    }

    // MARK: 11. Polymorphic default_value: string

    func test_polymorphicDefaultValueDecodesString() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Default string",
            "fields": [
                {"id": "f", "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "F", "default_value": "abc"}
            ]
        }
        """

        let model = try decode(json)
        let value = model.fields.first?.default_value

        XCTAssertEqual(value?.stringValue, "abc")
        XCTAssertNil(value?.boolValue)
    }

    // MARK: 12. Polymorphic default_value: bool

    func test_polymorphicDefaultValueDecodesBool() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Default bool",
            "fields": [
                {"id": "f", "order": 1, "type": "TOGGLE", "label": "F", "default_value": true}
            ]
        }
        """

        let model = try decode(json)
        let value = model.fields.first?.default_value

        XCTAssertEqual(value?.boolValue, true)
        // A bool default has no meaningful string representation - keep it
        // nil so seedValues for a text field cannot accidentally consume it.
        XCTAssertNil(value?.stringValue)
    }

    // MARK: 13. Polymorphic default_value: numeric (int + double)

    func test_polymorphicDefaultValueDecodesNumeric() throws {
        let json = """
        {
            \(themeBlock),
            "form_title": "Default numeric",
            "fields": [
                {"id": "i", "order": 1, "type": "TEXT", "subtype": "NUMBER", "label": "I", "default_value": 5},
                {"id": "d", "order": 2, "type": "TEXT", "subtype": "NUMBER", "label": "D", "default_value": 5.5}
            ]
        }
        """

        let model = try decode(json)
        let byID = Dictionary(uniqueKeysWithValues: model.fields.map { ($0.id, $0) })

        // Integers round-trip through `stringValue` without a trailing ".0".
        XCTAssertEqual(byID["i"]?.default_value?.stringValue, "5")
        // Doubles preserve their fractional part.
        XCTAssertEqual(byID["d"]?.default_value?.stringValue, "5.5")
    }

    // MARK: 14. Missing optional keys decode to safe defaults

    func test_missingOptionalKeysDecodeToSafeDefaults() throws {
        // Field with the absolute minimum keys - everything else is omitted.
        let json = """
        {
            \(themeBlock),
            "form_title": "Bare minimum",
            "fields": [
                {"id": "f", "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "F"}
            ]
        }
        """

        let model = try decode(json)
        let field = try XCTUnwrap(model.fields.first)

        XCTAssertEqual(field.metadata, [:])
        XCTAssertEqual(field.default_values, [])
        XCTAssertEqual(field.options.count, 0)
        XCTAssertNil(field.error_message)
        XCTAssertNil(field.placeholder)
        XCTAssertNil(field.default_value)
        XCTAssertNil(field.supporting_text)
        XCTAssertNil(field.max_length)
        XCTAssertNil(field.clickable_text_color)
        XCTAssertFalse(field.allow_multiple)
        XCTAssertFalse(field.required)
    }

    // MARK: 15. Smoke test: the bundled UI.json loads via loadFromBundle()

    func test_bundledUIJSONLoadsWithoutError() throws {
        // The test target is hosted by DynamicFormBuilder, so Bundle.main
        // resolves to the app bundle that contains UI.json.
        let model = try UIElements.loadFromBundle()

        XCTAssertFalse(model.fields.isEmpty, "Bundled UI.json should contain at least one field")
        XCTAssertFalse(model.renderableFields.isEmpty, "Bundled UI.json should contain at least one renderable field")
    }
}
