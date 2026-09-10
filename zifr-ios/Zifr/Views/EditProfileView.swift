import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM
    
    @Binding var userEmail: String
    
    @State private var newEmail: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1C1C1E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ZifrSheetCard(
                            title: "PROFILE PHOTO",
                            contentHorizontalPadding: 0,
                            contentTopPadding: 0,
                            contentBottomPadding: 0
                        ) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottom) {
                                    profileImageContent
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 210)
                                        .clipped()
                                        .overlay {
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.08),
                                                    Color.black.opacity(0.66)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        }

                                    HStack(spacing: 8) {
                                        Image(systemName: "photo.fill")
                                        Text("CHANGE PHOTO")
                                            .tracking(0.6)
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "#171914"))
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(Color.miloomGold)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                                    .padding(.bottom, 18)

                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.45))
                                            .clipShape(Circle())
                                            .padding(14)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 210)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = Image(uiImage: uiImage)
                                        await uploadPhoto(data: data)
                                    }
                                }
                            }
                        }

                        ZifrSheetCard(title: "ACCOUNT EMAIL") {
                            VStack(spacing: 14) {
                                ZifrField(
                                    label: "EMAIL ADDRESS",
                                    placeholder: "name@example.com",
                                    text: $newEmail,
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress
                                )
                                .textInputAutocapitalization(.never)

                                Button {
                                    Task { await saveEmail() }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isLoading {
                                            ProgressView()
                                                .tint(Color(hex: "#171914"))
                                        }
                                        Text(isLoading ? "Saving…" : "Save Changes")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                }
                                .buttonStyle(MiloomPrimaryButtonStyle())
                                .disabled(newEmail == userEmail || newEmail.isEmpty || isLoading)
                                .opacity(newEmail == userEmail || newEmail.isEmpty ? 0.5 : 1)

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.red.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .disabled(isLoading)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#1C1C1E"))
        .onAppear {
            newEmail = userEmail
        }
    }

    @ViewBuilder
    private var profileImageContent: some View {
        if let selectedImage {
            selectedImage
                .resizable()
                .scaledToFill()
        } else if let user = authVM.currentUser,
                  case let .string(avatarURLString) = user.userMetadata["avatar_url"],
                  let avatarURL = URL(string: avatarURLString) {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    profilePhotoPlaceholder
                default:
                    ZStack {
                        Color.zifrTabBarFill.opacity(0.70)
                        ProgressView().tint(Color.miloomGold)
                    }
                }
            }
        } else {
            profilePhotoPlaceholder
        }
    }

    private var profilePhotoPlaceholder: some View {
        ZStack {
            Color.zifrTabBarFill.opacity(0.70)
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .foregroundStyle(Color.white.opacity(0.18))
        }
    }
    private func saveEmail() async {
        guard !newEmail.isEmpty, newEmail != userEmail else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authVM.updateEmail(newEmail)
            userEmail = newEmail
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isLoading = false
    }
    
    private func uploadPhoto(data: Data) async {
        isLoading = true
        errorMessage = nil
        do {
            try await authVM.uploadAvatar(imageData: data)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isLoading = false
    }
}
