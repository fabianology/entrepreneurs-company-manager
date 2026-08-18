import SwiftUI

struct CompanyAvatar: View {
    let company: Company
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if let data = company.logoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.35))
    }

    private var initialsView: some View {
        ZStack {
            company.brandColor
            Text(company.initial)
                .font(.system(size: size * 0.40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func faviconURL(for website: String) -> URL? {
        var host = website
        if !host.hasPrefix("http") { host = "https://\(host)" }
        guard let url = URL(string: host), let _ = url.scheme, let h = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(h)&sz=128")
    }
}
