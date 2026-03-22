import Foundation

@Observable
final class AppState {
    var scanPhase: ScanPhase = .idle
    var audioTimbre: AudioTimbre = .drone
    var isAudioPlaying: Bool = false
    var isLiDARAvailable: Bool = false
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
}

enum AudioTimbre: Equatable {
    case drone
    case ambient
}
