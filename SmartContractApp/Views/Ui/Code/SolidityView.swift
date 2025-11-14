//
//  SolidityView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import CodeEditorView
import LanguageSupport
import SwiftUI
import Solidity

struct SolidityView: View {
    @Binding var content: String
    var compilationOutput: Binding<Output?>?

    @State private var position: CodeEditor.Position = .init()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var isCompiling: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var compiler: SolidityCompiler?

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        ZStack {
            CodeEditor(
                text: $content,
                position: $position,
                messages: $messages,
                language: .solidity()
            )
            .environment(\.codeEditorTheme,
                         colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
            .environment(\.codeEditorLayoutConfiguration, .init(showMinimap: false, wrapText: false))
            .onChange(of: content) { _, newValue in
                handleContentChange(newValue)
            }
            .onDisappear {
                cleanup()
            }

            // Loading spinner overlay
            if isCompiling {
                ZStack {
                    Color.black.opacity(0.2)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
    }

    // MARK: - Debounced Compilation

    private func handleContentChange(_ newValue: String) {
        // Cancel any existing debounce task
        debounceTask?.cancel()

        // Create new debounce task
        debounceTask = Task {
            // Wait for 800ms
            try? await Task.sleep(for: .milliseconds(800))

            // Check if task was cancelled
            if !Task.isCancelled {
                await compileCode(newValue)
            }
        }
    }

    // MARK: - Compilation

    @MainActor
    private func compileCode(_ code: String) async {
        // Don't compile empty code
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messages.removeAll()
            return
        }

        isCompiling = true
        messages.removeAll()

        defer {
            isCompiling = false
        }

        do {
            // Create compiler instance if needed (cache for reuse)
            if compiler == nil {
                compiler = try await Solc.create(version: "0.8.21")
            }

            guard let compiler = compiler else {
                return
            }

            // Prepare compilation input
            let sourceIn = SourceIn(content: code)
            let settings = Settings(
                optimizer: Optimizer(enabled: false, runs: 200),
                outputSelection: ["*": ["*": ["abi", "evm.bytecode", "evm.deployedBytecode"]]]
            )
            let input = Input(
                language: "Solidity",
                sources: ["Contract.sol": sourceIn],
                settings: settings
            )

            // Compile
            let output = try await compiler.compile(input, options: nil)

            // Store compilation output if binding is provided
            compilationOutput?.wrappedValue = output

            // Convert errors to messages
            if let errors = output.errors {
                let convertedMessages = convertErrorsToMessages(errors, sourceCode: code)
                messages = convertedMessages
            }
        } catch {
            // Handle compilation errors
            print("Compilation error: \(error)")
            // Create a generic error message
            let errorMessage = Message(
                category: .error,
                length: 1,
                summary: "Compilation failed: \(error.localizedDescription)",
                description: nil
            )
            let location = TextLocation(zeroBasedLine: 0, column: 0)
            messages = [TextLocated(location: location, entity: errorMessage)]
        }
    }

    // MARK: - Error Conversion

    private func convertErrorsToMessages(_ errors: [CompilationError], sourceCode: String) -> Set<TextLocated<Message>> {
        var result: Set<TextLocated<Message>> = []

        for error in errors {
            // Skip if no source location
            guard let sourceLocation = error.sourceLocation,
                  let start = sourceLocation.start,
                  let end = sourceLocation.end else {
                // Create a message at line 0 for errors without location
                let message = Message(
                    category: mapSeverityToCategory(error.severity),
                    length: 1,
                    summary: error.message ?? "Unknown error",
                    description: error.formattedMessage.map { AttributedString($0) }
                )
                let location = TextLocation(zeroBasedLine: 0, column: 0)
                result.insert(TextLocated(location: location, entity: message))
                continue
            }

            // Convert byte position to line/column
            let (line, column) = bytePositionToLineColumn(bytePosition: start, in: sourceCode)
            let length = calculateCharacterLength(from: start, to: end, in: sourceCode)

            // Create message
            let message = Message(
                category: mapSeverityToCategory(error.severity),
                length: length,
                summary: error.message ?? "Unknown error",
                description: error.formattedMessage.map { AttributedString($0) }
            )

            // Create text location
            let location = TextLocation(zeroBasedLine: line, column: column)
            result.insert(TextLocated(location: location, entity: message))
        }

        return result
    }

    private func mapSeverityToCategory(_ severity: String?) -> Message.Category {
        switch severity {
        case "error":
            return .error
        case "warning":
            return .warning
        case "info":
            return .informational
        default:
            return .error
        }
    }

    // MARK: - Byte Position Conversion

    private func bytePositionToLineColumn(bytePosition: Int, in sourceCode: String) -> (line: Int, column: Int) {
        var currentByte = 0
        var currentLine = 0
        var currentColumn = 0

        for character in sourceCode {
            if currentByte >= bytePosition {
                break
            }

            let characterByteCount = String(character).utf8.count
            currentByte += characterByteCount

            if character == "\n" {
                currentLine += 1
                currentColumn = 0
            } else {
                currentColumn += 1
            }
        }

        return (line: currentLine, column: currentColumn)
    }

    private func calculateCharacterLength(from start: Int, to end: Int, in sourceCode: String) -> Int {
        var currentByte = 0
        var characterCount = 0
        var isInRange = false

        for character in sourceCode {
            let characterByteCount = String(character).utf8.count

            if currentByte >= start && currentByte < end {
                isInRange = true
                characterCount += 1
            } else if isInRange {
                break
            }

            currentByte += characterByteCount

            if currentByte > end {
                break
            }
        }

        return max(1, characterCount)
    }

    // MARK: - Cleanup

    private func cleanup() {
        debounceTask?.cancel()
        debounceTask = nil

        // Close compiler in background
        if let compiler = compiler {
            Task {
                try? await compiler.close()
            }
        }
        compiler = nil
    }
}

#Preview {
    @Previewable @State var content = """
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    contract SimpleStorage {
        uint256 private value;

        function setValue(uint256 _value) public {
            value = _value;
        }

        function getValue() public view returns (uint256) {
            return value;
        }
    }
    """

    SolidityView(content: $content)
}
