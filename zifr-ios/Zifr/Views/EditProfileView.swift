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
        ZStack(alignment: .top) {
            Color.zifrGreen.ignoresSafeArea()
            
            AnimatedHeaderBackground()
                .ignoresSafeArea(edges: .top)
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    Text("EDIT PROFILE")
                        .zifrLabel()
                    Spacer()
                }
                .padding(.top, 16)
                .overlay(alignment: .trailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar Card
                        ZifrSheetCard(title: "PROFILE PHOTO", icon: "person.crop.circle.fill") {
                            VStack(spacing: 16) {
                                if let selectedImage {
                                    selectedImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else if let user = authVM.currentUser,
                                          case let .string(avatarUrlString) = user.userMetadata["avatar_url"],
                                          let avatarUrl = URL(string: avatarUrlString) {
                                    AsyncImage(url: avatarUrl) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 90, height: 90)
                                        .foregroundStyle(Color.white.opacity(0.2))
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(Circle())
                                }
                                
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo")
                                        Text("Change Photo")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.zifrGold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.zifrGold.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.zifrGold.opacity(0.25), lineWidth: 1))
                                }
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        // Email Card
                        ZifrSheetCard(title: "ACCOUNT EMAIL", icon: "envelope.fill") {
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
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Save Changes")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(MiloomPrimaryButtonStyle())
                                .disabled(newEmail == userEmail || newEmail.isEmpty || isLoading)
                                .opacity(newEmail == userEmail || newEmail.isEmpty ? 0.5 : 1.0)
                                
                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            newEmail = userEmail
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
