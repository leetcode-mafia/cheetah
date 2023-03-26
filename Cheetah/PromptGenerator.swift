import Foundation

let shorthandInstruction = """
Use bullet points and write in shorthand. For example, "O(n log n) due to sorting" is preferred to "The time complexity of the implementation is O(n log n) due to the sorting."
"""

class PromptGenerator {
    var domain = "software engineering"
    
    var systemMessage: String {
        return "You are a \(domain) expert."
    }
    
    func extractQuestion(transcript: String) -> ModelInput {
        let prompt = """
Extract the last problem or question posed by the interviewer during a \(domain) interview. State it as an instruction. If the question is about something the candidate did, restate it in a general way.

[transcript begins]
If you want to improve the query performance of multiple columns or a group of columns in a given table. Cool. And is it considered a cluster index or no cluster index? definitely be a non-clustered index. For sure. All right, great. So next question. What's the difference between "where" and "having"? Oh, that's an interesting one.
[transcript ends]
Is context needed here: Yes
Context: queries, databases, performance
Extracted question: Describe the difference between "where" and "having" clauses in SQL, focusing on performance.
Answer in code: No

[transcript begins]
Are you familiar with the traceroute command? Yes I am. Okay, so how does that work behind the scenes?
[transcript ends]
Is context needed here: No
Extracted question: How does the traceroute command work?
Answer in code: No

[transcript begins]
Write a function that takes 3 arguments. The first argument is a list of numbers that is guaranteed to be sorted. The remaining two arguments, a and b, are the coefficients of the function f(x) = a*x + b. Your function should compute f(x) for every number in the first argument, and return a list of those values, also sorted.
[transcript ends]
Is context needed here: Yes
Context: C++
Extracted question: C++ function that takes a vector of sorted numbers; and coefficients (a, b) of the function f(x) = a*x + b. It should compute f(x) for each input number, and return a sorted vector.
Answer in code: Yes

[transcript begins]
\(transcript)
[transcript ends]
Is context needed here:
"""
        
        return .chatPrompt(system: systemMessage, user: prompt, model: .chatgpt)
    }
    
    func answerQuestion(_ question: String) -> ModelInput {
        let prompt = """
You are a \(domain) expert. \(shorthandInstruction)

Example 1:
Question: Should I use "where" or "having" to find employee first names that appear more than 250 times?
Are follow up questions needed here: Yes
Follow up: Will this query use aggregation?
Intermediate answer: Yes, count(first_name)
Follow up: Does "where" or "having" filter rows after aggregation?
Intermediate answer: having
Final answer:
• Where: filters rows before aggregation
• Having: filters rows after aggregation
• Example SQL: having count(first_name) > 250

Example 2:
Question: How does the traceroute command work?
Are follow up questions needed here: No
Final answer:
• Traces the path an IP packet takes across networks
• Starting from 1, increments the TTL field in the IP header
• The returned ICMP Time Exceeded packets are used to build a list of routers

Question: \(question)
"""
        
        return .chatPrompt(system: systemMessage, user: prompt)
    }
    
    func answerQuestion(_ question: String, previousAnswer: String) -> ModelInput {
        let prompt = """
You are a \(domain) expert. Refine the partial answer. \(shorthandInstruction)

Example 1:
Question: Should I use "where" or "having" to find employee first names that appear more than 250 times?
Partial answer:
• Having: filters rows after aggregation
Are follow up questions needed here: Yes
Follow up: Will this query use aggregation?
Intermediate answer: Yes, count(first_name)
Follow up: Does "where" or "having" filter rows after aggregation?
Intermediate answer: having
Final answer:
• Where: filters rows before aggregation
• Having: filters rows after aggregation
• Example SQL: having count(first_name) > 250

Example 2:
Question: How does the traceroute command work?
Partial answer:
• Traces the path an IP packet takes across networks
• Starting from 1, increments the TTL field in the IP header
Are follow up questions needed here: No
Final answer:
• Traces the path an IP packet takes across networks
• Starting from 1, increments the TTL field in the IP header
• The returned ICMP Time Exceeded packets are used to build a list of routers

Question: \(question)
Partial answer:
\(previousAnswer)
"""
        
        return .chatPrompt(system: systemMessage, user: prompt)
    }
    
    func answerQuestion(_ question: String, highlightedAnswer: String) -> ModelInput {
        let prompt = """
Question: \(question)

You previously provided this answer, and I have highlighted part of it:
\(highlightedAnswer)

Explain the highlighted part of your previous answer in much greater depth. \(shorthandInstruction)
"""
        
        return .chatPrompt(system: systemMessage, user: prompt)
    }
    
    func writeCode(task: String) -> ModelInput {
        let prompt = """
Write pseudocode to accomplish this task: \(task)

Start with a comment outlining opportunities for optimization and potential pitfalls. Assume only standard libraries are available, unless specified. Don't explain, just give me the code.
"""
        
        return .chatPrompt(system: systemMessage, user: prompt)
    }
     
    func analyzeBrowserCode(_ code: String, logs: String, task: String? = nil) -> ModelInput {
        let prefix: String
        if let task = task {
            prefix = "Prompt: \(task)"
        } else {
            prefix = "Briefly describe how an efficient solution can be achieved."
        }
        
        let prompt = """
\(prefix)

Code:
\(code)

Output:
\(logs)

If the prompt is irrelevant, you may disregard it. You may suggest edits to the existing code. If appropriate, include a brief discussion of complexity. \(shorthandInstruction)
"""
        
        return .chatPrompt(system: systemMessage, user: prompt)
    }
}
