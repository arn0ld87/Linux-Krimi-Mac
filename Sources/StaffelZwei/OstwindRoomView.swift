import AppKit
import RealityKit
import SwiftUI

/// The evidence racks are modeled as geometry on macOS. Original portraits stay in the briefing.
struct OstwindRoomView: View {
    let episodeID: Int
    let solved: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var rotation = 12.0
    @State private var showingPhoto = false

    private var title: String {
        switch episodeID {
        case 1: "Rack · Fernwartung"
        case 2: "Rack · Lagerabgleich"
        case 4: "Rack · Freigabe und Vorlage"
        case 5: "Rack · Lokaler Ausgang"
        case 6: "Rack · Zeitquellen"
        case 7: "Rack · Übergabe"
        default: "Anmeldelog und Spiegel"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                Button("Schließen") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            RealityView { content in
                content.camera = .virtual
                content.add(makeRoom())
                let camera = PerspectiveCamera()
                camera.name = "StaffelZwei-Kamera"
                content.add(camera)
                orient(camera)
            } update: { content in
                if let camera = content.entities.first(where: { $0.name == "StaffelZwei-Kamera" }) {
                    orient(camera)
                }
            }
            .frame(height: 400)
            .background(Color(red: 0.035, green: 0.070, blue: 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(title + ", räumliche Ansicht")

            HStack(spacing: Space.lg) {
                Slider(value: $rotation, in: -55...55) { Text("Blickwinkel") }
                Button("Zentrieren") { rotation = 12 }
                if episodeID == 2 {
                    Button("Wartungsfoto") { showingPhoto = true }
                }
            }
        }
        .padding(Space.xl)
        .frame(width: 780)
        .sheet(isPresented: $showingPhoto) { MaintenancePhotoView() }
    }

    private func orient(_ camera: Entity) {
        let angle = Float(rotation * .pi / 180)
        let position = SIMD3<Float>(sin(angle) * 5.2, 2.25, cos(angle) * 5.2)
        camera.look(at: [0, 1.12, 0], from: position, relativeTo: nil)
    }

    private func makeRoom() -> Entity {
        let root = Entity()
        let dark = NSColor(srgbRed: 0.10, green: 0.16, blue: 0.22, alpha: 1)
        let steel = NSColor(srgbRed: 0.26, green: 0.34, blue: 0.40, alpha: 1)
        let amber = NSColor(srgbRed: 1.0, green: 0.59, blue: 0.20, alpha: 1)
        let turquoise = NSColor(srgbRed: 0.22, green: 0.88, blue: 0.81, alpha: 1)
        let violet = NSColor(srgbRed: 0.59, green: 0.50, blue: 1, alpha: 1)
        let green = NSColor(srgbRed: 0.33, green: 0.95, blue: 0.55, alpha: 1)
        let accent: NSColor
        switch episodeID {
        case 1, 4: accent = amber
        case 2, 6: accent = turquoise
        case 7: accent = solved ? green : amber
        default: accent = violet
        }

        root.addChild(box([7, 0.12, 7], at: [0, -0.08, 0], color: dark))
        for stripe in -4...4 {
            root.addChild(box([0.016, 0.016, 6.6], at: [Float(stripe) * 0.62, 0, 0], color: steel))
        }
        for rack in -1...1 {
            let x = Float(rack) * 1.24
            let z: Float = rack == 0 ? -0.36 : -0.65
            let rackColor = rack == 0 ? accent : steel
            root.addChild(box([1.02, 2.25, 0.87], at: [x, 1.13, z], color: dark))
            for flank in [-1, 1] {
                root.addChild(box([0.07, 2.20, 0.08],
                                  at: [x + Float(flank) * 0.46, 1.13, z + 0.47], color: rackColor))
            }
            for unit in 0..<9 {
                let y = Float(unit) * 0.21 + 0.30
                root.addChild(box([0.83, 0.16, 0.09], at: [x, y, z + 0.44], color: steel))
                root.addChild(box([0.38, 0.045, 0.10], at: [x - 0.12, y, z + 0.46], color: dark))
                for led in 0..<3 {
                    let color = unit % 4 == 0 ? amber : turquoise
                    root.addChild(box([0.025, 0.023, 0.025],
                                      at: [x + 0.21 + Float(led) * 0.06, y, z + 0.51],
                                      color: color, lit: false))
                }
            }
        }

        if episodeID == 2 || episodeID == 4 {
            let paper = NSColor(srgbRed: 0.90, green: 0.83, blue: 0.50, alpha: 1)
            root.addChild(box([0.37, 0.29, 0.023], at: [0.35, 1.57, 0.24], color: paper, lit: false))
            for line in 0..<3 {
                root.addChild(box([0.25, 0.013, 0.015], at: [0.35, 1.62 - Float(line) * 0.05, 0.26],
                                  color: dark, lit: false))
            }
        } else if episodeID == 6 {
            root.addChild(box([1.75, 0.10, 0.62], at: [0, 0.84, 0.92], color: steel))
            for x: Float in [-0.45, 0.45] {
                root.addChild(box([0.54, 0.35, 0.18], at: [x, 1.07, 0.98], color: dark))
                root.addChild(box([0.43, 0.24, 0.02], at: [x, 1.07, 1.08],
                                  color: x < 0 ? amber : turquoise, lit: false))
            }
        } else {
            let x: Float = episodeID == 1 ? 0 : 0.76
            root.addChild(box([0.71, 0.41, 0.07], at: [x, 1.13, 0.48], color: dark))
            root.addChild(box([0.63, 0.33, 0.025], at: [x, 1.13, 0.53], color: accent, lit: false))
            for row in 0..<4 {
                root.addChild(box([0.48 - Float(row % 2) * 0.16, 0.023, 0.02],
                                  at: [x - 0.035, 1.23 - Float(row) * 0.065, 0.55], color: dark, lit: false))
            }
            if episodeID == 5 || episodeID == 7 {
                root.addChild(box([0.62, 0.07, 0.40], at: [x, 0.65, 0.72], color: steel))
                root.addChild(box([0.08, 0.05, 0.04], at: [x + 0.25, 0.68, 0.93], color: accent, lit: false))
            }
        }
        let key = PointLight()
        key.position = [1.5, 3.25, 2.5]
        key.light.intensity = 1750
        key.light.attenuationRadius = 9
        root.addChild(key)
        let fill = PointLight()
        fill.position = [-2.2, 1.75, 0.8]
        fill.light.color = accent
        fill.light.intensity = 800
        fill.light.attenuationRadius = 7
        root.addChild(fill)
        return root
    }

    private func box(_ size: SIMD3<Float>, at position: SIMD3<Float>, color: NSColor, lit: Bool = true) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        let material: any RealityKit.Material = lit
            ? SimpleMaterial(color: color, roughness: 0.56, isMetallic: true)
            : UnlitMaterial(color: color)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        return entity
    }
}
