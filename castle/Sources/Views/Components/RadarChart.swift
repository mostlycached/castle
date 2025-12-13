import SwiftUI

struct RadarChart: View {
    let data: [MasteryDimension]
    let maxValue: Double = 10.0
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            ZStack {
                // Determine step size (e.g. 5 steps for 0, 2, 4, 6, 8, 10)
                let steps = 5
                
                // Draw grid lines
                ForEach(1...steps, id: \.self) { step in
                    let stepRadius = radius * Double(step) / Double(steps)
                    RadarGrid(radius: stepRadius, sides: max(3, data.count))
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                
                // Draw data shape
                if !data.isEmpty {
                    RadarShape(data: data, maxValue: maxValue, radius: radius)
                        .fill(Color.purple.opacity(0.3))
                        .overlay {
                            RadarShape(data: data, maxValue: maxValue, radius: radius)
                                .stroke(Color.purple, lineWidth: 2)
                        }
                    
                    // Draw labels
                    ForEach(Array(data.enumerated()), id: \.element.name) { index, item in
                        let angle = (Double.pi * 2 * Double(index) / Double(data.count)) - Double.pi / 2
                        let labelRadius = radius + 15
                        let x = center.x + labelRadius * cos(angle)
                        let y = center.y + labelRadius * sin(angle)
                        
                        Text(item.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: x, y: y)
                    }
                } else {
                    Text("No dimensions analyzed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct RadarGrid: Shape {
    let radius: Double
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        for i in 0..<sides {
            let angle = (Double.pi * 2 * Double(i) / Double(sides)) - Double.pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct RadarShape: Shape {
    let data: [MasteryDimension]
    let maxValue: Double
    let radius: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let count = max(3, data.count) // Enforce at least triangle for shape
        
        for (i, item) in data.enumerated() {
            let angle = (Double.pi * 2 * Double(i) / Double(data.count)) - Double.pi / 2
            let valueRadius = radius * (item.level / maxValue)
            let point = CGPoint(
                x: center.x + valueRadius * cos(angle),
                y: center.y + valueRadius * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    RadarChart(data: [
        MasteryDimension(name: "Tone", level: 8, description: "Clear and resonant"),
        MasteryDimension(name: "Rhythm", level: 6, description: "Improving"),
        MasteryDimension(name: "Theory", level: 4, description: "Basic understanding"),
        MasteryDimension(name: "Improv", level: 7, description: "Creative"),
        MasteryDimension(name: "Repetoire", level: 5, description: "Growing")
    ])
    .frame(width: 300, height: 300)
    .padding(40)
}
