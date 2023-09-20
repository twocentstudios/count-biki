import Dependencies
import Foundation
import IdentifiedCollections

private struct TopicGenerator: Identifiable {
    var id: UUID { topic.id }
    let topic: Topic
    var generateQuestion: @Sendable (WithRandomNumberGenerator) throws -> (Question)
}

struct Topic: Identifiable, Equatable {
    enum Skill {
        case listening
        case reading
    }

    enum Category {
        case number
        case money
        case duration
        case dateTime
        case counter
    }

    let id: UUID
    let skill: Skill
    let category: Category
    let title: String
    let description: String
    var notesMarkdown: String = ""
}

extension Topic.Skill {
    var title: String {
        switch self {
        case .listening: "Listening"
        case .reading: "Reading"
        }
    }
}

extension Topic.Category {
    var title: String {
        switch self {
        case .number: "Numbers"
        case .money: "Money"
        case .duration: "Time Durations"
        case .dateTime: "Dates & Times"
        case .counter: "Counters"
        }
    }

    var description: String {
        switch self {
        case .number: "Just whole numbers"
        case .money: "Using money in common situations"
        case .duration: "Lengths of time from seconds to years"
        case .dateTime: "Dates on a calendar"
        case .counter: "Objects and more: Objects and more: 個、枚、人、..."
        }
    }
}

struct Question: Equatable {
    let topicID: UUID
    let displayText: String
    let spokenText: String
    let answerPrefix: String?
    let answerPostfix: String?
    let acceptedAnswer: String
}

struct Submission: Identifiable, Equatable {
    enum Kind: Equatable {
        case correct
        case incorrect
        case skip
    }

    let id: UUID
    let date: Date
    let kind: Kind
    let value: String?
}

struct Challenge: Identifiable, Equatable {
    let id: UUID
    let startDate: Date
    let question: Question
    var submissions: [Submission]
}

struct TopicClient {
    var allTopics: @Sendable () -> IdentifiedArrayOf<Topic>
    var generateQuestion: @Sendable (UUID) throws -> (Question)
}

extension Topic {
    static func id(for intValue: Int) -> UUID {
        UUID(uuidString: "C27296D2-934F-42DD-9F48-\(String(format: "%012x", intValue))")!
    }

    static let mockID: UUID = Topic.id(for: 000)
    fileprivate static let mockGenerator = TopicGenerator(
        topic: Topic(
            id: Self.mockID,
            skill: .listening,
            category: .number,
            title: "Mock topic",
            description: "Just the number 1"
        ),
        generateQuestion: { _ in
            Question(topicID: Self.mockID, displayText: "1", spokenText: "1", answerPrefix: nil, answerPostfix: nil, acceptedAnswer: "1")
        }
    )
}

func numberQuestionGenerator(for range: ClosedRange<Int>, topicID: UUID) -> @Sendable (WithRandomNumberGenerator) throws -> (Question) {
    { rng in
        let answer = rng { Int.random(in: range, using: &$0) }
        let displayText = answer.formatted(.number.grouping(.automatic))
        let acceptedAnswer = String(answer)
        let question = Question(
            topicID: topicID,
            displayText: displayText,
            spokenText: displayText,
            answerPrefix: nil,
            answerPostfix: nil,
            acceptedAnswer: acceptedAnswer
        )
        return question
    }
}

func moneyGenerator(for range: ClosedRange<Int>, by byValue: Int, topicID: UUID) -> @Sendable (WithRandomNumberGenerator) throws -> (Question) {
    { rng in
        let byRange = Int(Double(range.lowerBound) / Double(byValue)) ... Int(Double(range.upperBound) / Double(byValue))
        let answer = rng { Int.random(in: byRange, using: &$0) * byValue }
        let prefix = "￥"
        let displayText = "\(prefix)\(answer.formatted(.number.grouping(.automatic)))"
        let acceptedAnswer = String(answer)
        let question = Question(
            topicID: topicID,
            displayText: displayText,
            spokenText: displayText,
            answerPrefix: prefix,
            answerPostfix: nil,
            acceptedAnswer: acceptedAnswer
        )
        return question
    }
}

extension TopicClient: DependencyKey {
    static var liveValue: TopicClient {
        @Dependency(\.withRandomNumberGenerator) var rng
        let allTopicGenerators: IdentifiedArrayOf<TopicGenerator> = [
            /// Listening -> Number
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 001),
                    skill: .listening,
                    category: .number,
                    title: "Absolute Beginner",
                    description: "Whole numbers between 1-10"
                ),
                generateQuestion: numberQuestionGenerator(for: 1 ... 10, topicID: Topic.id(for: 001))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 002),
                    skill: .listening,
                    category: .number,
                    title: "Beginner",
                    description: "Whole numbers between 1-100"
                ),
                generateQuestion: numberQuestionGenerator(for: 1 ... 100, topicID: Topic.id(for: 002))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 003),
                    skill: .listening,
                    category: .number,
                    title: "Intermediate",
                    description: "Whole numbers between 1-1,000"
                ),
                generateQuestion: numberQuestionGenerator(for: 1 ... 1_000, topicID: Topic.id(for: 003))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 004),
                    skill: .listening,
                    category: .number,
                    title: "Advanced",
                    description: "Whole numbers between 1-10,000"
                ),
                generateQuestion: numberQuestionGenerator(for: 1 ... 10_000, topicID: Topic.id(for: 004))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 005),
                    skill: .listening,
                    category: .number,
                    title: "Extreme",
                    description: "Whole numbers between 1-1,000,000,000"
                ),
                generateQuestion: numberQuestionGenerator(for: 1 ... 1_000_000_000, topicID: Topic.id(for: 005))
            ),

            /// Listening -> Money
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 101),
                    skill: .listening,
                    category: .money,
                    title: "Conbini",
                    description: "Yen amounts between 100-1,500"
                ),
                generateQuestion: moneyGenerator(for: 100 ... 1500, by: 1, topicID: Topic.id(for: 101))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 102),
                    skill: .listening,
                    category: .money,
                    title: "Restaurant",
                    description: "Yen amounts between 800-6,000 by 10s"
                ),
                generateQuestion: moneyGenerator(for: 800 ... 6_000, by: 10, topicID: Topic.id(for: 102))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 103),
                    skill: .listening,
                    category: .money,
                    title: "Monthly Rent",
                    description: "Yen amounts between 30,000-200,000 by 1,000s"
                ),
                generateQuestion: moneyGenerator(for: 30_000 ... 200_000, by: 1_000, topicID: Topic.id(for: 103))
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 104),
                    skill: .listening,
                    category: .money,
                    title: "Annual Salary",
                    description: "Yen amounts between 2,000,000-15,000,000 by 100,000s"
                ),
                generateQuestion: moneyGenerator(for: 2_000_000 ... 15_000_000, by: 100_000, topicID: Topic.id(for: 104))
            ),

            /// Listening -> Duration
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 201),
                    skill: .listening,
                    category: .duration,
                    title: "Hours",
                    description: "1-48時間"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 48, using: &$0) }
                    let postfix = "時間"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 201),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 202),
                    skill: .listening,
                    category: .duration,
                    title: "Minutes",
                    description: "1-100分間"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 100, using: &$0) }
                    let postfix = "分間"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 202),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 203),
                    skill: .listening,
                    category: .duration,
                    title: "Seconds",
                    description: "1-100秒間"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 100, using: &$0) }
                    let postfix = "秒間"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 203),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            // TODO: Hours/Minutes e.g. 24時間60分
            // TODO: Hours/Minutes/Seconds e.g. 24時間60分60秒
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 206),
                    skill: .listening,
                    category: .duration,
                    title: "Days",
                    description: "1-100日(間)",
                    notesMarkdown: """
                    - This topic chooses durations in the range 1-10 in equal probability to 11-100.
                    - 間 is optional after 日 except for 1日 where 間 cannot be appended.
                    - 1日 is pronounced いちにち as a duration (as opposed to ついたち as a date).

                    **Reference**: [A Guide to the Japanese Counter-ish Word: 日 (Days)](https://www.tofugu.com/japanese/japanese-counter-ka-nichi/)
                    """
                ),
                generateQuestion: { rng in
                    // 1 ... 10 range is emphasized
                    let range = rng { [1 ... 10, 11 ... 100].randomElement(using: &$0)! }
                    let answer = rng { Int.random(in: range, using: &$0) }
                    let postfix = "日"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 206),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 207),
                    skill: .listening,
                    category: .duration,
                    title: "Weeks",
                    description: "1-52週間"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 52, using: &$0) }
                    let postfix = "週間"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 207),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 208),
                    skill: .listening,
                    category: .duration,
                    title: "Months",
                    description: "1-18ヶ月",
                    notesMarkdown: """
                    - This topic only tests on the ヶ月 reading for counting month durations.
                    - However, ひとつき (1月) and ふたつき (2月) readings are also common.

                    **Reference**: [A Guide to the Japanese Counter-ish Word: 月 (Months)](https://www.tofugu.com/japanese/japanese-counter-tsuki-gatsu-getsu/)
                    """
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 18, using: &$0) }
                    let postfix = "ヶ月"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 208),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 209),
                    skill: .listening,
                    category: .duration,
                    title: "Years",
                    description: "1-100年間"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 100, using: &$0) }
                    let postfix = "年間"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 209),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),

            /// Listening -> DateTime
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 301),
                    skill: .listening,
                    category: .dateTime,
                    title: "Hour (24-hour)",
                    description: "1-24時"
                ),
                generateQuestion: { rng in
                    let range = rng { [1 ... 12, 1 ... 12, 13 ... 24].randomElement(using: &$0)! }
                    let answer = rng { Int.random(in: range, using: &$0) }
                    let postfix = "時"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 301),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 302),
                    skill: .listening,
                    category: .dateTime,
                    title: "Hour (AM/PM)",
                    description: "午前・午後1-12時"
                ),
                generateQuestion: { rng in
                    // According to https://www.tofugu.com/japanese/japanese-counter-ji-jikan/ , 午後12時 is 12pm, which means 午後 is an exact translation of pm.
                    // However, many sites say that 午後12時 and 午前12時 are ambiguous so alternates are preferred. Even the alternates are not always obvious.
                    // For example: 0:00 = 午前0時 or 真夜中, 12:00 = 午後0時 or 正午.
                    let prefix = rng { ["午前", "午後"].randomElement(using: &$0)! }
                    let answer = rng { Int.random(in: 1 ... 12, using: &$0) }
                    let postfix = "時"
                    let displayText = "\(prefix)\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 302),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 303),
                    skill: .listening,
                    category: .dateTime,
                    title: "Hour (AM/PM as 24-hour)",
                    description: "午前・午後1-12時 -> 1-24時"
                ),
                generateQuestion: { rng in
                    // See notes in previous topic.
                    enum Prefix: Int {
                        case am = 0
                        case pm = 1

                        var title: String {
                            switch self {
                            case .am: "午前"
                            case .pm: "午後"
                            }
                        }
                    }
                    let prefix: Prefix = rng { [.am, .pm].randomElement(using: &$0)! }
                    let hour = rng { Int.random(in: 1 ... 12, using: &$0) }
                    let answer = hour + (prefix.rawValue * 12)
                    let postfix = "時"
                    let displayText = "\(answer)\(postfix)"
                    let spokenText = "\(prefix.title)\(hour)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 303),
                        displayText: displayText,
                        spokenText: spokenText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 304),
                    skill: .listening,
                    category: .dateTime,
                    title: "Minute",
                    description: "0-59分"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 0 ... 59, using: &$0) }
                    let postfix = "分"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 304),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 305),
                    skill: .listening,
                    category: .dateTime,
                    title: "Day of Month (Beginner)",
                    description: "1日-10日"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 10, using: &$0) }
                    let postfix = "日"
                    let exceptions: [Int: String] = [
                        1: "ついたち",
                    ]
                    let displayText = "\(answer)\(postfix)"
                    let spokenText = exceptions[answer] ?? displayText
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 305),
                        displayText: displayText,
                        spokenText: spokenText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 306),
                    skill: .listening,
                    category: .dateTime,
                    title: "Day of Month (All)",
                    description: "1日-31日"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 31, using: &$0) }
                    let postfix = "日"
                    let exceptions: [Int: String] = [
                        1: "ついたち",
                    ]
                    let displayText = "\(answer)\(postfix)"
                    let spokenText = exceptions[answer] ?? displayText
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 306),
                        displayText: displayText,
                        spokenText: spokenText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 307),
                    skill: .listening,
                    category: .dateTime,
                    title: "Month",
                    description: "1月-12月"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 12, using: &$0) }
                    let postfix = "月"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 307),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 308),
                    skill: .listening,
                    category: .dateTime,
                    title: "Year (Recent)",
                    description: "2010年-2025年"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 2010 ... 2025, using: &$0) }
                    let postfix = "年"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 308),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 309),
                    skill: .listening,
                    category: .dateTime,
                    title: "Year (Contemporary)",
                    description: "1950年-2030年"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1950 ... 2030, using: &$0) }
                    let postfix = "年"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 309),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 310),
                    skill: .listening,
                    category: .dateTime,
                    title: "Year (A.D.)",
                    description: "1年-2500年"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 2500, using: &$0) }
                    let postfix = "年"
                    let displayText = "\(answer)\(postfix)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 310),
                        displayText: displayText,
                        spokenText: displayText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: Topic.id(for: 311),
                    skill: .listening,
                    category: .dateTime,
                    title: "Year (日本 to Gregorian)",
                    description: "昭和/平成/令和 -> 1926年-2024年"
                ),
                generateQuestion: { rng in
                    enum Era: CaseIterable {
                        case showa
                        case heisei
                        case reiwa

                        var title: String {
                            switch self {
                            case .showa: "昭和"
                            case .heisei: "平成"
                            case .reiwa: "令和"
                            }
                        }

                        var length: Int {
                            switch self {
                            case .showa: 64
                            case .heisei: 31
                            case .reiwa: 6
                            }
                        }

                        var start: Int {
                            switch self {
                            case .showa: 1926
                            case .heisei: 1989
                            case .reiwa: 2019
                            }
                        }
                    }
                    let era = rng { Era.allCases.randomElement(using: &$0)! }
                    let japaneseYear = rng { Int.random(in: 1 ... era.length, using: &$0) }
                    let answer = era.start + japaneseYear - 1
                    let postfix = "年"
                    let displayText = "\(answer)\(postfix)"
                    let spokenText = "\(era.title)\(japaneseYear)"
                    let acceptedAnswer = String(answer)
                    return Question(
                        topicID: Topic.id(for: 311),
                        displayText: displayText,
                        spokenText: spokenText,
                        answerPrefix: nil,
                        answerPostfix: postfix,
                        acceptedAnswer: acceptedAnswer
                    )
                }
            ),
        ]
        return TopicClient(
            allTopics: {
                IdentifiedArray(uniqueElements: allTopicGenerators.map(\.topic))
            },
            generateQuestion: { topicID in
                struct NoTopicForIDError: Error {}
                guard let topicGenerator = allTopicGenerators[id: topicID] else { throw NoTopicForIDError() }
                return try topicGenerator.generateQuestion(rng)
            }
        )
    }
}

extension TopicClient: TestDependencyKey {
    static let previewValue: TopicClient = .mock

    static var testValue: TopicClient {
        Self(
            allTopics: unimplemented("allTopics"),
            generateQuestion: unimplemented("generateQuestion")
        )
    }

    static var mock: TopicClient {
        Self(
            allTopics: {
                let array = IdentifiedArray(uniqueElements: [Topic.mockGenerator.topic])
                return array
            },
            generateQuestion: { _ in
                @Dependency(\.withRandomNumberGenerator) var rng
                return try! Topic.mockGenerator.generateQuestion(rng)
            }
        )
    }
}

extension DependencyValues {
    var topicClient: TopicClient {
        get { self[TopicClient.self] }
        set { self[TopicClient.self] = newValue }
    }
}
