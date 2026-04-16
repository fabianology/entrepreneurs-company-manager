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
                    // Logo preview + upload
                    VStack(spacing: 16) {
                        ZStack {
                            if let data = logoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color(hex: colorHex)
                                    Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Upload Logo", systemImage: "photo")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    logoData = data
                                }
                            }
                        }

                        if logoData != nil {
                            Button("Remove Logo") { logoData = nil }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    formSection {
                        ZifrField(label: "Entity Name", placeholder: "Acme Holdings LLC", text: $name)
                        ZifrField(label: "Website", placeholder: "acme.com", text: $website)
                            .keyboardType(.URL)
                    }

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
                                            .background(structure == s ? Color.white : Color.white.opacity(0.06))
                                            .foregroundStyle(structure == s ? Color.black : Color.white.opacity(0.6))
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
                            .glassCard(cornerRadius: 16)
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Entity", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color.zifrBG)
            .navigationTitle(isEditing ? "Edit Entity" : "New Entity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        save()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(name.isEmpty ? Color.white.opacity(0.2) : .white)
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear { prefill() }
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
}

// MARK: - Helpers

private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 14) { content() }
}
