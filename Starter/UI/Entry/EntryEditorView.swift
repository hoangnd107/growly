import SwiftUI

struct EntryEditorView: View {
    @State private var text: String = ""

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .padding()
                    .navigationTitle("Edit Entry")
                Spacer()
            }
        }
    }
}

struct EntryEditorView_Previews: PreviewProvider {
    static var previews: some View {
        EntryEditorView()
    }
}
