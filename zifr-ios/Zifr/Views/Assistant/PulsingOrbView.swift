import SwiftUI

enum OrbActivity {
    case idle, listening, speaking
}

/// Retarget from the visible blend, including when a turn is interrupted mid-fade.
struct OrbTransition {
    struct Blend {
        var speaking: Double = 0
        var listening: Double = 0
    }
    private var from = Blend()
    private var target = Blend()
    private var startedAt: TimeInterval = 0
    static let duration = 0.7

    func value(at time: TimeInterval) -> Blend {
        let progress = min(1, max(0, (time - startedAt) / Self.duration))
        let eased = progress * progress * (3 - 2 * progress)
        return Blend(speaking: from.speaking + (target.speaking - from.speaking) * eased,
                     listening: from.listening + (target.listening - from.listening) * eased)
    }

    mutating func set(_ activity: OrbActivity, at time: TimeInterval, animated: Bool) {
        from = value(at: time)
        target = Blend(speaking: activity == .speaking ? 1 : 0,
                       listening: activity == .listening ? 1 : 0)
        startedAt = animated ? time : time - Self.duration
    }
}

/// A procedural, deforming mesh: cool translucent shell around warm moving energy.
struct PulsingOrbView: View {
    var volume: Float
    var outputVolume: Float = 0
    var inputPitch: Float = 0
    var isActive = true
    var activity: OrbActivity = .idle
    @State private var transition = OrbTransition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || !isActive || scenePhase != .active)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let time = reduceMotion || !isActive ? 0 : now
            let blend = transition.value(at: now)
            let energy = reduceMotion || !isActive ? 0
                : Double(outputVolume) * blend.speaking + Double(volume) * blend.listening
            Canvas { context, size in
                Self.draw(context: &context, size: size, time: time, energy: energy,
                          activity: activity, reduceMotion: reduceMotion, blend: blend,
                          pitch: reduceMotion ? 0 : Double(inputPitch))
            }
        }
        .onAppear {
            transition.set(activity, at: Date.timeIntervalSinceReferenceDate, animated: false)
        }
        .onChange(of: activity) { _, value in
            transition.set(value, at: Date.timeIntervalSinceReferenceDate, animated: !reduceMotion)
        }
        .onChange(of: reduceMotion) { _, _ in
            transition.set(activity, at: Date.timeIntervalSinceReferenceDate, animated: false)
        }
        .frame(maxWidth: 320, maxHeight: 320)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    static func draw(context: inout GraphicsContext, size: CGSize, time: Double, energy: Double,
                     activity: OrbActivity = .idle, reduceMotion: Bool = false,
                     blend: OrbTransition.Blend? = nil, pitch: Double = 0) {
        let speaking = blend?.speaking ?? (activity == .speaking ? 1 : 0)
        let listening = blend?.listening ?? (activity == .listening ? 1 : 0)
        let active = speaking + listening
        let energy = min(1, max(0, energy))
        let pitch = min(1, max(0, pitch))
        // One continuous phase for the surface: switching mode never resets or
        // multiplies the clock, which would instantly warp the mesh.
        let motionTime = reduceMotion ? 0 : time
        let time = motionTime * 0.9
        let pulse = reduceMotion ? 0 : 0.015 * speaking * sin(time * 5)
            + 0.009 * listening * sin(time * 1.3)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * (0.315 + pulse + energy * (0.018 + speaking * 0.017))
        let blue = Color(red: 0.26, green: 0.58, blue: 0.9)
        let amber = Color(red: 1, green: 0.48, blue: 0.06)
        let accent = Color(red: 0.26 + speaking * 0.74,
                           green: 0.58 - speaking * 0.1, blue: 0.9 - speaking * 0.84)
        // Every layer follows the orb's own contour, so energy emerges from
        // the surface instead of looking like separate rings around it.
        func contour(scale: Double = 1) -> Path {
            var path = Path()
            for index in 0...240 {
                let angle = Double(index) / 240 * .pi * 2
                let ripple = sin(angle * 7 + time * 0.7) * 0.03
                    + sin(angle * 13 - time * 0.5) * 0.015
                let r = radius * scale * (1 + ripple)
                let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
        let shell = contour()
        if active > 0 {
            for index in 0..<3 {
                let offset = Double(index) / 3
                let outward = reduceMotion ? offset + 0.1
                    : (motionTime * 0.8 + offset).truncatingRemainder(dividingBy: 1)
                context.drawLayer { aura in
                    aura.addFilter(.blur(radius: radius * (0.045 + outward * 0.035)))
                    aura.stroke(contour(scale: 0.96 + outward * 0.39),
                                with: .color(amber.opacity(speaking * pow(1 - outward, 1.6) * (0.55 + energy * 0.3))),
                                lineWidth: radius * (0.09 + outward * 0.07))
                }
                let inward = reduceMotion ? offset + 0.1
                    : (motionTime * 0.34 + offset).truncatingRemainder(dividingBy: 1)
                let ring = contour(scale: 1.36 - inward * 0.4)
                let intensity = listening * sin(inward * .pi) * (0.22 + pitch * 0.4 + energy * 0.14)
                context.drawLayer { halo in
                    halo.addFilter(.blur(radius: radius * 0.035))
                    halo.stroke(ring, with: .color(blue.opacity(intensity * 0.8)), lineWidth: radius * 0.08)
                }
                // A fine ring remains visible outside, then softens into the edge.
                context.stroke(ring, with: .color(blue.opacity(intensity * (1 - inward * 0.6))),
                               lineWidth: 0.8 + pitch * 1.2)
            }
        }
        let bounds = CGRect(x: center.x - radius * 1.5, y: center.y - radius * 1.5,
                            width: radius * 3, height: radius * 3)
        context.fill(Path(ellipseIn: bounds), with: .radialGradient(
            Gradient(colors: [accent.opacity(0.13 + energy * 0.12), accent.opacity(0.025), .clear]),
            center: center, startRadius: radius * 0.4, endRadius: radius * 1.5))

        func point(_ latitude: Double, _ longitude: Double, swell: Double = 0) -> CGPoint {
            let latitude = max(-Double.pi / 2, min(Double.pi / 2, latitude))
            let poleFalloff = pow(max(0, cos(latitude)), 0.8)
            let wave = (sin(latitude * 7 + longitude * 4 + time * 0.8) * 0.037
                + sin(longitude * 9 - latitude * 5 - time * 0.55) * 0.022
                + cos(latitude * 13 + longitude * 3 + time) * 0.013) * poleFalloff
            let r = radius * (1 + wave * (1 + energy) + swell)
            let x = cos(latitude) * sin(longitude)
            let y = sin(latitude)
            let z = cos(latitude) * cos(longitude)
            // Tilt the sphere slightly to show its surface structure.
            return CGPoint(x: center.x + r * (x * 0.97 + y * 0.2),
                           y: center.y + r * (y * 0.94 - x * 0.15 + z * 0.08))
        }

        context.fill(shell, with: .radialGradient(
            Gradient(colors: [Color(red: 0.055, green: 0.04, blue: 0.04),
                              Color(red: 0.025, green: 0.065, blue: 0.11), blue.opacity(0.35)]),
            center: CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.3),
            startRadius: 0, endRadius: radius * 1.45))

        context.drawLayer { core in
            core.clip(to: shell)
            for index in 0..<3 {
                let phase = time * 0.35 + Double(index) * 1.8
                let origin = CGPoint(x: center.x + radius * (0.25 + sin(phase) * 0.23),
                                     y: center.y + radius * (-0.28 + cos(phase * 0.7) * 0.23))
                let reach = radius * (0.6 + energy * 0.08)
                core.fill(Path(ellipseIn: CGRect(x: origin.x - reach, y: origin.y - reach,
                                                width: reach * 2, height: reach * 2)),
                          with: .radialGradient(Gradient(colors: [
                            Color(red: 1, green: 0.68, blue: 0.12).opacity(0.55),
                            amber.opacity(0.26), .clear]), center: origin,
                            startRadius: 0, endRadius: reach))
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.07))
            layer.stroke(shell, with: .color(blue.opacity(0.5)), lineWidth: radius * 0.06)
            for band in 0..<5 {
                var path = Path()
                for step in 0...110 {
                    let longitude = -.pi / 2 + Double(step) / 110 * .pi
                    let latitude = -0.85 + Double(band) * 0.36
                        + sin(longitude * 3 + time * 0.6 + Double(band)) * 0.17
                    let p = point(latitude, longitude)
                    if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                layer.stroke(path, with: .linearGradient(
                    Gradient(colors: [amber.opacity(0.02), amber.opacity(0.65), Color.yellow.opacity(0.65), amber.opacity(0.05)]),
                    startPoint: CGPoint(x: center.x - radius, y: center.y),
                    endPoint: CGPoint(x: center.x + radius, y: center.y - radius * 0.4)), lineWidth: radius * 0.07)
            }
        }

        // Fine latitude and longitude filaments drift independently across the shell.
        var mesh = context
        mesh.clip(to: shell)
        for row in 0..<88 {
            let latitude = -.pi / 2 + (Double(row) + 0.5) / 88 * .pi
            var path = Path()
            for column in 0...100 {
                let longitude = -.pi / 2 + Double(column) / 100 * .pi
                let p = point(latitude + sin(longitude * 3 + time * 0.45) * 0.035 * cos(latitude), longitude)
                if column == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            let warmth = max(0, sin(latitude * 9 + time * 0.5))
            mesh.stroke(path, with: .linearGradient(
                Gradient(colors: [blue.opacity(0.42), amber.opacity(0.12 + warmth * 0.58),
                                  Color(red: 1, green: 0.76, blue: 0.32).opacity(warmth * 0.7), blue.opacity(0.55)]),
                startPoint: CGPoint(x: center.x - radius, y: center.y + radius * 0.4),
                endPoint: CGPoint(x: center.x + radius, y: center.y - radius * 0.5)), lineWidth: 0.45)
        }
        for column in 0..<70 {
            let longitude = -.pi / 2 + Double(column) / 70 * .pi
            var path = Path()
            for row in 0...70 {
                let latitude = -.pi / 2 + Double(row) / 70 * .pi
                let p = point(latitude, longitude + sin(latitude * 4 + time * 0.3) * 0.045)
                if row == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            mesh.stroke(path, with: .color(blue.opacity(0.11)), lineWidth: 0.4)
        }
        if active > 0 {
            context.drawLayer { surface in
                surface.clip(to: shell)
                surface.addFilter(.blur(radius: radius * 0.045))
                surface.stroke(shell, with: .color(accent.opacity(active * (0.4 + energy * 0.25))),
                               lineWidth: radius * 0.15)
            }
        }
        context.stroke(shell, with: .color(blue.opacity(0.45)), lineWidth: 0.8)
    }
}

struct LiveVoicePanel: View {
    let entries: [LiveTranscriptEntry]
    let inputVolume: Float
    let outputVolume: Float
    var inputPitch: Float = 0
    let isActive: Bool
    let microphoneMuted: Bool
    var isListening = false
    var isSpeaking = false
    let onToggleMicrophone: () -> Void
    let onType: () -> Void
    let onEnd: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            PulsingOrbView(volume: inputVolume, outputVolume: outputVolume, inputPitch: inputPitch,
                           isActive: isActive,
                           activity: !isActive ? .idle : isSpeaking ? .speaking
                               : isListening && !microphoneMuted ? .listening : .idle)
                .frame(height: 280)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.speaker == .user ? "You" : "Miloom")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entry.speaker == .user ? Color.white.opacity(0.45) : Color.orange.opacity(0.9))
                                Text(entry.text + (entry.interrupted ? " …" : ""))
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(entry.speaker == .user ? 0.7 : 0.95))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .frame(maxHeight: 230)
                .onChange(of: entries) { _, entries in
                    if let last = entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            HStack(spacing: 20) {
                Button(action: onToggleMicrophone) {
                    Image(systemName: microphoneMuted ? "mic.slash.fill" : "mic.fill")
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(microphoneMuted ? 0.18 : 0.08), in: Circle())
                }
                .accessibilityLabel(microphoneMuted ? "Unmute microphone" : "Mute microphone")
                Button(action: onType) {
                    Label("Type Instead", systemImage: "keyboard")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                Button(action: onEnd) {
                    Image(systemName: "phone.down.fill")
                        .frame(width: 46, height: 46)
                        .background(.red.opacity(0.2), in: Circle())
                }
                .accessibilityLabel("End voice conversation")
            }
            .foregroundStyle(.white.opacity(0.85))
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
    }


}
