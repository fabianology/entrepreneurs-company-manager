import SwiftUI
import AppKit

struct GooeyTestView: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            GeometryReader { geo in
                let w = geo.size.width
                let searchWidth = w - 44 - 12
                
                ZStack {
                    Canvas { context, size in
                        context.addFilter(.alphaThreshold(min: 0.5, color: Color(red: 0.1, green: 0.1, blue: 0.12)))
                        context.addFilter(.blur(radius: 8))
                        
                        context.drawLayer { ctx in
                            if let blobs = context.resolveSymbol(id: "blobs") {
                                ctx.draw(blobs, at: CGPoint(x: size.width / 2, y: size.height / 2))
                            }
                        }
                    } symbols: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 44, height: 44)
                            
                            Capsule()
                                .fill(Color.black)
                                .frame(width: max(searchWidth, 0), height: 44)
                        }
                        .frame(width: w, height: 44)
                        .tag("blobs")
                    }
                    .frame(width: w + 40, height: 44 + 40)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(width: max(searchWidth, 0), height: 44)
                        .foregroundStyle(.secondary)
                    }
                    .frame(width: w)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)
        }
        .frame(width: 390, height: 200)
    }
}

let view = GooeyTestView()
let hosting = NSHostingView(rootView: view)
hosting.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
hosting.layoutSubtreeIfNeeded()

if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    let data = rep.representation(using: .png, properties: [:])
    try! data?.write(to: URL(fileURLWithPath: "gooey_test.png"))
    print("Saved gooey_test.png")
} else {
    print("Failed to create bitmapImageRep")
}
