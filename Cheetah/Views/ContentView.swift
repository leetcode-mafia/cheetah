import SwiftUI
import LibWhisper

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @ViewBuilder
    var body: some View {
        if viewModel.authToken?.isEmpty == false {
            VStack(spacing: 16) {
                switch viewModel.downloadState {
                case .pending:
                    Text("Downloading \(viewModel.whisperModel)...")
                    
                case .failed(let error):
                    if let error = error {
                        Text("Failed to download model. \(error.localizedDescription)")
                    } else {
                        Text("Failed to download model. An unknown error occurred.")
                    }
                    
                case .completed:
                    CoachView(viewModel: viewModel)
                }
            }
            .padding()
            .frame(minWidth: 300, minHeight: 350)
        } else {
            AuthTokenView(storedToken: viewModel.$authToken,
                          useGPT4: viewModel.$useGPT4.nonEmpty)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AppViewModel()
        viewModel.devices = [CaptureDevice(id: 0, name: "Audio Loopback Device")]
        viewModel.buttonsAlwaysEnabled = true
        viewModel.authToken = "x"
        viewModel.downloadState = .completed
        viewModel.transcript = "So how would we break this app down into components?"
        viewModel.answer = """
• Header Component: Contains two sub-components: Logo and Title.
Props: logoUrl, title

• Content Component: Contains an image and a paragraph.
Props: imageUrl, message

• Footer Component: Simple component that displays a message.
Props: message

• App Component: Renders the Header, Content, and Footer components
"""
        return ContentView(viewModel: viewModel)
            .previewLayout(.fixed(width: 300, height: 500))
            .previewDisplayName("Cheetah")
    }
}

extension Binding where Value == Bool? {
    var nonEmpty: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue ?? false },
            set: { self.wrappedValue = $0 }
        )
    }
}
