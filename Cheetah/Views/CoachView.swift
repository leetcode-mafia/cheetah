import SwiftUI
import LibWhisper

struct CoachView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State var answer: String
    @State var answerSelection = NSRange()
    
    @State var showError = false
    @State var errorDescription = ""
    
    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self.answer = viewModel.answer ?? ""
    }
    
    var spinner: some View {
        ProgressView().scaleEffect(0.5)
    }
    
    @ViewBuilder
    var body: some View {
        Picker("Audio input device", selection: $viewModel.selectedDevice) {
            Text("-").tag(nil as CaptureDevice?)
            ForEach(viewModel.devices, id: \.self) {
                Text($0.name).tag($0 as CaptureDevice?)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        ZStack {
            HStack(spacing: 10) {
                Button(action: {
                    viewModel.answerRequest = .answerQuestion
                }, label: {
                    Text("Answer")
                })
                Button(action: {
                    viewModel.answerRequest = .refineAnswer(selection: Range(answerSelection, in: answer))
                }, label: {
                    Text("Refine")
                })
                Button(action: {
                    viewModel.answerRequest = .analyzeCode
                }, label: {
                    Text("Analyze")
                })
            }
            .disabled((viewModel.authToken == nil || viewModel.analyzer == nil) && !viewModel.buttonsAlwaysEnabled)
            HStack {
                Spacer()
                switch viewModel.answerRequest {
                case .none:
                    spinner.hidden()
                default:
                    spinner
                }
            }
        }
        .onReceive(viewModel.$errorDescription) {
            if let error = $0 {
                self.showError = true
                self.errorDescription = error
            }
        }
        .alert(errorDescription, isPresented: $showError) {
            Button("OK", role: .cancel) {
                self.showError = false
            }
        }
        HStack {
            VStack(alignment: .leading, spacing: 20) {
                if let transcript = viewModel.transcript {
                    Text(transcript)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .font(.footnote.italic())
                }
                ScrollView {
                    NSTextFieldWrapper(text: $answer, selectedRange: $answerSelection)
                        .onChange(of: viewModel.answer) {
                            if let newAnswer = $0 {
                                self.answer = newAnswer
                            }
                        }
                }
                .frame(maxHeight: 600)
                if let solution = viewModel.codeAnswer {
                    Text(solution)
                        .textSelection(.enabled)
                        .font(.footnote)
                        .monospaced()
                }
                Spacer()
            }
            Spacer()
        }
    }
}
