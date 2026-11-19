import Foundation

/// The Swift app and the Linux guest read the same exported browser missions.
public struct BrowserMission: Decodable, Sendable {
    public struct Desktop: Decodable, Sendable {
        public let initialApp: String
        public let photo: String?
    }

    public struct Answer: Decodable, Sendable {
        public let question: String
        public let format: String
    }

    public let episode: Episode
    public let responses: [String: Answer]
    public let repairs: [String]
    public let minimumEvidence: Int
    public let resolution: String
    public let wrongSuspect: String
    public let insufficientEvidence: String
    public let desktop: Desktop?

    public let stepsByID: [String: Guidance]

    public struct Guidance: Decodable, Sendable {
        let id: String
        public let hints: [String]
    }

    private enum Keys: String, CodingKey {
        case episode, responses, repairs, minimumEvidence, resolution, wrongSuspect, insufficientEvidence
        case steps, desktop
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: Keys.self)
        episode = try values.decode(Episode.self, forKey: .episode)
        responses = try values.decode([String: Answer].self, forKey: .responses)
        repairs = try values.decode([String].self, forKey: .repairs)
        minimumEvidence = try values.decode(Int.self, forKey: .minimumEvidence)
        resolution = try values.decode(String.self, forKey: .resolution)
        wrongSuspect = try values.decode(String.self, forKey: .wrongSuspect)
        insufficientEvidence = try values.decode(String.self, forKey: .insufficientEvidence)
        desktop = try values.decodeIfPresent(Desktop.self, forKey: .desktop)
        let guidance = try values.decode([Guidance].self, forKey: .steps)
        stepsByID = Dictionary(guidance.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static let all: [Self] = {
        guard let url = Bundle.main.url(forResource: "Missions", withExtension: "json")
                ?? Bundle.module.url(forResource: "Missions", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }()

    public static func forEpisode(_ id: Int) -> Self? {
        all.first { $0.episode.id == id }
    }

    public static func supportsDesktop(_ id: Int) -> Bool {
        id == 2 || forEpisode(id)?.desktop != nil
    }
}
