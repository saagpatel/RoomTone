import AVFoundation
import os

/// Records audio from the mixer node to a WAV file.
///
/// Uses `installTap` on the mixer output — no additional permissions needed.
/// Files written to temporaryDirectory and cleaned up on next launch.
@Observable
final class AudioRecorder {
    private let engine: AVAudioEngine
    private var audioFile: AVAudioFile?
    private var startTime: Date?
    private let logger = Logger(subsystem: "com.roomtone.app", category: "AudioRecorder")

    var isRecording: Bool = false
    var duration: TimeInterval {
        guard let startTime, isRecording else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    init(engine: AVAudioEngine) {
        self.engine = engine
        cleanupOldRecordings()
    }

    /// Start recording the mixer output to a WAV file.
    func startRecording() throws {
        guard !isRecording else { return }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let url = Self.recordingURL()

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        audioFile = file

        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            do {
                try file.write(from: buffer)
            } catch {
                // Can't log from this closure without capturing self — silently drop frames
            }
        }

        startTime = Date()
        isRecording = true
        logger.info("Recording started: \(url.lastPathComponent)")
    }

    /// Stop recording and return the file URL.
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        engine.mainMixerNode.removeTap(onBus: 0)
        let url = audioFile?.url
        audioFile = nil
        startTime = nil
        isRecording = false

        if let url {
            logger.info("Recording stopped: \(url.lastPathComponent)")
        }
        return url
    }

    // MARK: - Private

    private static func recordingURL() -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "roomtone-\(timestamp).wav"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func cleanupOldRecordings() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil
            )
            for file in files where file.lastPathComponent.hasPrefix("roomtone-") {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            logger.warning("Failed to cleanup old recordings: \(error.localizedDescription)")
        }
    }
}
