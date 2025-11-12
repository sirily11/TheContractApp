import CodeEditorView
import LanguageSupport
import SwiftUI

struct JsonView: View {
    @Binding var content: String
    @State private var position: CodeEditor.Position = .init()
    @State private var messages: Set<TextLocated<Message>> = Set()

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        CodeEditor(text: $content, position: $position, messages: $messages, language: .json())
            .environment(\.codeEditorTheme,
                         colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
            .environment(\.codeEditorLayoutConfiguration, .init(showMinimap: false, wrapText: false))
    }
}

#Preview {
    @Previewable @State var content = """
    {
    "name": "Smart Contract"
    }
    """

    JsonView(content: $content)
}
