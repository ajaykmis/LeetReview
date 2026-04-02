import SwiftUI

/// A reusable code block component with monospaced text display, dark background,
/// optional language label, and copy button.
struct CodeBlock: View {
    let code: String
    var language: String?
    var showCopyButton: Bool = false
    var onCopy: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar with language label and copy button
            if language != nil || showCopyButton {
                headerBar
            }

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.Colors.text)
                    .textSelection(.enabled)
                    .padding(Theme.Spacing.md)
            }
        }
        .background(codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Header Bar

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            if let language {
                Text(language)
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
            }

            Spacer()

            if showCopyButton {
                Button {
                    onCopy?()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                        Text("Copy")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.card.opacity(0.5))
    }

    // MARK: - Code Background

    private var codeBackground: Color {
        Theme.Colors.background
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.Colors.background.ignoresSafeArea()

        VStack(spacing: Theme.Spacing.lg) {
            CodeBlock(
                code: """
                func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
                    var map: [Int: Int] = [:]
                    for (i, num) in nums.enumerated() {
                        if let j = map[target - num] {
                            return [j, i]
                        }
                        map[num] = i
                    }
                    return []
                }
                """,
                language: "Swift",
                showCopyButton: true,
                onCopy: { print("Copied!") }
            )

            CodeBlock(
                code: "print(\"Hello, World!\")",
                language: "Python"
            )

            CodeBlock(
                code: "console.log('No header bar')"
            )
        }
        .padding()
    }
}
