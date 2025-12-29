import SwiftUI

struct PronounPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPronouns: [String]
    let options: [String]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(options, id: \.self) { pronoun in
                    Button(action: {
                        if selectedPronouns.contains(pronoun) {
                            selectedPronouns.removeAll { $0 == pronoun }
                        } else {
                            selectedPronouns.append(pronoun)
                        }
                    }) {
                        HStack {
                            Text(pronoun)
                            Spacer()
                            if selectedPronouns.contains(pronoun) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Pronouns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

