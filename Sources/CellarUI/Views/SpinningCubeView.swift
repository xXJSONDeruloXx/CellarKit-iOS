import SwiftUI

/// A SwiftUI 3D spinning cube that mimics the DX11 Tutorial04 Hello Cube output.
/// Uses projected vertices and gradient fills to simulate a rotating colored cube.
public struct SpinningCubeView: View {
    @State private var rotation: Double = 0

    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let cx = size.width / 2
                let cy = size.height / 2
                let scale = min(size.width, size.height) * 0.28

                let angleY = time * 1.2
                let angleX = time * 0.7

                let cosY = cos(angleY)
                let sinY = sin(angleY)
                let cosX = cos(angleX)
                let sinX = sin(angleX)

                // Unit cube vertices [-1, 1]
                let verts: [(Double, Double, Double)] = [
                    (-1, -1, -1), ( 1, -1, -1), ( 1,  1, -1), (-1,  1, -1),
                    (-1, -1,  1), ( 1, -1,  1), ( 1,  1,  1), (-1,  1,  1),
                ]

                // Vertex colors (DX11 tutorial style)
                let colors: [Color] = [
                    .red, .green, .blue, .yellow,
                    .cyan, .purple, .orange, .mint,
                ]

                // Rotate and project
                let projected: [(x: Double, y: Double, z: Double)] = verts.map { v in
                    // Rotate Y
                    let x1 = v.0 * cosY - v.2 * sinY
                    let z1 = v.0 * sinY + v.2 * cosY
                    let y1 = v.1
                    // Rotate X
                    let y2 = y1 * cosX - z1 * sinX
                    let z2 = y1 * sinX + z1 * cosX
                    // Perspective
                    let d = 4.0 + z2
                    let px = cx + (x1 / d) * scale * 3
                    let py = cy + (y2 / d) * scale * 3
                    return (x: px, y: py, z: z2)
                }

                // Face indices (quads) with approximate face normals for sorting
                let faces: [(indices: [Int], label: String)] = [
                    (indices: [0, 1, 2, 3], label: "front"),
                    (indices: [5, 4, 7, 6], label: "back"),
                    (indices: [4, 0, 3, 7], label: "left"),
                    (indices: [1, 5, 6, 2], label: "right"),
                    (indices: [3, 2, 6, 7], label: "top"),
                    (indices: [4, 5, 1, 0], label: "bottom"),
                ]

                // Sort by average Z (painter's algorithm)
                let sorted = faces.sorted { a, b in
                    let az = a.indices.map { projected[$0].z }.reduce(0, +) / 4.0
                    let bz = b.indices.map { projected[$0].z }.reduce(0, +) / 4.0
                    return az < bz
                }

                for face in sorted {
                    var path = Path()
                    let pts = face.indices.map { CGPoint(x: projected[$0].x, y: projected[$0].y) }
                    path.move(to: pts[0])
                    for i in 1..<pts.count {
                        path.addLine(to: pts[i])
                    }
                    path.closeSubpath()

                    // Average color from vertex colors
                    let faceColors = face.indices.map { colors[$0] }
                    let avgZ = face.indices.map { projected[$0].z }.reduce(0, +) / 4.0
                    let brightness = (avgZ + 2) / 4.0 // depth-based shading

                    ctx.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                faceColors[0].opacity(0.6 + brightness * 0.4),
                                faceColors[2].opacity(0.6 + brightness * 0.4),
                            ]),
                            startPoint: pts[0],
                            endPoint: pts[2]
                        )
                    )

                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(0.3)),
                        lineWidth: 1
                    )
                }
            }
        }
        .background(.black)
    }
}
