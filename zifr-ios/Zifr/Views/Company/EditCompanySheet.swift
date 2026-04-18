import SwiftUI
import SwiftData
import PhotosUI

struct EditCompanySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: AppViewModel
    var company: Company?

    @State private var name: String = ""
    @State private var structure: String = "LLC"
    @State private var colorHex: String = "#4f46e5"
    @State private var website: String = ""
    @State private var logoData: Data? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showDeleteConfirm = false

    var isEditing: Bool { company != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Entity Name Row
                    HStack(spacing: 16) {
                        ZStack {
                            if let data = logoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color(hex: colorHex)
                                    Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            if logoData != nil {
                                Button { logoData = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red, .white)
                                        .font(.system(size: 20))
                                }
                                .padding(4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .offset(x: 8, y: -8)
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        formSection {
                            ZifrField(label: "Entity Name", placeholder: "Acme Holdings LLC", text: $name)
                        }
                    }
                    .padding(.top, 8)

                    // Website Row
                    HStack(spacing: 16) {
                        formSection {
                            ZifrField(label: "Website", placeholder: "acme.com", text: $website)
                                .keyboardType(.URL)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("UPLOAD")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                            }
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 76)
                            .frame(maxHeight: .infinity) // fills height of HStack defined by formSection
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    logoData = data
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true) // forces HStack to adhere to formSection's natural height

                    // Structure picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entity Structure")
                            .zifrLabel()
                            .padding(.horizontal, 4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Company.structures, id: \.self) { s in
                                    Button {
                                        structure = s
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text(s)
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(structure == s ? Color(hex: "#222E2F") : Color.white.opacity(0.06))
                                            .foregroundStyle(structure == s ? Color(hex: "#A2A2A2") : Color.white.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Identity Color")
                            .zifrLabel()
                            .padding(.horizontal, 4)
                        HStack(spacing: 10) {
                            ForEach(Company.brandColors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                    logoData = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(Color.white.opacity(0.5), lineWidth: colorHex == hex && logoData == nil ? 2 : 0)
                                        )
                                        .scaleEffect(colorHex == hex && logoData == nil ? 1.15 : 1)
                                        .animation(.spring(response: 0.3), value: colorHex)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    VStack(spacing: 30) {
                        // App Navigators
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APP NAVIGATORS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .padding(.leading, 4)
                            
                            HStack(spacing: 12) {
                                navButton(icon: "square.3.layers.3d", color: Color(hex: "#2070BD"), text: "Subscriptions") {
                                    if let company { vm.selectedCompany = company; vm.activeTab = .subscriptions; dismiss() }
                                }
                                navButton(icon: "creditcard", color: Color(hex: "#1A7077"), text: "Financials") {
                                    if let company { vm.selectedCompany = company; vm.activeTab = .financial; dismiss() }
                                }
                                navButton(icon: "doc.text", color: Color(hex: "#918457"), text: "Docs") {
                                    if let company { vm.selectedCompany = company; vm.activeTab = .documents; dismiss() }
                                }
                            }
                        }

                        // Tutorial
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                Text("Tutorial")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.black)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)

                        // Delete
                        if isEditing {
                            if showDeleteConfirm {
                                HStack(spacing: 20) {
                                    Text("Delete this entity?")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.red)
                                    Button("Yes, Delete") {
                                        if let company { vm.deleteCompany(company, context: context) }
                                        dismiss()
                                    }
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.red)
                                    Button("Cancel") { showDeleteConfirm = false }
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .glassCard(cornerRadius: 16)
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDeleteConfirm = true
                                } label: {
                                    Text("DELETE \(name.isEmpty ? "ENTITY" : name.uppercased())")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(2)
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.red.opacity(0.05))
                                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color.zifrBG)
            .navigationTitle(isEditing ? "Edit Entity" : "New Entity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Cancel (X)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .liquidGlass(cornerRadius: 18)
                        }
                        
                        // Save (Checkmark)
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            save()
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle((hasChanges && !name.isEmpty) ? Color.green : Color.white.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .liquidGlass(cornerRadius: 18)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasChanges)
                        }
                        .disabled(!hasChanges || name.isEmpty)
                    }
                }
            }
        }
        .onAppear { prefill() }
    }

    private var hasChanges: Bool {
        if let c = company {
            return name != c.name ||
                   structure != c.structure ||
                   colorHex != c.colorHex ||
                   website != c.website ||
                   logoData != c.logoData
        } else {
            return !name.isEmpty
        }
    }

    private func prefill() {
        guard let c = company else { return }
        name = c.name
        structure = c.structure
        colorHex = c.colorHex
        website = c.website
        logoData = c.logoData
    }

    private func save() {
        if let c = company {
            c.name = name; c.structure = structure; c.colorHex = colorHex
            c.website = website; c.logoData = logoData
            vm.updateCompany(c, context: context)
        } else {
            vm.addCompany(context: context, name: name, structure: structure, colorHex: colorHex, logoData: logoData, website: website)
        }
    }

    private func navButton(icon: String, color: Color, text: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Text(text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "#171717"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 14) { content() }
}
