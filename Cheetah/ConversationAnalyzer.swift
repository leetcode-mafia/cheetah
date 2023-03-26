import LibWhisper
import Combine

enum ContextKey: String {
    case transcript
    case question
    case answerInCode
    case answer
    case previousAnswer
    case highlightedAnswer
    case codeAnswer
    case browserCode
    case browserLogs
}

typealias AnalysisContext = [ContextKey: String]

extension AnalysisContext {
    var answerInCode: Bool {
        return self[.answerInCode]?.first?.lowercased() == "y"
    }
}

enum AnalysisError: Error {
    case missingRequiredContextKey(ContextKey)
}

extension PromptGenerator {
    func extractQuestion(context: AnalysisContext) throws -> ModelInput? {
        if let transcript = context[.transcript] {
            return extractQuestion(transcript: transcript)
        } else {
            throw AnalysisError.missingRequiredContextKey(.transcript)
        }
    }
    
    func answerQuestion(context: AnalysisContext) throws -> ModelInput? {
        guard let question = context[.question] else {
            throw AnalysisError.missingRequiredContextKey(.question)
        }
        if context.answerInCode {
            return nil
        } else if let answer = context[.previousAnswer] {
            return answerQuestion(question, previousAnswer: answer)
        } else if let answer = context[.highlightedAnswer] {
            return answerQuestion(question, highlightedAnswer: answer)
        } else {
            return answerQuestion(question)
        }
    }
    
    func writeCode(context: AnalysisContext) -> ModelInput? {
        if context.answerInCode, let question = context[.question] {
            return writeCode(task: question)
        } else {
            return nil
        }
    }
    
    func analyzeBrowserCode(context: AnalysisContext) -> ModelInput? {
        if let code = context[.browserCode], let logs = context[.browserLogs] {
            return analyzeBrowserCode(code, logs: logs, task: context[.question])
        } else {
            return nil
        }
    }
}

extension ContextKey {
    var `set`: (String, inout AnalysisContext) -> () {
        return { output, context in
            context[self] = output
        }
    }
    
    func extract(using regexArray: Regex<(Substring, answer: Substring)>...) -> (String, inout AnalysisContext) -> () {
        return { output, context in
            for regex in regexArray {
                if let match = output.firstMatch(of: regex) {
                    context[self] = String(match.answer)
                }
            }
        }
    }
}

let extractQuestion: (String, inout AnalysisContext) -> () = { output, context in
    let regex = /Extracted question: (?<question>[^\n]+)(?:\nAnswer in code: (?<answerInCode>Yes|No))?/.ignoresCase()
    if let match = output.firstMatch(of: regex) {
        context[.question] = String(match.question)
        if let answerInCode = match.answerInCode {
            context[.answerInCode] = String(answerInCode)
        }
    }
}

let finalAnswerRegex = /Final answer:\n(?<answer>[-•].+$)/.dotMatchesNewlines()
let answerOnlyRegex = /(?<answer>[-•].+$)/.dotMatchesNewlines()

class ConversationAnalyzer {
    let stream: WhisperStream
    let generator: PromptGenerator
    let executor: OpenAIExecutor
    
    init(stream: WhisperStream, generator: PromptGenerator, executor: OpenAIExecutor) {
        self.stream = stream
        self.generator = generator
        self.executor = executor
    }
    
    var context = [ContextKey: String]()
    
    func answer(refine: Bool = false, selection: Range<String.Index>? = nil) async throws {
        let chain = PromptChain(
            generator: generator.extractQuestion,
            updateContext: extractQuestion,
            maxTokens: 250,
            children: [
                Prompt(generator: generator.answerQuestion,
                       updateContext: ContextKey.answer.extract(using: finalAnswerRegex, answerOnlyRegex),
                       maxTokens: 500),
                Prompt(generator: generator.writeCode,
                       updateContext: ContextKey.codeAnswer.set,
                       maxTokens: 1000),
            ])
        
        var newContext: AnalysisContext = [
            .transcript: String(stream.segments.text)
        ]
        
        if refine, let previousAnswer = context[.answer] {
            if let selection = selection {
                let highlightedAnswer = previousAnswer[..<selection.lowerBound] + " [start highlighted text] " + previousAnswer[selection] + " [end highlighted text] " + previousAnswer[selection.upperBound...]
                newContext[.highlightedAnswer] = String(highlightedAnswer)
            } else {
                newContext[.previousAnswer] = previousAnswer
            }
        }
        
        context = try await executor.execute(chain: chain, context: newContext)
    }
    
    func analyzeCode(extensionState: BrowserExtensionState) async throws {
        let newContext: AnalysisContext = [
            .transcript: String(stream.segments.text),
            .browserCode: extensionState.codeDescription,
            .browserLogs: extensionState.logsDescription
        ]
        
        let chain = PromptChain(
            generator: generator.extractQuestion,
            updateContext: extractQuestion,
            maxTokens: 250,
            children: [
                Prompt(generator: generator.analyzeBrowserCode,
                       updateContext: ContextKey.answer.set,
                       maxTokens: 500)
            ])
        
        context = try await executor.execute(chain: chain, context: newContext)
    }
}
