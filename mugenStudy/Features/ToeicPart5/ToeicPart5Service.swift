// MARK: - Groq API Client

import Foundation
final class GroqToeicService {
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    enum GroqError: LocalizedError {
        case http(status: Int, body: String)
        case emptyContent
        
        var errorDescription: String? {
            switch self {
            case let .http(status, body):
                return "Groq HTTP Error (status=\(status)): \(body)"
            case .emptyContent:
                return "Groq response had no message content."
            }
        }
    }
}

extension GroqToeicService {
    // explanationから不要なエスケープや記号を除去
    fileprivate func normalizeExplanation(_ text: String) -> String {
        if text.isEmpty { return text }
        var s = text
        // 既存のエスケープ解除
        s = s.replacingOccurrences(of: "\\\"", with: "\"")
        s = s.replacingOccurrences(of: "\\'", with: "'")
        s = s.replacingOccurrences(of: "\\\\", with: "\\")
        // 引用符・バッククォートを日本語の括弧へ寄せる
        s = s.replacingOccurrences(of: "\"", with: "」")
        s = s.replacingOccurrences(of: "'", with: "」")
        s = s.replacingOccurrences(of: "`", with: "」")
        // 簡易整形
        s = s.replacingOccurrences(of: "「「", with: "「")
        s = s.replacingOccurrences(of: "」」", with: "」")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func generateQuestions(with plans: [ItemPlan], level: ToeicLevel, types: [QuestionType]) async throws -> [ToeicQuestion] {
        let jsonSchemaExample: String = {
            switch level {
            case .l200:
                return """
                       {
                         "questions": [
                           {
                             "type": "grammar",
                             "prompt": "He (____) a teacher.,
                             "choices": ["is", "are", "am", "be"]
                           }
                         ],
                         [
                           {
                             "type": "vocabulary",
                             "prompt": "I want a (____) car.",
                             "choices": ["fast", "read", "run", "sleep"]
                           }
                         ],
                         [
                           {
                             "type": "partOfSpeech",
                             "prompt": "She works (____).",
                             "choices": ["hard", "harder", "hardness", "hardly"]
                           }
                         ]
                       }
                       """
            case .l400:
                return """
                       {
                         "questions": [
                           {
                             "type": "grammar",
                             "prompt": "The meeting (____) at 3 p.m. today.",
                             "choices": ["starts", "start", "started", "starting]
                           }
                         ],
                         [
                           {
                             "type": "vocabulary",
                             "prompt": "The company will (____) a new product soon.",
                             "choices": ["launch", "lunch", "lend", "land"]
                           }
                         ],
                         [
                           {
                             "type": "partOfSpeech",
                             "prompt": "Please be (____) when speaking to customers.",
                             "choices": ["polite", "politely", "politeness", "politer"]
                           }
                         ]
                       }
                       """
            case .l600:
                return """
                       {
                         "questions": [
                           {
                             "type": "grammar",
                             "prompt": "If the report (____) finished today, we can send it tomorrow.",
                             "choices": ["is", "was", "has", "will"]
                           }
                         ],
                         [
                           {
                             "type": "vocabulary",
                             "prompt": "The manager (____) the team to improve communication skills.",
                             "choices": ["encouraged", "entered", "enjoyed", "examined"]
                           }
                         ],
                         [
                           {
                             "type": "partOfSpeech",
                             "prompt": "The company’s (____) growth impressed many investors this year.",
                             "choices": ["rapid", "rapidly", "rapidity", "more rapid"]
                           }
                         ]
                       }
                       """
            case .l800:
                return """
                       {
                         "questions": [
                           {
                             "type": "grammar",
                             "prompt": "The software update, which was delayed due to system testing, (____) automatically once all devices are connected to the network.",
                             "choices": ["will installs", "installing", "install", "installs"]
                           }
                         ],
                         [
                           {
                             "type": "vocabulary",
                             "prompt": "The manager emphasized the need to (____) transparency and accountability throughout the organization’s decision-making process.",
                             "choices": ["maintain", "mention", "measure", "memorize"]
                           }
                         ],
                         [
                           {
                             "type": "partOfSpeech",
                             "prompt": "The newly introduced policy aims to reduce (____) among employees and improve overall workplace satisfaction.",
                             "choices": ["stress", "stressful", "stressing", "stressed"]
                           }
                         ]
                       }
                       """
            case .l990:
                return """
                       {
                         "questions": [
                           {
                             "type": "grammar",
                             "prompt": "Had the project been approved by the board earlier, the company (____) secured additional funding before the market conditions worsened.",
                             "choices": ["would have", "has", "had", "will have"]
                           }
                         ],
                         [
                           {
                             "type": "vocabulary",
                             "prompt": "To remain competitive in an increasingly volatile market, the firm must (____) innovative solutions that anticipate client needs and regulatory shifts.,
                             "choices": ["devise", "divide", "derive", "describe"]
                           }
                         ],
                         [
                           {
                             "type": "partOfSpeech",
                             "prompt": "The CEO’s speech was both (____) and inspirational, leaving the audience with a renewed sense of purpose and confidence in the company’s vision.",
                             "choices": ["persuasive", "persuade", "persuasion", "persuasively"]
                           }
                         ]
                       }
                       """
            }
        }()

        let plansForPrompt: [PlanForPrompt] = plans.sorted { $0.index < $1.index }.map { p in
            PlanForPrompt(
                index: p.index,
                type: p.type.rawValue,
                scene: .init(text: p.sceneText),
                grammar: p.grammarSubcategory,
                vocab: p.vocab?.headword,
                pos: p.pos
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let constraintsJSON = (try? String(data: encoder.encode(plansForPrompt), encoding: .utf8)) ?? "[]"
        let allowed = Array(Set(plans.map { $0.type.rawValue })).sorted().joined(separator: ", ")
        


        // Difficulty rubric per TOEIC level
        let levelRules: String = {
            switch level {
            case .l200:
                return """
                        Target difficulty: CEFR A1: 
                        - Use only very simple and common English words (e.g., work, meet, send, make, get, go, have, need, want, use, show, say).
                        - Grammar: simple present or simple past only.
                         ❌ Do NOT use passive, perfect, continuous, infinitive phrases, participial, or relative clauses.
                         ❌ Do NOT use advanced verbs like submit, confirm, complete, provide, receive, require.
                        - Use only simple vocabulary at the TOEIC 300 level.
                        - Allow only one clause (no commas, no subclauses). 'and' or 'but' is OK.
                        - Sentence length: 4–8 words.
                       """
            case .l400:
                return """
                        Target difficulty: CEFR A2:
                        - Use only simple, common business English vocabulary (avoid abstract or formal words like “regulatory,” “compliance,” “statutory,” “align”).
                        - UGrammar: use simple present, past, or future.
                        - Do not use passive, present perfect, or relative clauses with “whose,” “which,” “that.”
                        - Use only one clause per sentence (no commas or subclauses).
                        - Please use only fairly easy vocabulary at the TOEIC 500 level.
                        - Each sentence should be 8–12 words long.
                        - Avoid advanced connectors like “in light of,” “considering,” or “unless.”
                        - Use only basic conjunctions: “and,” “but,” “or,” “because,” “if,” “when.”
                        - Avoid complex noun phrases (e.g., “the internal audit procedures” → “the company rules”).
                        """
            case .l600:
                return """
                        Target difficulty: CEFR from A2 to B1-: 
                        - Focus on phrasal verbs, prepositions, and word usage (e.g., deal with, carry out, look for, depend on).
                        - Include countable/uncountable noun distinctions or comparatives/superlatives when natural.
                        - Grammar: passive, participle phrases, or one relative clause allowed.
                        - Please use only intermediate vocabulary at the TOEIC 600 level.
                        - Allow one subordinate clause (that/when/if).
                        - Sentence length: 10–15 words.
                        """
            case .l800:
                return """
                        Target difficulty: CEFR B2: 
                        - Use precise business expressions and collocations (e.g., comply with, adhere to, be subject to). Allow conditionals/hypotheticals (Type 1–2) and more natural ellipsis/participial phrasing.
                        - Ensure tone is professional and formal, but not overly academic.
                        - Please use only advanced vocabulary at the TOEIC 800 level.
                        - Sentence length: 16–24 words.
                        """
            case .l990:
                return """
                        Target difficulty: CEFR C2:
                        - Lexis: Prefer precise, high-register business/legal/technical collocations (e.g., exercise discretion, assume liability, incur costs, mitigate risk, be contingent upon, in accordance with).
                        - Semantics: Force fine-grained distinctions (collocation, valency, and preposition choice: responsible for vs responsible to; comply with vs conform to; subject to vs liable for).
                        - Grammar: Use at least one advanced device per item when natural: reduced relative, participial modifier, fronting/inversion after negative adverbials (e.g., Not only ...), complex noun pre-modification, or hypothetical with modal perfect.
                        - Register and tone: formal and precise; avoid conversational substitutes.
                        - Please use only vocabulary for advanced learners, at the TOEIC score level of 990.
                        - Sentence length: 20–28 words; allow one subordinate structure but keep exactly one blank.
                        - Vocabulary distractor policy (C1 override): For vocabulary items, use options from the same semantic field and register with near meanings that fail collocation/valency/preposition in context, so only choices[0] yields a fully idiomatic and logically correct sentence. Avoid trivial, unrelated words.
                        - Avoid overly generic headwords such as summary, suite, protocol unless the scene strictly requires them.
                        """
            }
        }()

        let system = "You are an expert TOEIC Part 5 item writer."
        let user = """
        Create 10 multiple-choice TOEIC Part 5 questions as strict JSON only.
        - Allowed categories (mix ok): \(allowed)
        - Each question MUST have exactly 4 choices and one correct answer.
        - The correct answer MUST be choices[0]. Do NOT randomize correct position.
        
        1. General constraints
        - The prompt always contains (____).
        - type is one of: grammar, partOfSpeech, vocabulary.
        - Ensure diversity across items (topics/structures/headwords). Do not repeat the same lemma in blanks.
        - Choice-set validation: exactly one correct answer; options are four DISTINCT headwords (no duplicates, no same-lemma variants, no capitalization/hyphenation-only differences); for vocabulary items the correct option MUST equal the provided vocab.headword string and MUST be placed at choices[0]; no “All/None of the above”; do NOT randomize correct answer position; avoid multiword phrases for vocabulary items.
        - Include at least one adverbial or prepositional phrase for realistic context (e.g., time, reason, condition) while keeping exactly one blank.
        - Keep sentences specific and natural. Avoid template-like prompts.

        2. Plan
        - Please make sure to follow the level of the questions written below.
        - The level of the questions cannot be too high or too low.
        \(constraintsJSON)
        
        3. Level Rules (CEFR-based)
          \(levelRules)
        
        4. Rules per Type
        - If json type key is grammar:
          - Target EXACTLY the specified grammar subcategory from grammar.json.
          - The blank must test that rule; distractors must contrast it.
          - All options must be grammatically valid in isolation.
        
        - If json type key is partOfSpeech:
          - Validate the required POS via the scene context.
          - Distractors must be POS-correct but semantically wrong.
          - Choices[0] should contain the correct part of speech, and choices[1] through choices[3] should contain different parts of speech for the same word.

        - If json type key is vocabulary:
          - You MUST include the provided target word as one of the four options (unchanged).
          - All choices must be single-word headwords of the same POS.
          - Avoid derivational or inflectional variants (e.g., manage/management/manager).
          - Distractors must be semantically plausible but incorrect in meaning or collocation.
          - The options from choices[1] to choices[3] must be completely different words from the context.
        
        5. Level-specific Distractor Policy
        - For CEFR B1 and below:
          - Distractors must be semantically FAR from the correct meaning.
          - BAN near-synonyms, quasi-synonyms, hypernyms/hyponyms, and same semantic-field alternatives.

        - For CEFR B2 and above:
          - Use near-synonyms and same-register words requiring precise collocation or valency discrimination.
          - Only the correct choice should yield a fully idiomatic, logically coherent sentence.
          - Encourage subtle distinctions in tone, usage, and lexical preference.
        
        6. Scene usage
          - Each question’s “scene” provides a contextual domain.
          - The question must logically match the given scene and vocabulary register.
          - Avoid generic or out-of-context sentences.
        
        7. Output Format Example 
          - The format should be the following json format:
          - Please create the question’s level by checking the Level Rules and the following json.
          \(jsonSchemaExample)
        """

        let decoded = try await performChat(
            model: "openai/gpt-oss-120b",
//            model: "llama-3.3-70b-versatile",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            responseFormat: .init(type: "json_object"),
            temperature: 0.2,
            topP: 0.8
        )
        guard let content = decoded.choices.first?.message.content else { throw GroqError.emptyContent }

        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = normalized.data(using: .utf8) else { return [] }
        let envelope = try JSONDecoder().decode(QuestionEnvelope.self, from: jsonData)
        var items: [ToeicQuestion] = envelope.questions.map {
            ToeicQuestion(id: UUID(),
                          type: $0.type,
                          prompt: $0.prompt,
                          choices: $0.choices,
                          answerIndex: 0)
        }
        // 二次チェック（回答の正確性検証と解説の充実化）
        do {
            let verified = try await verifyAndEnrich(items,level)
            return verified
        } catch {
            // 検証に失敗した場合は一次生成結果をそのまま返す（フォールバック）
            return items
        }
    }
}

private extension URLRequest {
    mutating func setValue(_ value: String, forHTTPHeaderFields fields: [String]) {
        for field in fields { setValue(value, forHTTPHeaderField: field) }
    }
}

// MARK: - Second-pass verification & enrichment
extension GroqToeicService {
    private func verifyAndEnrich(_ items: [ToeicQuestion],_ level: ToeicLevel) async throws -> [ToeicQuestion] {
        guard !items.isEmpty else { return items }

        // using performChat() for HTTP; no local URLRequest needed here

        // 入力問題を検証用に整形
        let payload = VerifyPayload(questions: items.enumerated().map { pair in
            let (idx, q) = pair
            return .init(
                index: idx,
                type: q.type.rawValue,
                prompt: q.prompt,
                choices: q.choices
            )
        })
        print(payload)

        var targetC2: String?
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let payloadJSON = (try? String(data: encoder.encode(payload), encoding: .utf8)) ?? "{}"

        let system = "You are an expert TOEIC Part 5 reviewer and English grammar/vocabulary instructor."
        let user = """
        REVIEW AND REPAIR the following TOEIC Part 5 multiple-choice questions.

        Phase 1 — Repair first:
        - Ensure the item has EXACTLY ONE correct answer in its current sentence context, and that the ONLY correct option is placed at choices[0].
        - If multiple options could be acceptable, MODIFY DISTRACTORS so that ONLY choices[0] remains correct. Keep the prompt unchanged. Keep exactly 4 options. Preserve the correct option string when possible and place it at choices[0].
        - Your options must consist of 1–3 words (or short phrases).
        - Explicitly sanity-check each of choices[1], choices[2], choices[3] in the completed sentence; if ANY could be acceptable to a well-informed TOEIC writer, EXCLUDE the item from the final output.
        - Remove duplicate or near-duplicate options (including same-lemma variants) and meta options like "All/None of the above"; replace with plausible but incorrect distractors that fit the context and POS.
        - Make the English sentence natural and idiomatic for business/TOEIC usage (fix awkward phrasing, collocation, or grammar if needed without changing the tested point).

        Phase 2 — Final gate (strict):
        - After repairs, re-check ALL of the following. If ANY check fails, EXCLUDE the item from the output:
          1) Exactly one correct answer AND it is choices[0] (no alternative option acceptable in context). For vocabulary items, explicitly perform the substitution test for choices[1..3] and ensure each yields a semantically WRONG or illogical sentence.
          2) 4 options, all distinct (no duplicates, no same-lemma variants, no capitalization/hyphenation-only differences).

        For each RETAINED item, produce a thorough Japanese explanation including ALL of:
        - 正解が文法・語法・意味・コロケーションの観点でなぜ正しいか（具体ルール/根拠）
        - 各誤答肢が不適切な理由（形・意味・用法不一致、コロケーション不適合 等）
        - 学習上の注意点（紛らわしい表現や似た語の違い、固定表現 等）

        Explanation formatting:
        - The explanation must be plain Japanese prose with no double quotes ("), no single quotes ('), no backslashes (\\), no backticks, and no code fences.
        - If you need to mark terms, use Japanese brackets 「」 or （） instead.

        Input JSON:
        \(payloadJSON)

        Output exactly this JSON shape (no prose):
        {
          "verified": [
            {
              "index": 0,
              "type": "grammar | partOfSpeech | vocabulary",
              "prompt": "Sentence with a blank (____)",
              "choices": ["A", "B", "C", "D"],
              "explanation": "日本語での詳細解説（最後にCEFR目標レベルとの整合性コメントを含む）",
              "filled_sentence": "正解を埋めた英文",
              "filled_sentence_ja": "上記英文の日本語訳",
              "choice_translations_ja": ["Aの日本語訳","Bの日本語訳","Cの日本語訳","Dの日本語訳"]
            }
          ]
        }

        Rules for the output array:
        - May be SHORTER than the input (items that fail the final gate must be excluded). Do NOT create new items.
        - Each object MUST correspond to an existing input index.
        - The "choices" field is OPTIONAL. When provided, it MUST contain exactly 4 strings and will REPLACE the original options to enforce a single correct answer. The correct answer MUST be choices[0]. Do NOT change the prompt.

        """

        let decoded = try await performChat(
            model: "openai/gpt-oss-120b",
//            model: "llama-3.3-70b-versatile",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            responseFormat: .init(type: "json_object")
        )
        guard let content = decoded.choices.first?.message.content else { return items }

        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = normalized.data(using: .utf8) else { return items }
        let envelope = try JSONDecoder().decode(VerifyEnvelope.self, from: jsonData)

        let map: [Int: VerifyEnvelope.Item] = Dictionary(uniqueKeysWithValues: envelope.verified.map { ($0.index, $0) })

        func safeIndex(_ idx: Int, max: Int) -> Int? {
            return (0..<max).contains(idx) ? idx : nil
        }

        // モデルが返さなかったID（=条件不適合で削除対象）は除外する
        let merged: [ToeicQuestion] = items.enumerated().compactMap { pair in
            let (idx, q) = pair
            guard let v = map[idx] else { return nil }
            let newChoices: [String] = (v.choices?.count == 4) ? (v.choices ?? q.choices) : q.choices
            // Structural gate: ensure 4 distinct options (case-insensitive)
            let lowered = newChoices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard newChoices.count == 4, Set(lowered).count == 4 else { return nil }
            return ToeicQuestion(
                id: q.id,
                type: q.type,
                prompt: q.prompt,
                choices: newChoices,
                answerIndex: 0,
                explanation: normalizeExplanation(v.explanation),
                filledSentence: v.filled_sentence,
                filledSentenceJa: v.filled_sentence_ja,
                choiceTranslationsJa: v.choice_translations_ja
            )
        }

        return merged
    }
}

// MARK: - Low-level HTTP helper
private extension GroqToeicService {
    func performChat(model: String,
                     messages: [GroqChatRequest.Message],
                     responseFormat: GroqChatRequest.ResponseFormat? = nil,
                     temperature: Double? = nil,
                     topP: Double? = nil) async throws -> GroqChatResponse {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderFields: ["Content-Type"])
        request.setValue("application/json", forHTTPHeaderFields: ["Accept"])
        request.setValue("Bearer \(apiKey)", forHTTPHeaderFields: ["Authorization"])
        request.timeoutInterval = 60
        let body = GroqChatRequest(
            model: model,
            messages: messages,
            response_format: responseFormat,
            temperature: temperature,
            top_p: topP
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw GroqError.http(status: http.statusCode, body: text)
        }
        return try JSONDecoder().decode(GroqChatResponse.self, from: data)
    }
}
