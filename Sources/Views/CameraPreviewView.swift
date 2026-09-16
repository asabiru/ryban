import SwiftUI

public struct CameraPreviewView: View {
    let image: UIImage?
    let isGlassesCamera: Bool
    let isStreaming: Bool
    
    @State private var scanOffset: CGFloat = -80
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(18)
                
                // AR HUD Reticle & Corner Brackets
                GeometryReader { geo in
                    ZStack {
                        // Center Crosshair Reticle
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 4, height: 4)
                        
                        // Corner Target Guides
                        Path { path in
                            let w = geo.size.width
                            let h = geo.size.height
                            let len: CGFloat = 16
                            
                            // Top-Left
                            path.move(to: CGPoint(x: 16, y: 16 + len))
                            path.addLine(to: CGPoint(x: 16, y: 16))
                            path.addLine(to: CGPoint(x: 16 + len, y: 16))
                            
                            // Top-Right
                            path.move(to: CGPoint(x: w - 16 - len, y: 16))
                            path.addLine(to: CGPoint(x: w - 16, y: 16))
                            path.addLine(to: CGPoint(x: w - 16, y: 16 + len))
                            
                            // Bottom-Left
                            path.move(to: CGPoint(x: 16, y: h - 16 - len))
                            path.addLine(to: CGPoint(x: 16, y: h - 16))
                            path.addLine(to: CGPoint(x: 16 + len, y: h - 16))
                            
                            // Bottom-Right
                            path.move(to: CGPoint(x: w - 16 - len, y: h - 16))
                            path.addLine(to: CGPoint(x: w - 16, y: h - 16))
                            path.addLine(to: CGPoint(x: w - 16, y: h - 16 - len))
                        }
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isGlassesCamera ? "eyeglasses" : "camera")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    
                    Text(isGlassesCamera ? "Очки готовы • Ожидание потока" : "Камера смартфона")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Top HUD Bar
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isStreaming ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text(isGlassesCamera ? "Ray-Ban Meta Live" : "iPhone Camera")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "battery.100.bolt")
                            .font(.caption2)
                        Text("Очки: 100%")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(20)
                }
                .padding(10)
                
                Spacer()
            }
        }
    }
}
