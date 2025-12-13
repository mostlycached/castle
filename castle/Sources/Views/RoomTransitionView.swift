import SwiftUI

struct RoomTransitionView: View {
    let text: String
    let roomName: String
    let color: Color
    let type: RoomGuideService.TransitionType
    let onContinue: () -> Void
    
    @State private var opacity = 0.0
    @State private var textValues: [String] = []
    
    // Split text into haiku lines centered, or paragraph
    private var isHaiku: Bool {
        text.components(separatedBy: "\n").count >= 3 && text.count < 150
    }
    
    var body: some View {
        ZStack {
            color.opacity(0.15).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text(roomName.uppercased())
                    .font(.caption)
                    .tracking(4)
                    .foregroundStyle(.secondary)
                    .opacity(opacity)
                
                if isHaiku {
                    VStack(spacing: 12) {
                        ForEach(text.components(separatedBy: "\n"), id: \.self) { line in
                            Text(line)
                        }
                    }
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .opacity(opacity)
                    .animation(.easeOut(duration: 1.5).delay(0.2), value: opacity)
                } else {
                    Text(text)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 40)
                        .foregroundStyle(.primary)
                        .opacity(opacity)
                        .animation(.easeOut(duration: 1.5).delay(0.2), value: opacity)
                }
                
                Spacer()
                
                Button(action: onContinue) {
                    Text(type == .entry ? "Enter Room" : "Complete Session")
                        .font(.body.weight(.medium))
                        .foregroundStyle(color)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                        .background(color.opacity(0.1))
                        .clipShape(Capsule())
                }
                .opacity(opacity)
                .animation(.easeOut(duration: 0.5).delay(1.5), value: opacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation {
                opacity = 1.0
            }
        }
    }
}
