import AppKit
import AVFoundation
import SwiftUI
import StaffelCore

struct Einsatzszene: View {
    let episodeID: Int
    let solved: Bool
    @Binding var michaActivity: Date
    let isShowingExternalVideo: Bool
    let openTerminal: () -> Void
    let openDesktop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artwork = Einsatzbilder()
    @State private var pointer = CGSize.zero
    @State private var line: Funktext?
    @State private var player: AVAudioPlayer?
    @State private var level: CGFloat = 0
    @State private var audioUnavailable = false
    @State private var showingArtwork = false
    @State private var showingRoom = false
    @State private var showingPhoto = false
    @State private var finaleScene: FinaleScene?
    @State private var michaMotion: AVPlayer?
    @State private var pendingWake = false

    private var cues: [Funktext] {
        let entries = episodeID == 0 ? Funktext.introduction : Funktext.episodes[String(episodeID)] ?? []
        return entries.filter { solved || !$0.id.hasSuffix("-abschluss") }
    }

    private var episodeClip: FinaleScene? {
        switch episodeID {
        case 4: .briefing
        case 5 where solved: .dispatch
        case 6: .clocks
        case 7 where solved: .credits
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            stage
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.sm) {
                    voiceControls
                    Spacer()
                    sceneControls
                }
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(spacing: Space.sm) { voiceControls }
                    HStack(spacing: Space.sm) { sceneControls }
                }
            }
            if episodeID > 0 {
                HStack(spacing: Space.sm) {
                    Button {
                        stop()
                        showingRoom = true
                    } label: {
                        Label("3D-Serverraum", systemImage: "cube")
                    }
                    if BrowserMission.supportsDesktop(episodeID) {
                        Button(action: openDesktop) {
                            Label("Linux-Bildschirm", systemImage: "display")
                        }
                    }
                    if episodeID == 2 {
                        Button {
                            stop()
                            showingPhoto = true
                        } label: {
                            Label("Wartungsfoto", systemImage: "photo")
                        }
                    }
                    if let episodeClip {
                        Button {
                            stop()
                            michaMotion?.pause()
                            michaMotion = nil
                            finaleScene = episodeClip
                        } label: {
                            Label(episodeClip.title, systemImage: "play.rectangle")
                        }
                    }
                }
            }
            michaAssistant
            if let line {
                HStack(alignment: .top, spacing: Space.md) {
                    if let portrait = artwork.portrait(for: line, speaking: player != nil) {
                        Image(nsImage: portrait)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("\(line.speaker) · \(line.title)")
                            .font(.headline)
                        Text(line.transcript)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if audioUnavailable {
                            Label("Sprachclip nicht verfügbar", systemImage: "speaker.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.callout)
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onDisappear {
            stop()
            michaMotion?.pause()
            michaMotion = nil
        }
        .sheet(isPresented: $showingRoom) {
            OstwindRoomView(episodeID: episodeID, solved: solved)
        }
        .sheet(isPresented: $showingPhoto) {
            MaintenancePhotoView()
        }
        .sheet(item: $finaleScene) { FinaleSceneView(scene: $0) }
        .onChange(of: isShowingExternalVideo) { _, showing in
            if showing {
                stop()
                pendingWake = false
                michaMotion?.pause()
                michaMotion = nil
            }
        }
        .task(id: pendingWake) {
            guard pendingWake else { return }
            await animateMicha("micha-wacht")
            guard !Task.isCancelled, pendingWake else { return }
            pendingWake = false
            if let clip = Funktext.micha["wake"] { play(clip) }
        }
        .task(id: player) {
            guard let activePlayer = player else { return }
            while !Task.isCancelled, activePlayer.isPlaying {
                if !reduceMotion {
                    activePlayer.updateMeters()
                    let power = CGFloat(activePlayer.averagePower(forChannel: 0))
                    level = max(0, min(1, (power + 42) / 42))
                }
                try? await Task.sleep(for: .milliseconds(65))
            }
            if !Task.isCancelled, player === activePlayer { stop() }
        }
    }

    private var voiceControls: some View {
        ForEach(cues) { playbackButton($0) }
    }

    private var michaAssistant: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let speaking = line?.speaker == "Micha" && player != nil
            let asleep = !speaking && !(episodeID == 7 && solved)
                && timeline.date.timeIntervalSince(michaActivity) >= 32
            HStack(spacing: Space.md) {
                if let michaMotion {
                    TrailerPlayer(player: michaMotion, controls: .none)
                        .frame(width: 92, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                } else if let image = asleep ? artwork.michaSleeping : artwork.michaAwake {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Micha").font(.headline)
                    Label(asleep ? "Döst kurz" : speaking ? "Spricht" : "Assistenz",
                          systemImage: asleep ? "moon.zzz" : speaking ? "waveform" : "person.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer()
                Button {
                    if speaking {
                        stop()
                        return
                    }
                    michaActivity = .now
                    if asleep {
                        stop()
                        pendingWake = true
                    } else if let clip = Funktext.micha[String(episodeID)] {
                        play(clip)
                    }
                } label: {
                    Label(speaking ? "Micha stoppen" : asleep ? "Micha wecken" : "Micha fragen",
                          systemImage: speaking ? "stop.fill" : asleep ? "bell" : "questionmark.bubble")
                }
                .buttonStyle(.bordered)
                .disabled(pendingWake || michaMotion != nil)
            }
            .padding(Space.md)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: asleep)
            .task(id: asleep) {
                if asleep && finaleScene == nil && !isShowingExternalVideo && player == nil {
                    await animateMicha("micha-doest")
                }
            }
        }
    }

    private func animateMicha(_ name: String) async {
        guard episodeID >= 4, !reduceMotion, michaMotion == nil, let url = FinaleScene.url(for: name) else { return }
        let video = AVPlayer(url: url)
        video.isMuted = true
        michaMotion = video
        defer {
            video.pause()
            if michaMotion === video { michaMotion = nil }
        }
        let duration = (try? await video.currentItem?.asset.load(.duration).seconds) ?? 4
        guard !Task.isCancelled, michaMotion === video else { return }
        video.play()
        try? await Task.sleep(for: .seconds(duration.isFinite ? min(duration, 8) : 4))
    }

    @ViewBuilder
    private var sceneControls: some View {
        Button {
            stop()
            showingArtwork = true
        } label: {
            Label("Originalgrafiken", systemImage: "photo.on.rectangle")
        }
        .popover(isPresented: $showingArtwork, arrowEdge: .bottom) { gallery }
        Button(action: openTerminal) {
            Label("Zum Terminal", systemImage: "terminal")
        }
        .buttonStyle(.borderedProminent)
    }

    private var stage: some View {
        GeometryReader { geometry in
            let offset = reduceMotion ? CGSize.zero : pointer
            let movement = reduceMotion ? 0 : level
            let micha = artwork.michaInChair
            let figureHeight = min(geometry.size.height - 24, geometry.size.width * 0.36)
            let chairHeight = figureHeight * 0.77
            let alexX = geometry.size.width * (micha == nil ? 0.76 : 0.66)
            let michaX = geometry.size.width * 0.84
            let floorY = geometry.size.height - 8

            ZStack(alignment: .bottomLeading) {
                Color(red: 0.06, green: 0.10, blue: 0.12)
                if let room = artwork.room {
                    Image(nsImage: room)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .scaleEffect(1.08)
                        .offset(x: -offset.width * 8, y: -offset.height * 4) // grid: ok Parallaxe
                }
                LinearGradient(
                    stops: [.init(color: .black.opacity(0.88), location: 0),
                            .init(color: .black.opacity(0.62), location: 0.34),
                            .init(color: .clear, location: 0.78)],
                    startPoint: .leading, endPoint: .trailing
                )
                Ellipse()
                    .fill(.black.opacity(0.62))
                    .frame(width: 128, height: 24)
                    .blur(radius: 9)
                    .position(x: alexX, y: floorY - 8) // grid: ok Figurenschatten
                if let character = artwork.figure {
                    Image(nsImage: character)
                        .resizable()
                        .scaledToFit()
                        .frame(height: figureHeight)
                        .rotation3DEffect(.degrees(Double(offset.width) * 8),
                                          axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                        .scaleEffect(1 + movement * 0.014, anchor: .bottom)
                        .position(x: alexX + offset.width * 20, // grid: ok Parallaxe
                                  y: floorY - figureHeight / 2 + offset.height * 4)
                        .animation(.easeOut(duration: 0.10), value: movement)
                }
                if let micha {
                    Ellipse()
                        .fill(.black.opacity(0.66))
                        .frame(width: chairHeight * 0.93, height: chairHeight * 0.11)
                        .blur(radius: 8)
                        .position(x: michaX, y: floorY - 3) // grid: ok Stuhlschatten
                    Image(nsImage: micha)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.27, height: chairHeight)
                        .rotation3DEffect(.degrees(Double(offset.width) * 5),
                                          axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                        .position(x: michaX + offset.width * 13, // grid: ok Parallaxe
                                  y: floorY - chairHeight / 2 + offset.height * 3)
                        .accessibilityLabel("Micha schläft im Bürostuhl neben Alex")
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Rechenwerk Ostwind")
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                    Text("Alex · Einsatzbegleitung")
                        .font(.callout)
                    if let line, line.speaker == "Alex", player != nil {
                        Label(line.title, systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(Space.lg)
                .accessibilityElement(children: .combine)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard !reduceMotion else { return }
                    pointer = CGSize(width: location.x / geometry.size.width * 2 - 1,
                                     height: location.y / geometry.size.height * 2 - 1)
                case .ended:
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        pointer = .zero
                    }
                }
            }
        }
        .frame(height: 256)
    }

    private var gallery: some View {
        HStack(alignment: .top, spacing: Space.md) {
            galleryImage(artwork.poster, title: "Terminal-Missionen")
            galleryImage(artwork.commands, title: "Linux-Befehle")
        }
        .padding(Space.lg)
    }

    private func galleryImage(_ image: NSImage?, title: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 180)
                    .accessibilityHidden(true)
            }
            Text(title).font(.headline)
        }
    }

    private func playbackButton(_ cue: Funktext) -> some View {
        let playing = line == cue && player != nil
        return Button {
            if playing {
                stop()
            } else {
                play(cue)
            }
        } label: {
            Label(playing ? "\(cue.title) stoppen" : cue.title,
                  systemImage: playing ? "stop.fill" : "speaker.wave.2")
        }
        .buttonStyle(.bordered)
    }

    private func play(_ cue: Funktext) {
        stop()
        line = cue
        audioUnavailable = true
        guard let url = Einsatzbilder.url(cue.id, "mp3"),
              let audio = try? AVAudioPlayer(contentsOf: url) else { return }
        audio.isMeteringEnabled = true
        guard audio.play() else { return }
        audioUnavailable = false
        player = audio
    }

    private func stop() {
        player?.stop()
        player = nil
        level = 0
    }
}

private struct Funktext: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let transcript: String
    var speaker: String { id.hasPrefix("micha-") ? "Micha" : "Alex" }

    static let introduction = [
        Self(id: "staffel-2-briefing", title: "Begrüßung",
             transcript: "Willkommen im Rechenwerk Ostwind. Ich bin Alex und begleite dich durch deinen ersten Einsatz. Im Archiv stimmt etwas nicht. Sieh dich zuerst im Terminal um und sammle Beweise, bevor du einen Vorwurf erhebst."),
        Self(id: "staffel-2-archiv", title: "Archivhinweis",
             transcript: "Im Archiv steckt die Vorgeschichte. Prüfe die Metadaten und vergleiche die Originalzeilen. Erst wenn du die Abweichung belegen kannst, weißt du, welche Korrektur sinnvoll ist."),
    ]

    static let episodes: [String: [Self]] = {
        guard let url = Einsatzbilder.url("episodenstimmen", "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [Self]].self, from: data)) ?? [:]
    }()

    static let micha: [String: Self] = {
        guard let url = Einsatzbilder.url("micha-stimmen", "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Self].self, from: data)) ?? [:]
    }()
}

struct Einsatzbilder {
    let room = load("serverraum", "webp")
    let figure = load("alex-figur", "png")
    let neutral = load("alex-portraet", "png")
    let thoughtful = load("alex-portraet-konzentriert", "png")
    let poster = load("terminal_missions_hero", "png")
    let commands = load("linux_commands_preview", "svg")
    let michaAwake = load("micha-awake", "jpg")
    let michaSleeping = load("micha-sleep", "jpg")
    let michaInChair = load("micha-buerostuhl", "png")

    fileprivate func portrait(for cue: Funktext, speaking: Bool) -> NSImage? {
        if cue.speaker == "Micha" { return michaAwake }
        return speaking && !cue.id.hasSuffix("-briefing") ? thoughtful : neutral
    }

    static func url(_ name: String, _ fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Einsatzszene")
    }

    static func load(_ name: String, _ fileExtension: String) -> NSImage? {
        url(name, fileExtension).flatMap(NSImage.init(contentsOf:))
    }
}

struct MaintenancePhotoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text("Wartungsfoto").font(.title2.bold())
                Spacer()
                Button("Schließen") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if let photo = Einsatzbilder.load("wiederganger-zettel", "png") {
                Image(nsImage: photo)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Wartungszettel für den Wächter des Lagerabgleichs. Die Änderung ist R W, Bindestrich, zwei eins zwei zwei.")
            }
        }
        .padding(Space.xl)
        .frame(width: 720)
    }
}
