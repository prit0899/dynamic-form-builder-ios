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
- Required dropdowns with empty option arrays are treated as effectively optional at runtime. The schema is contradicting itself (`required: true` plus `options: []`), and the user cannot choose a value that does not exist, so blocking submission would only deadlock them. The field is rendered with a "No options available" placeholder so the empty state is visible, the submitted payload records an empty selection, and the server is the right place to enforce business rules about whether that is acceptable. Adding a fake placeholder option client-side was rejected because it would corrupt the payload — downstream code could not tell a real selection from a synthesised one.
- `URI` text fields are validated for an `http`/`https` scheme and a dotted host on submit; format errors surface their own message rather than the field's generic required-field copy.
- Negative or zero `max_length` values are treated as missing constraints.
- Toggle and checkbox cards omit the shared card header because those SwiftUI controls already render the field label inline.

## Testing

XCTest target `DynamicFormBuilderTests` covers the parts of the app that
contain real logic — the polymorphic `Codable` decoder and the form
state machine. The SwiftUI view layer is intentionally not unit-tested;
its correctness is verified manually via the demo recording, since
ViewInspector/snapshot harnesses would add more brittleness than signal
for a single-screen form.

Targeted coverage:

| Layer | Coverage target | Over All ~75%
|---|---|
| Decoder (`Theme.swift`, `ViewType.swift`) | ~95% |
| ViewModel (`DynamicFormViewModel.swift`) | ~65% |
| View (`ContentView.swift`) | ~82% |

Run the suite:

```sh
xcodebuild test \
  -project DynamicFormBuilder.xcodeproj \
  -scheme DynamicFormBuilder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

What is covered today (in `DecoderTests`):

1. All supported field types (`TEXT`, `DROPDOWN`, `TOGGLE`, `CHECKBOX`, `COLOR_PICKER`) decode to the right `FieldType` case.
2. All text subtypes (`PLAIN`, `MULTILINE`, `NUMBER`, `URI`, `SECURE`) decode to the right `Subtype` case.
3. `"URL"` is accepted as an alias for `"URI"` in the subtype field.
4. An unknown `type` (e.g. `"DATE_PICKER"`) decodes as `.unknown("DATE_PICKER")` rather than throwing.
5. An unknown text `subtype` decodes as `.unknown(...)` rather than throwing.
6. `renderableFields` filters unknown-type fields out before the UI sees them.

## More Time

- Expand the suite to cover the view model (validation, default-value seeding, URL format check, empty-options dropdown behaviour, max-length clamping).
- Add regex validation support for optional text patterns from the JSON.

## Notes

On successful save, final key-value pairs are printed to the Xcode console and a confirmation alert is shown.
