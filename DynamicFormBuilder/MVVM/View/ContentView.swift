//
//  ContentView.swift
//  DynamicFormBuilder
//
//  Created by prit on 27/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DynamicFormViewModel()
    @FocusState private var focusedFieldID: String?
    @State private var hasAppeared = false

    var body: some View {
        Group {
            if let uiElements = viewModel.uiElements {
                formView(for: uiElements)
            } else if let loadError = viewModel.loadError {
                loadErrorView(loadError)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.07))
            }
        }
        .task {
            viewModel.loadFormIfNeeded()
        }
        .alert("Campaign setup is ready", isPresented: $viewModel.showConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Final key-value pairs were printed.")
        }
    }
}

// MARK: - Layout

private extension ContentView {
    func formView(for elements: UIElements) -> some View {
        let theme = elements.theme
        let accent = viewModel.fieldAccentColor(elements)

        return ZStack(alignment: .top) {
            backgroundLayer(theme: theme, accent: accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    formHeader(elements, theme: theme, accent: accent)

                    ForEach(Array(elements.renderableFields.enumerated()), id: \.element.id) { index, field in
                        fieldSection(field, theme: theme, accent: accent)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 14)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.85)
                                    .delay(Double(index) * 0.045),
                                value: hasAppeared
                            )
                    }

                    submitSection(elements, theme: theme, accent: accent)
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(
                            .easeOut(duration: 0.4)
                                .delay(Double(elements.renderableFields.count) * 0.045 + 0.05),
                            value: hasAppeared
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .toolbar {
            keyboardToolbar(accent: accent)
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    func backgroundLayer(theme: Theme, accent: Color) -> some View {
        ZStack {
            theme.backgroundColor

            LinearGradient(
                colors: [
                    accent.opacity(0.14),
                    accent.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    func formHeader(_ elements: UIElements, theme: Theme, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server-Driven Form")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(accent)

            Text(elements.form_title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Capsule()
                    .fill(accent)
                    .frame(width: 40, height: 4)
                Capsule()
                    .fill(accent.opacity(0.4))
                    .frame(width: 16, height: 4)
                Capsule()
                    .fill(accent.opacity(0.18))
                    .frame(width: 8, height: 4)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Field section

private extension ContentView {
    @ViewBuilder
    func fieldSection(_ field: Field, theme: Theme, accent: Color) -> some View {
        let errorMessage = viewModel.validationMessage(for: field)

        VStack(alignment: .leading, spacing: 12) {
            if !controlEmbedsLabel(for: field) {
                fieldLabel(field, theme: theme, accent: accent)
            }

            controlView(for: field, theme: theme, accent: accent)

            if let supportingText = field.supporting_text, !supportingText.isEmpty {
                Text(supportingText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textColor.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if field.type == .text, let maxLength = field.max_length {
                characterCountIndicator(field: field, max: maxLength, theme: theme, accent: accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.errorColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background {
            LinearGradient(
                colors: [
                    theme.textColor.opacity(0.07),
                    theme.textColor.opacity(0.025)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [theme.textColor.opacity(0.18), theme.textColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
            .padding(.horizontal, 1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(errorMessage == nil ? theme.borderColor : theme.errorColor, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: errorMessage)
    }

    func fieldLabel(_ field: Field, theme: Theme, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: iconName(for: field))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18)

            Text(field.label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)

            if field.required {
                Text("*")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.errorColor)
            }
        }
    }

    func controlEmbedsLabel(for field: Field) -> Bool {
        switch field.type {
        case .checkbox, .toggle:
            return true
        default:
            return false
        }
    }

    func iconName(for field: Field) -> String {
        switch field.type {
        case .text:
            switch field.subtype {
            case .secure: return "lock.fill"
            case .number: return "number"
            case .uri: return "link"
            case .multiline: return "text.alignleft"
            default: return "textformat"
            }
        case .dropdown:
            return field.allow_multiple ? "checklist" : "chevron.down.circle"
        case .toggle:
            return "switch.2"
        case .checkbox:
            return "checkmark.square"
        case .colorPicker:
            return "paintpalette.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Controls

private extension ContentView {
    @ViewBuilder
    func controlView(for field: Field, theme: Theme, accent: Color) -> some View {
        switch field.type {
        case .text:
            textInput(for: field, theme: theme, accent: accent)
        case .dropdown:
            dropdownInput(for: field, theme: theme, accent: accent)
        case .checkbox:
            checkboxInput(for: field, theme: theme, accent: accent)
        case .colorPicker:
            colorInput(for: field, theme: theme)
        case .toggle:
            toggleInput(for: field, theme: theme, accent: accent)
        case .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    func textInput(for field: Field, theme: Theme, accent: Color) -> some View {
        if field.subtype == .multiline {
            multilineTextInput(for: field, theme: theme, accent: accent)
        } else {
            singleLineTextInput(for: field, theme: theme, accent: accent)
        }
    }

    @ViewBuilder
    func singleLineTextInput(for field: Field, theme: Theme, accent: Color) -> some View {
        let isFocused = focusedFieldID == field.id

        Group {
            switch field.subtype {
            case .secure:
                SecureField("", text: textBinding(for: field), prompt: promptText(for: field, fallback: "Password"))
                    .textContentType(.password)
            case .number:
                TextField("", text: textBinding(for: field), prompt: promptText(for: field, fallback: "0.00"))
                    .keyboardType(.decimalPad)
            case .uri:
                TextField("", text: textBinding(for: field), prompt: promptText(for: field, fallback: "https://"))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .plain, .multiline, .unknown, .none:
                TextField("", text: textBinding(for: field), prompt: promptText(for: field, fallback: field.label))
            }
        }
        .focused($focusedFieldID, equals: field.id)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textColor)
        .tint(accent)
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? accent : theme.borderColor, lineWidth: isFocused ? 1.6 : 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }

    func multilineTextInput(for field: Field, theme: Theme, accent: Color) -> some View {
        let isFocused = focusedFieldID == field.id

        return ZStack(alignment: .topLeading) {
            TextEditor(text: textBinding(for: field))
                .focused($focusedFieldID, equals: field.id)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textColor)
                .tint(accent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 112)

            if viewModel.textValues[field.id, default: ""].isEmpty {
                Text(field.placeholder ?? field.label)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textColor.opacity(0.38))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? accent : theme.borderColor, lineWidth: isFocused ? 1.6 : 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }

    @ViewBuilder
    func dropdownInput(for field: Field, theme: Theme, accent: Color) -> some View {
        if field.options.isEmpty {
            emptyDropdownPlaceholder(theme: theme)
        } else if field.allow_multiple {
            multiSelectDropdown(field: field, theme: theme, accent: accent)
        } else {
            singleSelectDropdown(field: field, theme: theme, accent: accent)
        }
    }

    func emptyDropdownPlaceholder(theme: Theme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
            Text("No options available")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textColor.opacity(0.55))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    func multiSelectDropdown(field: Field, theme: Theme, accent: Color) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
            ForEach(field.options) { option in
                let isSelected = viewModel.selectedOptions[field.id, default: []].contains(option.id)

                Button {
                    viewModel.toggleOption(option, for: field)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? accent : theme.textColor.opacity(0.45))

                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textColor)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(
                        isSelected ? accent.opacity(0.18) : theme.backgroundColor.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? accent : theme.borderColor, lineWidth: isSelected ? 1.4 : 1)
                    }
                }
                .buttonStyle(ChipButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
            }
        }
    }

    func singleSelectDropdown(field: Field, theme: Theme, accent: Color) -> some View {
        Menu {
            ForEach(field.options) { option in
                Button(option.label) {
                    viewModel.selectSingleOption(option, for: field)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(viewModel.selectedOptionLabel(for: field) ?? "Select \(field.label)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(viewModel.selectedOptionLabel(for: field) == nil ? theme.textColor.opacity(0.55) : theme.textColor)
                    .lineLimit(2)

                Spacer(minLength: 12)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    func checkboxInput(for field: Field, theme: Theme, accent: Color) -> some View {
        let isChecked = viewModel.checkboxValues[field.id, default: false]

        return HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.updateCheckbox(!isChecked, for: field)
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(isChecked ? field.clickableTextColor : theme.textColor.opacity(0.6))
                    .frame(width: 28)
                    .scaleEffect(isChecked ? 1.0 : 0.94)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isChecked)
            }
            .buttonStyle(.plain)

            Text(attributedLabel(for: field, theme: theme))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textColor)
                .tint(field.clickableTextColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.updateCheckbox(!isChecked, for: field)
                }
        }
        .padding(.vertical, 4)
    }

    func colorInput(for field: Field, theme: Theme) -> some View {
        let color = colorBinding(for: field)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.wrappedValue)
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.borderColor, lineWidth: 1)
                }
                .shadow(color: color.wrappedValue.opacity(0.45), radius: 10)
                .animation(.easeInOut(duration: 0.2), value: color.wrappedValue)

            Spacer()

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .tint(field.clickableTextColor)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    func toggleInput(for field: Field, theme: Theme, accent: Color) -> some View {
        Toggle(isOn: toggleBinding(for: field)) {
            HStack(spacing: 4) {
                Text(field.label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .fixedSize(horizontal: false, vertical: true)

                if field.required {
                    Text("*")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.errorColor)
                }
            }
        }
        .tint(accent)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }
}

// MARK: - Submit + supporting views

private extension ContentView {
    func submitSection(_ elements: UIElements, theme: Theme, accent: Color) -> some View {
        let didSucceed = viewModel.didSubmitSuccessfully

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                viewModel.submit(elements)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: didSucceed ? "checkmark.circle.fill" : "paperplane.fill")
                        .imageScale(.medium)
                    Text(didSucceed ? "Saved" : "Save")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: didSucceed
                            ? [Color.green, Color.green.opacity(0.85)]
                            : [accent, accent.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .shadow(color: (didSucceed ? Color.green : accent).opacity(0.4), radius: 12, y: 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: didSucceed)
            }
            .buttonStyle(SubmitButtonStyle())

            if viewModel.submitted && !viewModel.didSubmitSuccessfully {
                Label("Review required fields.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.errorColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.2), value: viewModel.submitted)
    }

    func characterCountIndicator(field: Field, max maxLength: Int, theme: Theme, accent: Color) -> some View {
        let current = viewModel.textValues[field.id, default: ""].count
        let progress = min(1.0, Double(current) / Double(maxLength))
        let isWarn = progress >= 0.85
        let ringColor = isWarn ? theme.errorColor : accent

        return HStack(spacing: 7) {
            Text("\(current)/\(maxLength)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWarn ? theme.errorColor : theme.textColor.opacity(0.55))

            ZStack {
                Circle()
                    .stroke(theme.textColor.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.18), value: progress)
            }
            .frame(width: 14, height: 14)
        }
    }

    func attributedLabel(for field: Field, theme: Theme) -> AttributedString {
        var attributed = AttributedString(field.label)

        // Stable iteration order so a longer key that contains another
        // key (e.g. "Privacy Policy" vs "Policy") still gets matched first.
        let sortedKeys = field.metadata.keys.sorted { $0.count > $1.count }

        for key in sortedKeys {
            guard let urlString = field.metadata[key],
                  let url = URL(string: urlString),
                  let range = attributed.range(of: key) else {
                continue
            }
            attributed[range].link = url
            attributed[range].font = .system(size: 15, weight: .semibold, design: .rounded)
        }

        if field.required {
            var asterisk = AttributedString(" *")
            asterisk.font = .system(size: 15, weight: .bold, design: .rounded)
            asterisk.foregroundColor = theme.errorColor
            attributed.append(asterisk)
        }

        return attributed
    }

    func promptText(for field: Field, fallback: String) -> Text {
        Text(field.placeholder ?? fallback)
    }

    func loadErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .bold))

            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
    }
}

// MARK: - Keyboard toolbar (Dynamic Focus Management)

private extension ContentView {
    var textFieldOrder: [String] {
        viewModel.uiElements?.renderableFields
            .filter { $0.type == .text }
            .map(\.id) ?? []
    }

    @ToolbarContentBuilder
    func keyboardToolbar(accent: Color) -> some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button {
                moveFocus(direction: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMoveFocus(direction: -1))

            Button {
                moveFocus(direction: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveFocus(direction: 1))

            Spacer()

            Button("Done") {
                focusedFieldID = nil
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
        }
    }

    func canMoveFocus(direction: Int) -> Bool {
        guard let current = focusedFieldID, let idx = textFieldOrder.firstIndex(of: current) else {
            return false
        }
        let next = idx + direction
        return next >= 0 && next < textFieldOrder.count
    }

    func moveFocus(direction: Int) {
        guard let current = focusedFieldID, let idx = textFieldOrder.firstIndex(of: current) else {
            return
        }
        let next = idx + direction
        guard next >= 0 && next < textFieldOrder.count else { return }
        focusedFieldID = textFieldOrder[next]
    }
}

// MARK: - Bindings

private extension ContentView {
    func textBinding(for field: Field) -> Binding<String> {
        Binding {
            viewModel.textValues[field.id, default: ""]
        } set: { newValue in
            viewModel.updateText(newValue, for: field)
        }
    }

    func toggleBinding(for field: Field) -> Binding<Bool> {
        Binding {
            viewModel.toggleValues[field.id, default: false]
        } set: { newValue in
            viewModel.updateToggle(newValue, for: field)
        }
    }

    func colorBinding(for field: Field) -> Binding<Color> {
        Binding {
            viewModel.colorValues[field.id, default: viewModel.fallbackAccentColor]
        } set: { newValue in
            viewModel.updateColor(newValue, for: field)
        }
    }
}

// MARK: - Button styles

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct SubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
