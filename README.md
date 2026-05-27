# Dynamic Form Builder

Single-screen SwiftUI app that renders a server-driven form from a local `UI.json` file bundled with the app.

## Approach

The app decodes the payload with `Codable`, sorts fields by `order`, and renders SwiftUI controls based on each field's decoded type. `ContentView` is responsible for presentation, while `DynamicFormViewModel` owns form state, default values, validation, and final submission output.

Supported components:

- `TEXT`: `PLAIN`, `MULTILINE`, `NUMBER`, `URI`/`URL`, and `SECURE`
- `DROPDOWN`: single-select and multi-select, storing selected option ids
- `TOGGLE`
- `CHECKBOX`, including optional metadata links
- `COLOR_PICKER`

The app is fully offline and reads only from the app bundle.

## Product Decisions

- Unknown field types are ignored instead of rendered so malformed or future payload fields do not break the form.
- Unknown text subtypes fall back to a standard single-line text field, which preserves user input while keeping decoding resilient.
- Required dropdowns with empty option arrays remain invalid and show the field error, because the user cannot provide a valid value.
- Negative or zero `max_length` values are treated as missing constraints.

## More Time

- Add XCTest coverage for decoder edge cases and malformed payloads.
- Add regex validation support for optional text patterns.
- Add focus management with a keyboard toolbar for dynamic text fields.
- Render checkbox metadata as inline attributed text instead of separate links.

## Notes

On successful save, final key-value pairs are printed to the Xcode console and a confirmation alert is shown.
