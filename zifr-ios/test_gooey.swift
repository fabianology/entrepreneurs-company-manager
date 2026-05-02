import SwiftUI
import AppKit

struct GooeyTestView: View {
    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 300, height: 100)
            .mask {
                Canvas { context, size in
                    context.addFilter(.alphaThreshold(min: 0.5, color: .black))
                    context.addFilter(.blur(radius: 8))
                    context.drawLayer { ctx in
                        if let resolved = context.resolveSymbol(id: 1) {
                            ctx.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height / 2))
                        }
                    }
                } symbols: {
                    HStack(spacing: 12) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 44, height: 44)
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 200, height: 44)
                    }
                    .tag(1)
                }
            }
            .background(Color.red)
    }
}

let view = GooeyTestView().frame(width: 300, height: 100)
let hosting = NSHostingView(rootView: view)
hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 100)

let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
hosting.cacheDisplay(in: hosting.bounds, to: rep)
let data = rep.representation(using: .png, properties: [:])
try! data?.write(to: URL(fileURLWithPath: "gooey.png"))
print("Saved gooey.png")
