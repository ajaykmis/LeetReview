import SwiftUI
import UIKit

/// A syntax-highlighted code editor using UITextView with regex-based coloring,
/// line number gutter, and a coding keyboard toolbar.
struct HighlightedCodeEditor: UIViewRepresentable {
    @Binding var code: String
    let languageSlug: String
    let onFocusChange: ((Bool) -> Void)?

    init(code: Binding<String>, languageSlug: String, onFocusChange: ((Bool) -> Void)? = nil) {
        _code = code
        self.languageSlug = languageSlug
        self.onFocusChange = onFocusChange
    }

    func makeUIView(context: Context) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        container.textView.delegate = context.coordinator
        container.textView.text = code
        container.textView.inputAccessoryView = makeToolbar(for: container.textView, coordinator: context.coordinator)
        context.coordinator.containerView = container
        context.coordinator.applyHighlighting(to: container.textView, language: languageSlug)
        return container
    }

    func updateUIView(_ container: CodeEditorContainerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isUpdatingFromSwiftUI = true
        defer { coordinator.isUpdatingFromSwiftUI = false }

        if container.textView.text != code {
            let selectedRange = container.textView.selectedRange
            container.textView.text = code
            coordinator.applyHighlighting(to: container.textView, language: languageSlug)
            // Restore cursor if within bounds
            if selectedRange.location <= (code as NSString).length {
                container.textView.selectedRange = selectedRange
            }
        }

        coordinator.currentLanguage = languageSlug
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code, languageSlug: languageSlug, onFocusChange: onFocusChange)
    }

    // MARK: - Keyboard Toolbar

    private func makeToolbar(for textView: UITextView, coordinator: Coordinator) -> UIView {
        let rowHeight: CGFloat = 36
        let containerHeight: CGFloat = rowHeight * 2 + 8 + 0.5 // 2 rows + padding + separator
        let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: containerHeight))
        container.backgroundColor = UIColor(Theme.Colors.card)
        container.autoresizingMask = .flexibleWidth

        // Thin top separator line
        let separator = UIView()
        separator.backgroundColor = UIColor(Theme.Colors.textSecondary).withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        // Row 1: most common coding symbols
        let row1Keys: [(String, String)] = [
            ("TAB", "    "), ("{", "{"), ("}", "}"), ("(", "("), (")", ")"),
            ("[", "["), ("]", "]"), ("=", "="), (";", ";"), (":", ":"), (".", "."),
        ]

        // Row 2: operators, quotes, misc + undo/redo/done
        let row2Keys: [(String, String)] = [
            ("<", "<"), (">", ">"), ("\"", "\""), ("'", "'"), (",", ","),
            ("+", "+"), ("-", "-"), ("*", "*"), ("/", "/"), ("!", "!"),
            ("&", "&"), ("|", "|"), ("_", "_"), ("#", "#"),
        ]

        let bgColor = UIColor(Theme.Colors.background)
        let textColor = UIColor(Theme.Colors.text)
        let accentColor = UIColor(Theme.Colors.accent)

        func makeKeyButton(_ label: String, _ insertText: String) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(label, for: .normal)
            button.titleLabel?.font = label == "TAB"
                ? .systemFont(ofSize: 11, weight: .semibold)
                : .monospacedSystemFont(ofSize: 15, weight: .medium)
            button.setTitleColor(label == "TAB" ? accentColor : textColor, for: .normal)
            button.backgroundColor = bgColor
            button.layer.cornerRadius = 6
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: label == "TAB" ? 10 : 8, bottom: 4, right: label == "TAB" ? 10 : 8)
            button.addAction(UIAction { _ in
                coordinator.insertText(insertText, into: textView)
            }, for: .touchUpInside)
            return button
        }

        func makeScrollableRow(_ keys: [(String, String)]) -> UIScrollView {
            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            scroll.translatesAutoresizingMaskIntoConstraints = false

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 5
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 6),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -6),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            ])

            for (label, insertText) in keys {
                stack.addArrangedSubview(makeKeyButton(label, insertText))
            }
            return scroll
        }

        let row1Scroll = makeScrollableRow(row1Keys)
        container.addSubview(row1Scroll)

        // Undo/Redo pinned left of row 2
        let undoBtn = UIButton(type: .system)
        undoBtn.setImage(UIImage(systemName: "arrow.uturn.backward")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)), for: .normal)
        undoBtn.tintColor = accentColor
        undoBtn.translatesAutoresizingMaskIntoConstraints = false
        undoBtn.addAction(UIAction { _ in textView.undoManager?.undo() }, for: .touchUpInside)
        container.addSubview(undoBtn)

        let redoBtn = UIButton(type: .system)
        redoBtn.setImage(UIImage(systemName: "arrow.uturn.forward")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)), for: .normal)
        redoBtn.tintColor = accentColor
        redoBtn.translatesAutoresizingMaskIntoConstraints = false
        redoBtn.addAction(UIAction { _ in textView.undoManager?.redo() }, for: .touchUpInside)
        container.addSubview(redoBtn)

        // Row 2: symbols scrollable in the middle
        let row2Scroll = makeScrollableRow(row2Keys)
        container.addSubview(row2Scroll)

        // Done pinned right of row 2
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.titleLabel?.font = .boldSystemFont(ofSize: 15)
        doneBtn.tintColor = accentColor
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.addAction(UIAction { _ in textView.resignFirstResponder() }, for: .touchUpInside)
        container.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: container.topAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            // Row 1: full width
            row1Scroll.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 2),
            row1Scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row1Scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row1Scroll.heightAnchor.constraint(equalToConstant: rowHeight),

            // Row 2: undo/redo pinned left, symbols scrollable middle, done pinned right
            undoBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            undoBtn.centerYAnchor.constraint(equalTo: row1Scroll.bottomAnchor, constant: 2 + rowHeight / 2),
            undoBtn.widthAnchor.constraint(equalToConstant: 36),

            redoBtn.leadingAnchor.constraint(equalTo: undoBtn.trailingAnchor, constant: 4),
            redoBtn.centerYAnchor.constraint(equalTo: undoBtn.centerYAnchor),
            redoBtn.widthAnchor.constraint(equalToConstant: 36),

            row2Scroll.topAnchor.constraint(equalTo: row1Scroll.bottomAnchor, constant: 2),
            row2Scroll.leadingAnchor.constraint(equalTo: redoBtn.trailingAnchor, constant: 4),
            row2Scroll.trailingAnchor.constraint(equalTo: doneBtn.leadingAnchor, constant: -4),
            row2Scroll.heightAnchor.constraint(equalToConstant: rowHeight),

            doneBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            doneBtn.centerYAnchor.constraint(equalTo: undoBtn.centerYAnchor),
            doneBtn.widthAnchor.constraint(equalToConstant: 48),
        ])

        return container
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var code: String
        var currentLanguage: String
        var isUpdatingFromSwiftUI = false
        let onFocusChange: ((Bool) -> Void)?
        weak var containerView: CodeEditorContainerView?
        private var highlightWorkItem: DispatchWorkItem?

        init(code: Binding<String>, languageSlug: String, onFocusChange: ((Bool) -> Void)?) {
            _code = code
            self.currentLanguage = languageSlug
            self.onFocusChange = onFocusChange
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            code = textView.text

            // Debounce highlighting for performance
            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyHighlighting(to: textView, language: self.currentLanguage)
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)

            containerView?.updateLineNumbers()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            onFocusChange?(false)
        }

        nonisolated func insertText(_ text: String, into textView: UITextView) {
            MainActor.assumeIsolated {
                textView.insertText(text)
            }
        }

        // MARK: - Smart Indentation

        private let bracketPairs: [String: String] = [
            "(": ")", "{": "}", "[": "]"
        ]

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let nsText = (textView.text ?? "") as NSString

            // Auto-close brackets
            if let closing = bracketPairs[text] {
                textView.insertText(text + closing)
                if let pos = textView.position(from: textView.beginningOfDocument, offset: range.location + 1) {
                    textView.selectedTextRange = textView.textRange(from: pos, to: pos)
                }
                return false
            }

            // Smart Enter
            guard text == "\n" else { return true }

            let cursorPosition = range.location
            let lineRange = nsText.lineRange(for: NSRange(location: cursorPosition, length: 0))
            let currentLine = nsText.substring(with: lineRange)
            let leadingWhitespace = String(currentLine.prefix(while: { $0 == " " || $0 == "\t" }))
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let indent = "    "
            var newIndent = leadingWhitespace

            let shouldDeepen = trimmedLine.hasSuffix(":") || trimmedLine.hasSuffix("{") ||
                               trimmedLine.hasSuffix("(") || trimmedLine.hasSuffix("[")

            if shouldDeepen {
                newIndent += indent
                // If next char is a closing bracket, add it on a new line
                if cursorPosition < nsText.length {
                    let nextChar = nsText.substring(with: NSRange(location: cursorPosition, length: 1))
                    if nextChar == "}" || nextChar == "]" || nextChar == ")" {
                        textView.insertText("\n" + newIndent + "\n" + leadingWhitespace)
                        if let pos = textView.position(from: textView.beginningOfDocument, offset: cursorPosition + 1 + newIndent.count) {
                            textView.selectedTextRange = textView.textRange(from: pos, to: pos)
                        }
                        return false
                    }
                }
            }

            textView.insertText("\n" + newIndent)
            return false
        }

        // MARK: - Syntax Highlighting

        func applyHighlighting(to textView: UITextView, language: String) {
            let text = textView.text ?? ""
            guard !text.isEmpty else { return }

            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: (text as NSString).length)

            // Base style
            let baseFontSize: CGFloat = 14
            let baseFont = UIFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
            let baseColor = UIColor(Theme.Colors.text)

            attributed.addAttribute(.font, value: baseFont, range: fullRange)
            attributed.addAttribute(.foregroundColor, value: baseColor, range: fullRange)

            let rules = SyntaxRules.rules(for: language)
            for rule in rules {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else { continue }
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    let range = rule.captureGroup < match.numberOfRanges
                        ? match.range(at: rule.captureGroup)
                        : match.range
                    guard range.location != NSNotFound else { continue }
                    attributed.addAttribute(.foregroundColor, value: rule.color, range: range)
                }
            }

            // Preserve cursor position
            let selectedRange = textView.selectedRange
            textView.attributedText = attributed
            if selectedRange.location <= (text as NSString).length {
                textView.selectedRange = selectedRange
            }

            containerView?.updateLineNumbers()
        }
    }
}

// MARK: - Container View (UITextView + Line Numbers)

final class CodeEditorContainerView: UIView {
    let textView = UITextView()
    private let lineNumberView = LineNumberView()
    private let gutterWidth: CGFloat = 40

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(Theme.Colors.background)

        // Line number gutter
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        lineNumberView.backgroundColor = UIColor(Theme.Colors.background)
        addSubview(lineNumberView)

        // Text view
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.textColor = UIColor(Theme.Colors.text)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardAppearance = .dark
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 12)
        textView.alwaysBounceVertical = true
        addSubview(textView)

        NSLayoutConstraint.activate([
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: gutterWidth),

            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Observe scroll changes
        textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }

    deinit {
        textView.removeObserver(self, forKeyPath: "contentOffset")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            updateLineNumbers()
        }
    }

    func updateLineNumbers() {
        lineNumberView.update(
            textView: textView,
            font: textView.font ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLineNumbers()
    }
}

// MARK: - Line Number Gutter

private final class LineNumberView: UIView {
    private var lineRects: [(Int, CGRect)] = []
    private var drawFont: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)

    func update(textView: UITextView, font: UIFont) {
        let text = textView.text ?? ""
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let contentOffset = textView.contentOffset
        let visibleRect = CGRect(
            x: 0,
            y: contentOffset.y,
            width: textView.bounds.width,
            height: textView.bounds.height
        )

        var newLineRects: [(Int, CGRect)] = []
        let nsText = text as NSString
        var lineNumber = 1
        var glyphIndex = 0
        let numberOfGlyphs = layoutManager.numberOfGlyphs

        while glyphIndex < numberOfGlyphs {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)

            let adjustedRect = CGRect(
                x: 0,
                y: lineRect.origin.y + textView.textContainerInset.top - contentOffset.y,
                width: bounds.width,
                height: lineRect.height
            )

            if adjustedRect.maxY > 0 && adjustedRect.minY < bounds.height {
                newLineRects.append((lineNumber, adjustedRect))
            }

            // Count newlines in this glyph range to determine line number advancement
            let charRange = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            let lineText = nsText.substring(with: charRange)
            let newlineCount = lineText.components(separatedBy: "\n").count - 1
            lineNumber += max(1, newlineCount)

            glyphIndex = NSMaxRange(lineRange)

            if adjustedRect.minY > bounds.height {
                break
            }
        }

        lineRects = newLineRects
        drawFont = UIFont.monospacedSystemFont(ofSize: font.pointSize - 3, weight: .regular)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)

        let bgColor = UIColor(Theme.Colors.background)
        bgColor.setFill()
        context.fill(rect)

        let textColor = UIColor(Theme.Colors.textSecondary).withAlphaComponent(0.5)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: drawFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]

        for (lineNumber, lineRect) in lineRects {
            let numberString = "\(lineNumber)" as NSString
            let drawRect = CGRect(
                x: 0,
                y: lineRect.origin.y + (lineRect.height - drawFont.lineHeight) / 2,
                width: bounds.width - 8,
                height: drawFont.lineHeight
            )
            numberString.draw(in: drawRect, withAttributes: attributes)
        }
    }
}

// MARK: - Syntax Rules

private struct SyntaxRule {
    let pattern: String
    let color: UIColor
    let options: NSRegularExpression.Options
    let captureGroup: Int

    init(_ pattern: String, color: UIColor, options: NSRegularExpression.Options = [], captureGroup: Int = 0) {
        self.pattern = pattern
        self.color = color
        self.options = options
        self.captureGroup = captureGroup
    }
}

private enum SyntaxRules {
    // Colors matching dark theme
    static let keyword = UIColor(red: 0.78, green: 0.46, blue: 0.86, alpha: 1.0)    // purple
    static let string = UIColor(red: 0.65, green: 0.89, blue: 0.63, alpha: 1.0)     // green
    static let comment = UIColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 1.0)    // gray
    static let number = UIColor(red: 0.98, green: 0.73, blue: 0.42, alpha: 1.0)     // orange
    static let type = UIColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1.0)       // blue
    static let function = UIColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1.0)   // blue
    static let builtIn = UIColor(red: 0.33, green: 0.82, blue: 0.76, alpha: 1.0)    // cyan

    static func rules(for language: String) -> [SyntaxRule] {
        var rules: [SyntaxRule] = []

        // Comments (apply first so they're not overridden)
        rules.append(SyntaxRule(#"//.*$"#, color: comment, options: .anchorsMatchLines))
        rules.append(SyntaxRule(#"#.*$"#, color: comment, options: .anchorsMatchLines))    // Python
        rules.append(SyntaxRule(#"/\*[\s\S]*?\*/"#, color: comment))

        // Strings
        rules.append(SyntaxRule(#"\"(?:[^\"\\]|\\.)*\""#, color: string))
        rules.append(SyntaxRule(#"'(?:[^'\\]|\\.)*'"#, color: string))
        rules.append(SyntaxRule(#"`[^`]*`"#, color: string))    // template literals / Go raw strings
        rules.append(SyntaxRule(#"\"\"\"[\s\S]*?\"\"\""#, color: string))  // triple-quoted strings

        // Numbers
        rules.append(SyntaxRule(#"\b\d+\.?\d*(?:[eE][+-]?\d+)?\b"#, color: number))
        rules.append(SyntaxRule(#"\b0x[0-9a-fA-F]+\b"#, color: number))

        // Language-specific keywords
        let lang = language.lowercased()
        let keywordPattern: String

        switch lang {
        case "python", "python3":
            keywordPattern = #"\b(def|class|return|if|elif|else|for|while|in|not|and|or|is|with|as|try|except|finally|raise|import|from|pass|break|continue|yield|lambda|None|True|False|self|global|nonlocal|assert|del|async|await)\b"#
        case "javascript", "typescript":
            keywordPattern = #"\b(function|const|let|var|return|if|else|for|while|do|switch|case|break|continue|class|extends|new|this|super|import|export|default|from|try|catch|finally|throw|async|await|typeof|instanceof|void|null|undefined|true|false|of|in|yield)\b"#
        case "java":
            keywordPattern = #"\b(public|private|protected|static|final|abstract|class|interface|extends|implements|return|if|else|for|while|do|switch|case|break|continue|new|this|super|import|package|try|catch|finally|throw|throws|void|null|true|false|instanceof|synchronized|volatile|transient)\b"#
        case "cpp", "c":
            keywordPattern = #"\b(int|long|short|float|double|char|bool|void|unsigned|signed|const|static|struct|class|public|private|protected|virtual|override|return|if|else|for|while|do|switch|case|break|continue|new|delete|this|nullptr|NULL|true|false|include|define|typedef|template|namespace|using|auto|sizeof|enum)\b"#
        case "go", "golang":
            keywordPattern = #"\b(func|package|import|return|if|else|for|range|switch|case|break|continue|var|const|type|struct|interface|map|chan|go|defer|select|default|nil|true|false|make|len|append|cap|error|string|int|bool|byte|float64|float32)\b"#
        case "rust":
            keywordPattern = #"\b(fn|let|mut|const|struct|enum|impl|trait|pub|use|mod|return|if|else|for|while|loop|match|break|continue|self|Self|true|false|None|Some|Ok|Err|unsafe|async|await|move|dyn|where|type|as|in|ref|static|extern|crate|super)\b"#
        case "swift":
            keywordPattern = #"\b(func|class|struct|enum|protocol|extension|return|if|else|guard|for|while|repeat|switch|case|break|continue|let|var|self|Self|super|import|true|false|nil|throws|throw|try|catch|async|await|in|where|is|as|init|deinit|static|private|public|internal|open|fileprivate|override|mutating|typealias|associatedtype|some|any)\b"#
        case "kotlin":
            keywordPattern = #"\b(fun|class|object|interface|val|var|return|if|else|when|for|while|do|break|continue|in|is|as|null|true|false|this|super|import|package|try|catch|finally|throw|override|abstract|open|sealed|data|companion|private|public|protected|internal|suspend|coroutine|lateinit|by|lazy)\b"#
        case "ruby":
            keywordPattern = #"\b(def|class|module|end|return|if|elsif|else|unless|for|while|until|do|begin|rescue|ensure|raise|yield|block_given|require|include|extend|attr_accessor|attr_reader|attr_writer|nil|true|false|self|super|puts|print)\b"#
        case "csharp", "c#":
            keywordPattern = #"\b(public|private|protected|internal|static|class|interface|struct|enum|abstract|sealed|override|virtual|return|if|else|for|foreach|while|do|switch|case|break|continue|new|this|base|null|true|false|void|var|string|int|bool|float|double|using|namespace|try|catch|finally|throw|async|await|readonly|const|ref|out|in|is|as|typeof)\b"#
        default:
            // Generic fallback
            keywordPattern = #"\b(function|class|return|if|else|for|while|do|switch|case|break|continue|var|let|const|new|this|null|true|false|import|export|from|try|catch|throw|void|def|self|None|nil)\b"#
        }

        rules.append(SyntaxRule(keywordPattern, color: keyword))

        // Type names (capitalized identifiers)
        rules.append(SyntaxRule(#"\b([A-Z][A-Za-z0-9_]*)\b"#, color: type))

        // Function calls
        rules.append(SyntaxRule(#"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#, color: function, captureGroup: 1))

        return rules
    }
}
