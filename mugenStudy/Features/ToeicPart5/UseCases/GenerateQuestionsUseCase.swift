import Foundation

protocol GenerateQuestionsUseCase {
    func execute(level: ToeicLevel, types: Set<QuestionType>) async throws -> [ToeicQuestion]
}

final class GroqGenerateQuestionsUseCase: GenerateQuestionsUseCase {
    private let groq: GroqToeicService
    private let questionsRepo: QuestionsRepository

    init(groq: GroqToeicService, questionsRepo: QuestionsRepository) {
        self.groq = groq
        self.questionsRepo = questionsRepo
    }

    func execute(level: ToeicLevel, types: Set<QuestionType>) async throws -> [ToeicQuestion] {
        // 1) プラン生成（均等配分・ランダムシーン・補助情報）
        let plans = buildPlans(level: level, types: types)
        // 2) 生成
        let items = try await groq.generateQuestions(with: plans, level: level, types: Array(types))
        // 3) 保存
        let levelExact = mapExactLevel(level)
        try await questionsRepo.save(items: items, level: levelExact)
        return items
    }

    private func buildPlans(level: ToeicLevel, types: Set<QuestionType>, total: Int = 10) -> [ItemPlan] {
        let typePool = Array(types)
        var counts: [QuestionType: Int] = [:]
        let base = total / max(typePool.count, 1)
        let rem  = total % max(typePool.count, 1)
        for (idx, t) in typePool.enumerated() { counts[t] = base + (idx < rem ? 1 : 0) }
        var typesForPlans: [QuestionType] = []
        for t in typePool { typesForPlans += Array(repeating: t, count: counts[t] ?? 0) }
        typesForPlans.shuffle()

        let levelExact = mapExactLevel(level)

        var plans: [ItemPlan] = []
        plans.reserveCapacity(total)
        for i in 0..<total {
            let t: QuestionType = (i < typesForPlans.count) ? typesForPlans[i] : (typePool.randomElement() ?? .grammar)
            let scene = ScenesLoader.randomLabelAndScene()
            let sceneText = "\(scene?.labelJa ?? "")に関する\(scene?.scene ?? "")のシーンです"

            let grammarSub: String? = (t == .grammar) ? (CEFRGrammarLoader.randomTopic(for: level) ?? GrammarLoader.randomSubcategory()) : nil
            let vocabEntry = (t == .vocabulary) ? ScoreWordsLoader.randomWord(approxScore: levelExact) : nil
            let vocab: ItemPlan.Vocab? = vocabEntry.map { ItemPlan.Vocab(headword: $0.word, meaning: $0.meaning, pos: $0.pos) }

            let posLabel: String? = {
                guard t == .partOfSpeech else { return nil }
                let posOptions: [(ja: String, en: String)] = [
                    ("名詞", "noun"), ("動詞", "verb"), ("形容詞", "adjective"), ("副詞", "adverb"),
                    ("前置詞", "preposition"), ("接続詞", "conjunction"), ("動詞形", "verb form"),
                    ("代名詞", "pronoun"), ("冠詞", "article"), ("関係詞", "relative pronoun")
                ]
                if let pick = posOptions.randomElement() { return "\(pick.ja) (\(pick.en))" }
                return nil
            }()

            plans.append(.init(index: i + 1,
                               type: t,
                               sceneText: sceneText,
                               grammarSubcategory: grammarSub,
                               vocab: vocab,
                               pos: posLabel))
        }
        return plans
    }

    private func mapExactLevel(_ level: ToeicLevel) -> Int {
        switch level {
        case .l200: return 200
        case .l400: return 400
        case .l600: return 600
        case .l800: return 800
        case .l990: return 990
        }
    }
}


