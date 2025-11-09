import Foundation

public struct VocabRange: Hashable {
    public let start: Int
    public let end: Int
    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

public struct VocabScore: Hashable {
    public let total: Int
    public let correct: Int
    public init(total: Int, correct: Int) {
        self.total = total
        self.correct = correct
    }
}

public extension VocabRange {
    static func split(range: VocabRange, chunk: Int = 10) -> [VocabRange] {
        var result: [VocabRange] = []
        var s = range.start
        while s <= range.end {
            let e = min(s + chunk - 1, range.end)
            result.append(VocabRange(start: s, end: e))
            s = e + 1
        }
        return result
    }
}
