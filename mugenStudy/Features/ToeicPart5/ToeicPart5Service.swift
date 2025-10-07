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
        let jsonSchemaExample = """
        {
          "questions": [
            {
              "type": "grammar | partOfSpeech | vocabulary",
              "prompt": "Sentence with a blank (____)",
              "choices": ["CORRECT", "DISTRACTOR", "DISTRACTOR", "DISTRACTOR"]
            }
          ]
        }
        """

        let plansForPrompt: [PlanForPrompt] = plans.sorted { $0.index < $1.index }.map { p in
            PlanForPrompt(
                index: p.index,
                type: p.type.rawValue,
                scene: .init(text: p.sceneText),
                grammar: p.grammarSubcategory,
                vocab: p.vocab?.headword
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
                        Target difficulty: CEFR A1–A2: Use only very simple and common English words (e.g., work, meet, send, make, get, go, have, need, want, use, show, say).
                        - Grammar: simple present or simple past only.
                         ❌ Do NOT use passive, perfect, continuous, infinitive phrases, participial, or relative clauses.
                         ❌ Do NOT use advanced verbs like submit, confirm, complete, provide, receive, require.
                        - Allow only one clause (no commas, no subclauses). 'and' or 'but' is OK.
                        - Sentence length: 12–18 words.
                       """
            case .l400:
                return """
                        Target difficulty: CEFR A2–B1: - Include basic business collocations (e.g., place an order, attend a meeting, take a break, send an email).
                        - Grammar: simple present, past, or progressive are allowed; **passive** may appear once.
                        - Present perfect may appear rarely.
                        - Allow at most ONE simple subordinate clause (that/when/if/because).
                        - Sentence length: 14–20 words.
                        """
            case .l600:
                return """
                        Target difficulty: CEFR B1: Focus on phrasal verbs, prepositions, and word usage (e.g., deal with, carry out, look for, depend on).
                        - Include countable/uncountable noun distinctions or comparatives/superlatives when natural.
                        - Grammar: passive, participle phrases, or one relative clause allowed.
                        - Allow one subordinate clause (that/when/if).
                        - Sentence length: 15–22 words.
                        """
            case .l800:
                return """
                        Target difficulty: CEFR B2: Use precise business expressions and collocations (e.g., comply with, adhere to, be subject to). Allow conditionals/hypotheticals (Type 1–2) and more natural ellipsis/participial phrasing.
                        - Ensure tone is professional and formal, but not overly academic.
                        - Sentence length: 16–24 words.
                        """
            case .l990:
                return """
                        Target difficulty: CEFR C2:
                        - Lexis: Prefer precise, high-register business/legal/technical collocations (e.g., exercise discretion, assume liability, incur costs, mitigate risk, be contingent upon, in accordance with).
                        - Semantics: Force fine-grained distinctions (collocation, valency, and preposition choice: responsible for vs responsible to; comply with vs conform to; subject to vs liable for).
                        - Grammar: Use at least one advanced device per item when natural: reduced relative, participial modifier, fronting/inversion after negative adverbials (e.g., Not only ...), complex noun pre-modification, or hypothetical with modal perfect.
                        - Register and tone: formal and precise; avoid conversational substitutes.
                        - Sentence length: 20–28 words; allow one subordinate structure but keep exactly one blank.
                        - Avoid overly generic headwords such as summary, suite, protocol unless the scene strictly requires them.
                        """
            }
        }()
        
        var targetC1: String?
        if level == .l990 {
            targetC1 = "Vocabulary distractor policy (C2 override): For vocabulary items, use options from the same semantic field and register with near meanings that fail collocation/valency/preposition in context, so only choices[0] yields a fully idiomatic and logically correct sentence. Avoid trivial, unrelated words.Please update it to use near‑synonym distractors that require precise discrimination of collocation and valency/subcategorization, and to employ advanced constructions."
        } else {
            targetC1 = "Critically, ALL distractors (choices[1], choices[2], choices[3]) MUST be semantically FAR from the correct meaning in the given sentence context and MUST make the completed sentence unambiguously incorrect or illogical. BAN near-synonyms, quasi-synonyms, collocational substitutes, hypernyms/hyponyms, and same semantic-field alternatives that could still fit the sentence. Keep POS-matched but choose distractors from DIFFERENT semantic classes/domains so the sentence clearly fails with them. "
        }

        let system = "You are an expert TOEIC Part 5 item writer."
        let user = """
        Create 10 multiple-choice TOEIC Part 5 questions as strict JSON only.
        - Allowed categories (mix ok): \(allowed)
        - Each question MUST have exactly 4 choices and one correct answer.
        - The correct answer MUST be choices[0]. Do NOT randomize correct position.
        - \(levelRules)

        Follow these per-item plans EXACTLY (1-to-1 by index; do not invent/omit/modify any plan):
        \(constraintsJSON)

        Rules per type:
        - grammar: Target EXACTLY the provided "grammar" subcategory from grammar.json. The blank must test that rule; distractors should contrast it.
        - vocabulary: You MUST include the provided vocab.headword (from the plan) as one of the four options and make it the ONLY correct answer. Use the headword string EXACTLY as provided (case-insensitive), do not alter it. All four choices MUST be distinct single-word headwords of the SAME part of speech (POS), like TOEIC Part 5 vocabulary items. Do NOT use inflectional/derivational variants of the same lemma among the options (no plural -s, -ed/-ing forms, comparative/superlative, or same-stem derivations like manage/management/manager). Avoid capitalization-only differences and hyphenation variants.
        - partOfSpeech: Validate the required POS via the scene context; distractors must be POS-correct but semantically wrong.
        \(targetC1)
        - Please review the generated question to ensure it follows the specified CEFR level. If it does not fully match the level, regenerate it repeatedly until it fits the level accurately.

        Scene usage:
        - Use the provided "scene.text" naturally (do not name the label). Make the sentence context fit that scene.

        General constraints:
        - The prompt contains a single blank like (____).
        - type is one of: grammar, partOfSpeech, vocabulary.
        - Ensure diversity across items (topics/structures/headwords). Do not repeat the same lemma in blanks.
        - Choice-set validation: exactly one correct answer; options are four DISTINCT headwords (no duplicates, no same-lemma variants, no capitalization/hyphenation-only differences); for vocabulary items the correct option MUST equal the provided vocab.headword string and MUST be placed at choices[0]; no “All/None of the above”; do NOT randomize correct answer position; avoid multiword phrases for vocabulary items.
        - Include at least one adverbial or prepositional phrase for realistic context (e.g., time, reason, condition) while keeping exactly one blank.
        - Keep sentences specific and natural. Avoid template-like prompts.

        Output exactly the following JSON shape and nothing else (no prose):
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

        var targetC1: String?
        if level == .l990 {
            targetC1 = "Target level: CEFR C1 (TOEIC 990). Upgrade items to this level while preserving the tested point and a single correct answer."
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let payloadJSON = (try? String(data: encoder.encode(payload), encoding: .utf8)) ?? "{}"

        let system = "You are an expert TOEIC Part 5 reviewer and English grammar/vocabulary instructor."
        let user = """
        REVIEW AND REPAIR the following TOEIC Part 5 multiple-choice questions.
        
        Phase 1 — Repair first:
        - Ensure the item has EXACTLY ONE correct answer in its current sentence context, and that the ONLY correct option is placed at choices[0].
        - If multiple options could be acceptable, MODIFY DISTRACTORS so that ONLY choices[0] remains correct. Keep the prompt unchanged. Keep exactly 4 options. Preserve the correct option string when possible and place it at choices[0].
        - Explicitly sanity-check each of choices[1], choices[2], choices[3] in the completed sentence; if ANY could be acceptable to a well-informed TOEIC writer, EXCLUDE the item from the final output.
        - Fix an incorrect answerIndex to the correct 0..3 position.
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
        - この問題がCEFRのどのランクか評価して欲しい(例　A1, A2, B1, B2, C1, C2)

        Explanation formatting:
        - The explanation must be plain Japanese prose with no double quotes ("), no single quotes ('), no backslashes (\\), no backticks, and no code fences. If you need to mark terms, use Japanese brackets 「」 or （） instead.

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
              "explanation": "日本語での詳細解説",
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
