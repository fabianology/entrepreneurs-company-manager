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
            } else if !company.website.isEmpty {
                AsyncImage(url: faviconURL(for: company.website)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(8)
                    default:
                        initialsView
                    }
                }
                .background(Color.white)
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.35))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.35)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var initialsView: some View {
        ZStack {
            Color(hex: company.colorHex)
            Text(company.initial)
                .font(.system(size: size * 0.40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func faviconURL(for website: String) -> URL? {
        var host = website
        if !host.hasPrefix("http") { host = "https://\(host)" }
        guard let url = URL(string: host), let scheme = url.scheme, let h = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(h)&sz=128")
    }
}
