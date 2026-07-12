import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: "waveform",
                    title: "Your room has a voice.",
                    body: "Every room resonates at specific frequencies determined by its shape. Room Tone makes those hidden acoustics audible.",
                    tag: 0
                )

                onboardingPage(
                    icon: "figure.walk",
                    title: "Walk to hear it change.",
                    body: "Your position in the room determines which frequencies dominate. Move toward a wall to hear its resonant modes intensify.",
                    tag: 1
                )

                onboardingPage(
                    icon: "sensor.fill",
                    title: "LiDAR maps the geometry.",
                    body: "On supported devices, LiDAR helps estimate the room's dimensions. The soundscape is synthesized locally from that estimated geometry; no microphone is used.",
                    tag: 2,
                    showButton: true
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    private func onboardingPage(
        icon: String,
        title: String,
        body: String,
        tag: Int,
        showButton: Bool = false
    ) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)

            Spacer()

            if showButton {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .tag(tag)
    }
}

#Preview {
    OnboardingView()
}
