//
//  ContentView.swift
//  ServerlessApp
//
//  Created by prit on 27/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DynamicFormViewModel()

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
            Text("Final key-value pairs were printed to the Xcode console.")
        }
    }
}

private extension ContentView {
    func formView(for elements: UIElements) -> some View {
        ZStack {
            elements.theme.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    formHeader(elements, theme: elements.theme)

                    ForEach(elements.renderableFields) { field in
                        fieldSection(field, theme: elements.theme)
                    }

                    submitSection(elements, theme: elements.theme)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    func formHeader(_ elements: UIElements, theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(elements.form_title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(viewModel.fieldAccentColor(elements))
                .frame(width: 56, height: 3)
                .clipShape(Capsule())
        }
        .padding(.bottom, 8)
    }

    func fieldSection(_ field: Field, theme: Theme) -> some View {
        let errorMessage = viewModel.validationMessage(for: field)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
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

            controlView(for: field, theme: theme)

            if let supportingText = field.supporting_text, !supportingText.isEmpty {
                Text(supportingText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textColor.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if field.type == .text, let maxLength = field.max_length {
                Text("\(viewModel.textValues[field.id, default: ""].count)/\(maxLength)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textColor.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.errorColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(theme.textColor.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(errorMessage == nil ? theme.borderColor : theme.errorColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    func controlView(for field: Field, theme: Theme) -> some View {
        switch field.type {
        case .text:
            textInput(for: field, theme: theme)
        case .dropdown:
            dropdownInput(for: field, theme: theme)
        case .checkbox:
            checkboxInput(for: field, theme: theme)
        case .colorPicker:
            colorInput(for: field, theme: theme)
        case .toggle:
            toggleInput(for: field, theme: theme)
        case .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    func textInput(for field: Field, theme: Theme) -> some View {
        if field.subtype == .multiline {
            multilineTextInput(for: field, theme: theme)
        } else {
            singleLineTextInput(for: field, theme: theme)
        }
    }

    @ViewBuilder
    func singleLineTextInput(for field: Field, theme: Theme) -> some View {
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
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textColor)
        .tint(field.clickableTextColor)
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    func multilineTextInput(for field: Field, theme: Theme) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: textBinding(for: field))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textColor)
                .tint(field.clickableTextColor)
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
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    func dropdownInput(for field: Field, theme: Theme) -> some View {
        if field.options.isEmpty {
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
        } else if field.allow_multiple {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                ForEach(field.options) { option in
                    let isSelected = viewModel.selectedOptions[field.id, default: []].contains(option.id)

                    Button {
                        viewModel.toggleOption(option, for: field)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? field.clickableTextColor : theme.textColor.opacity(0.45))

                            Text(option.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.textColor)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(isSelected ? field.clickableTextColor.opacity(0.16) : theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? field.clickableTextColor : theme.borderColor, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
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
                        .foregroundStyle(field.clickableTextColor)
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
    }

    func checkboxInput(for field: Field, theme: Theme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.updateCheckbox(!viewModel.checkboxValues[field.id, default: false], for: field)
            } label: {
                Image(systemName: viewModel.checkboxValues[field.id, default: false] ? "checkmark.square.fill" : "square")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(viewModel.checkboxValues[field.id, default: false] ? field.clickableTextColor : theme.textColor.opacity(0.6))
                    .frame(width: 28)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    viewModel.updateCheckbox(!viewModel.checkboxValues[field.id, default: false], for: field)
                } label: {
                    Text(field.label)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)

                if !field.metadata.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        metadataLinks(for: field)

                        VStack(alignment: .leading, spacing: 7) {
                            metadataLinks(for: field)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
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

    func toggleInput(for field: Field, theme: Theme) -> some View {
        Toggle(isOn: toggleBinding(for: field)) {
            Text(field.label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(field.clickableTextColor)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(theme.backgroundColor.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    func submitSection(_ elements: UIElements, theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                viewModel.submit(elements)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                    Text("Save")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(viewModel.fieldAccentColor(elements), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.submitted && !viewModel.didSubmitSuccessfully {
                Label("Review required fields.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.errorColor)
            }
        }
        .padding(.top, 4)
    }

    func metadataLinks(for field: Field) -> some View {
        HStack(spacing: 12) {
            ForEach(field.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                if let url = URL(string: item.value) {
                    Link(item.key, destination: url)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(field.clickableTextColor)
                }
            }
        }
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

#Preview {
    ContentView()
}
