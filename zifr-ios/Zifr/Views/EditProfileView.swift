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
            Color.black.ignoresSafeArea()
            
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
                    VStack(spacing: 32) {
                        // Avatar Section
                        VStack(spacing: 16) {
                            if let selectedImage {
                                selectedImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
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
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(Color.white.opacity(0.2))
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(Circle())
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
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
                        .padding(.top, 20)
                        
                        // Email Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EMAIL ADDRESS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .padding(.leading, 20)
                            
                            VStack(spacing: 0) {
                                TextField("Email Address", text: $newEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .frame(height: 56)
                            }
                            .masonryGlass(cornerRadius: 16)
                            
                            Button {
                                Task { await saveEmail() }
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Save Changes")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(newEmail != userEmail && !newEmail.isEmpty ? Color(hex: "#3b82f6") : Color.white.opacity(0.1))
                                .foregroundStyle(newEmail != userEmail && !newEmail.isEmpty ? .white : Color.white.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(newEmail == userEmail || newEmail.isEmpty || isLoading)
                            .padding(.top, 8)
                            
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                                    .padding(.top, 4)
                                    .padding(.horizontal, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
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
