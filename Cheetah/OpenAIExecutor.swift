import Foundation

enum ModelInput {
    case prompt(String, model: OpenAIModelType.GPT3 = .davinci)
    case messages([ChatMessage], model: OpenAIModelType.Chat = .gpt4)
    case chatPrompt(system: String, user: String, model: OpenAIModelType.Chat = .gpt4)
}

class PromptChain<Context> {
    let generator: (Context) throws -> ModelInput?
    let updateContext: (String, inout Context) throws -> ()
    let maxTokens: Int
    let children: [PromptChain]?
    
    init(generator: @escaping (Context) throws -> ModelInput?,
         updateContext: @escaping (String, inout Context) throws -> (),
         maxTokens: Int = 16,
         children: [PromptChain]? = nil
    ) {
        self.generator = generator
        self.updateContext = updateContext
        self.maxTokens = maxTokens
        self.children = children
    }
}

typealias Prompt = PromptChain

extension UserDefaults {
    @objc var logPrompts: Bool {
        get {
            bool(forKey: "logPrompts")
        }
        set {
            set(newValue, forKey: "logPrompts")
        }
    }
    
    @objc var logCompletions: Bool {
        get {
            bool(forKey: "logCompletions")
        }
        set {
            set(newValue, forKey: "logCompletions")
        }
    }
}

class OpenAIExecutor {
    let openAI: OpenAISwift
    let useGPT4: Bool
    
    init(openAI: OpenAISwift, useGPT4: Bool) {
        self.openAI = openAI
        self.useGPT4 = useGPT4
    }
    
    convenience init(authToken: String, useGPT4: Bool) {
        self.init(openAI: .init(authToken: authToken), useGPT4: useGPT4)
    }
    
    func log(prompt: String) {
        if UserDefaults.standard.logPrompts {
            print("Prompt:\n", prompt)
        }
    }
    
    func log(completion: String) {
        if UserDefaults.standard.logCompletions {
            print("Completion:\n", completion)
        }
    }
    
    func execute(prompt: String, model: OpenAIModelType, maxTokens: Int = 100) async throws -> String? {
        log(prompt: prompt)
        let result = try await openAI.sendCompletion(with: prompt, model: model, maxTokens: maxTokens)
        let text = result.choices?.first?.text
        if let text = text {
            log(completion: text)
        } else if let error = result.error {
            throw error
        }
        return text
    }
    
    func execute(messages: [ChatMessage], model: OpenAIModelType, maxTokens: Int = 100) async throws -> String? {
        log(prompt: messages.debugDescription)
        let result = try await openAI.sendChat(with: messages, model: model, maxTokens: maxTokens)
        let content = result.choices?.first?.message.content
        if let content = content {
            log(completion: content)
        } else if let error = result.error {
            throw error
        }
        return content
    }
    
    func adjustModel(_ model: OpenAIModelType.Chat) -> OpenAIModelType.Chat {
        if !useGPT4 && model == .gpt4 {
            return .chatgpt
        } else {
            return model
        }
    }
    
    func execute<K>(chain: PromptChain<[K: String]>, context initialContext: [K: String]) async throws -> [K: String] {
        var context = initialContext
        
        guard let input = try chain.generator(context) else {
            return context
        }
        
        let output: String?
        switch input {
        case .prompt(let prompt, let model):
            output = try await execute(prompt: prompt, model: .gpt3(model), maxTokens: chain.maxTokens)
            
        case .messages(let messages, let model):
            output = try await execute(messages: messages, model: .chat(adjustModel(model)), maxTokens: chain.maxTokens)
            
        case .chatPrompt(system: let systemMessage, user: let userMessage, model: let model):
            let messages = [
                ChatMessage(role: .system, content: systemMessage),
                ChatMessage(role: .user, content: userMessage),
            ]
            output = try await execute(messages: messages, model: .chat(adjustModel(model)), maxTokens: chain.maxTokens)
        }
        
        guard let output = output else {
            return context
        }
        
        try chain.updateContext(String(output.trimmingCharacters(in: .whitespacesAndNewlines)), &context)
        
        let childContext = context
        
        if let children = chain.children {
            let childOutputs = try await withThrowingTaskGroup(
                of: [K: String?].self,
                returning: [K: String?].self
            ) { group in
                for child in children {
                    group.addTask {
                        return try await self.execute(chain: child, context: childContext)
                    }
                }
                
                return try await group.reduce(into: [:]) {
                    for (key, output) in $1 {
                        $0[key] = output
                    }
                }
            }
            
            for (key, output) in childOutputs {
                context[key] = output
            }
        }
        
        return context
    }
}
