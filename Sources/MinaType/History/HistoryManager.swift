import Foundation
import Combine

public struct HistoryRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let text: String
    public let wordCount: Int
    public let duration: Double
    public let model: String
    public let wasPolished: Bool
    public let appName: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        duration: Double = 0.0,
        model: String = "Whisper",
        wasPolished: Bool = false,
        appName: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.wordCount = text.split { $0.isWhitespace }.count
        self.duration = duration
        self.model = model
        self.wasPolished = wasPolished
        self.appName = appName
    }
}

public final class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()

    @Published public private(set) var records: [HistoryRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.krishna.minaflow.history", qos: .utility)

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MinaFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")

        loadRecords()
    }

    // MARK: - Public Metrics

    public var totalTranscriptions: Int {
        records.count
    }

    public var totalWords: Int {
        records.reduce(0) { $0 + $1.wordCount }
    }

    /// Estimated typing time saved (assuming average human typing speed of 40 WPM).
    /// Speech is ~150 WPM vs typing at 40 WPM.
    public var timeSavedMinutes: Double {
        Double(totalWords) / 40.0
    }

    public var timeSavedFormatted: String {
        let minutes = timeSavedMinutes
        if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = minutes / 60.0
            return String(format: "%.1f hrs", hours)
        }
    }

    // MARK: - Mutations

    public func addRecord(
        text: String,
        duration: Double = 0.0,
        model: String = "Whisper",
        wasPolished: Bool = false,
        appName: String = ""
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = HistoryRecord(
            text: trimmed,
            duration: duration,
            model: model,
            wasPolished: wasPolished,
            appName: appName
        )

        DispatchQueue.main.async {
            self.records.insert(record, at: 0)
            if self.records.count > 1000 {
                self.records = Array(self.records.prefix(1000))
            }
            self.saveRecordsAsync()
        }
    }

    public func deleteRecord(id: UUID) {
        DispatchQueue.main.async {
            self.records.removeAll { $0.id == id }
            self.saveRecordsAsync()
        }
    }

    public func clearAll() {
        DispatchQueue.main.async {
            self.records.removeAll()
            self.saveRecordsAsync()
        }
    }

    // MARK: - Persistence

    private func loadRecords() {
        queue.async {
            guard FileManager.default.fileExists(atPath: self.fileURL.path),
                  let data = try? Data(contentsOf: self.fileURL),
                  let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                self.records = decoded
            }
        }
    }

    private func saveRecordsAsync() {
        let snapshot = self.records
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: self.fileURL, options: .atomic)
        }
    }
}
