import SwiftUI
import LibWhisper

struct AuthTokenView: View {
    @Binding var storedToken: String?
    @Binding var useGPT4: Bool
    
    @State var tokenValue = ""
    @State var toggleValue = true
    
    var body: some View {
        VStack(spacing: 16) {
            Link(destination: URL(string: "https://platform.openai.com/account/api-keys")!) {
                Text("Click here to create an OpenAI API key")
            }
            TextField(text: $tokenValue) {
                Text("Paste your API key here")
            }
            .privacySensitive()
            .frame(width: 300)
            Toggle("Use GPT-4 (access required)", isOn: $toggleValue)
            Button("Save") {
                storedToken = tokenValue
                useGPT4 = toggleValue
            }
            .disabled(tokenValue.isEmpty)
        }
        .padding()
        .fixedSize()
    }
}

struct APIKeyView_Previews: PreviewProvider {
    static var previews: some View {
        return AuthTokenView(
            storedToken: Binding.constant(nil),
            useGPT4: Binding.constant(false))
    }
}
