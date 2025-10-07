// MARK: - Domain Models

import Foundation
struct ToeicQuestion: Identifiable, Codable, Equatable {
    let id: UUID
    let type: QuestionType
    let prompt: String
    let choices: [String]
    let answerIndex: Int
    var explanation: String = ""
    var filledSentence: String? = nil
    var filledSentenceJa: String? = nil
    var choiceTranslationsJa: [String]? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    
    enum CodingKeys: String, CodingKey {
        case id, type, prompt, choices, answerIndex, explanation
        case filledSentence, filledSentenceJa, choiceTranslationsJa
        case createdAt, updatedAt
    }

    init(
        id: UUID,
        type: QuestionType,
        prompt: String,
        choices: [String],
        answerIndex: Int,
        explanation: String = "",
        filledSentence: String? = nil,
        filledSentenceJa: String? = nil,
        choiceTranslationsJa: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.choices = choices
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.filledSentence = filledSentence
        self.filledSentenceJa = filledSentenceJa
        self.choiceTranslationsJa = choiceTranslationsJa
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(QuestionType.self, forKey: .type)
        self.prompt = try container.decode(String.self, forKey: .prompt)
        self.choices = try container.decode([String].self, forKey: .choices)
        self.answerIndex = try container.decode(Int.self, forKey: .answerIndex)
        self.explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? ""
        self.filledSentence = try container.decodeIfPresent(String.self, forKey: .filledSentence)
        self.filledSentenceJa = try container.decodeIfPresent(String.self, forKey: .filledSentenceJa)
        self.choiceTranslationsJa = try container.decodeIfPresent([String].self, forKey: .choiceTranslationsJa)
        // Decode-only timestamps (do not encode back)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date.distantPast
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date.distantPast
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(choices, forKey: .choices)
        try container.encode(answerIndex, forKey: .answerIndex)
        if !explanation.isEmpty { try container.encode(explanation, forKey: .explanation) }
        try container.encodeIfPresent(filledSentence, forKey: .filledSentence)
        try container.encodeIfPresent(filledSentenceJa, forKey: .filledSentenceJa)
        try container.encodeIfPresent(choiceTranslationsJa, forKey: .choiceTranslationsJa)
        // Intentionally DO NOT encode createdAt/updatedAt here; server-side meta write will manage them
    }
}

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case grammar
    case partOfSpeech
    case vocabulary
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .grammar: return "文法"
        case .partOfSpeech: return "品詞"
        case .vocabulary: return "語彙"
        }
    }
}

enum ToeicLevel: String, CaseIterable, Identifiable {
    case l200 = "~200"
    case l400 = "201-400"
    case l600 = "401-600"
    case l800 = "601-800"
    case l990 = "801-990"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    var instructionHint: String {
        switch self {
        case .l200: return "Beginner (~200)"
        case .l400: return "Basic (201-400)"
        case .l600: return "Intermediate (401-600)"
        case .l800: return "Upper-Intermediate (601-800)"
        case .l990: return "Advanced (801-990)"
        }
    }
}

struct ItemPlan {
    struct Vocab: Codable {
        let headword: String
        let meaning: String?
        let pos: String?
        init(headword: String, meaning: String? = nil, pos: String? = nil) {
            self.headword = headword
            self.meaning = meaning
            self.pos = pos
        }
    }
    let index: Int
    let type: QuestionType
    let sceneText: String
    let grammarSubcategory: String?
    let vocab: Vocab?

    init(index: Int,
         type: QuestionType,
         sceneText: String,
         grammarSubcategory: String? = nil,
         vocab: Vocab? = nil) {
        self.index = index
        self.type = type
        self.sceneText = sceneText
        self.grammarSubcategory = grammarSubcategory
        self.vocab = vocab
    }
}

struct GroqChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Encodable { let type: String }
    let model: String
    let messages: [Message]
    let response_format: ResponseFormat?
    var temperature: Double? = nil
    var top_p: Double? = nil
    var presence_penalty: Double? = nil
    var frequency_penalty: Double? = nil

    init(
        model: String,
        messages: [Message],
        response_format: ResponseFormat? = nil,
        temperature: Double? = nil,
        top_p: Double? = nil,
        presence_penalty: Double? = nil,
        frequency_penalty: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.response_format = response_format
        self.temperature = temperature
        self.top_p = top_p
        self.presence_penalty = presence_penalty
        self.frequency_penalty = frequency_penalty
    }
}

struct GroqChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let role: String; let content: String }
        let index: Int
        let message: Message
    }
    let choices: [Choice]
}

struct QuestionEnvelope: Decodable {
    let questions: [QuestionDTO]
}

struct QuestionDTO: Decodable {
    let type: QuestionType
    let prompt: String
    let choices: [String]
}

struct PlanForPrompt: Encodable {
    struct SceneInfo: Encodable { let text: String }
    let index: Int
    let type: String
    let scene: SceneInfo
    let grammar: String?
    let vocab: String?
}

struct VerifyPayload: Encodable {
    struct Q: Encodable {
        let index: Int
        let type: String
        let prompt: String
        let choices: [String]
    }
    let questions: [Q]
}

struct VerifyEnvelope: Decodable {
    struct Item: Decodable {
        let index: Int
        let explanation: String
        let choices: [String]? // 4 options; when present, replace distractors to enforce single correct
        let filled_sentence: String?
        let filled_sentence_ja: String?
        let choice_translations_ja: [String]?
    }
    let verified: [Item]
}
