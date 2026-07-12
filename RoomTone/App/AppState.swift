import Foundation

@Observable
final class AppState {
    var scanPhase: ScanPhase = .idle
    var audioTimbre: AudioTimbre = .drone
    var isAudioPlaying: Bool = false
    var isLiDARAvailable: Bool = false

    var isScanning: Bool {
        if case .scanning = scanPhase { return true }
        return false
    }

    var isConfirmed: Bool {
        if case .confirmed = scanPhase { return true }
        return false
    }
}

enum ScanPhase: Equatable {
    case idle
    case scanning(progress: Float)
    case confirmed(dimensions: RoomDimensions)
    case failed(reason: ScanFailureReason)
}

enum ScanFailureReason: Equatable {
    case noEnclosure
    case timeout
    case deviceUnsupported
    case cameraDenied
}

enum AudioTimbre: Equatable {
    case drone
    case ambient
}
