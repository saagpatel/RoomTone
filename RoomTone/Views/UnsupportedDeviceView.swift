import SwiftUI

struct UnsupportedDeviceView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sensor.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.secondary)

            Text("LiDAR Required")
                .font(.system(size: 32, weight: .bold))

            Text("Room Tone uses LiDAR to map your room's geometry and synthesize its acoustic character.\n\nThis requires an iPhone Pro or iPad Pro with a LiDAR sensor.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    UnsupportedDeviceView()
}
