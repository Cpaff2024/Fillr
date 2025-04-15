import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    // Singleton instance
    static let shared = AuthManager()

    // Authentication state
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Firebase references
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    // Private initializer for singleton
    private init() {
        // Set up auth state listener
        auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            if let user = user {
                // User is signed in
                print("Auth state changed: User is signed in with ID: \(user.uid)")
                self.isAuthenticated = true // Explicitly set isAuthenticated to true
                self.fetchUserData(userId: user.uid)
            } else {
                // User is signed out
                print("Auth state changed: User is signed out")
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }

        // Load profile image URL from UserDefaults on app start
        if let userId = Auth.auth().currentUser?.uid, let savedImageUrl = UserDefaults.standard.string(forKey: "profileImageUrl") {
            if self.currentUser == nil {
                self.currentUser = User(id: userId, email: "", username: "", dateJoined: Date(), profileImageUrl: savedImageUrl, stationsAdded: 0, favoriteStations: [], isVerified: false)
            } else {
                self.currentUser?.profileImageUrl = savedImageUrl
            }
            print("Loaded profile image URL from UserDefaults on app start for user: \(userId)")
        }
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil

        print("Attempting to sign in with email: \(email)")

        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Sign in error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }

            // Check if email is verified
            if let user = result?.user, !user.isEmailVerified {
                self.errorMessage = "Please verify your email before signing in."
                print("Email not verified for user: \(user.uid)")
                completion(false, "Please verify your email address before signing in.")
                return
            }

            // User is authenticated successfully
            if let user = result?.user {
                print("User successfully signed in: \(user.uid)")
                self.fetchUserData(userId: user.uid)
                completion(true, nil)
            } else {
                print("Unknown sign in error: No user returned")
                completion(false, "Unknown error occurred")
            }
        }
    }

    /// Sign up with email, password, and username
    func signUp(email: String, password: String, username: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil

        print("Attempting to sign up with email: \(email) and username: \(username)")

        // Check if username is already taken
        checkUsernameAvailability(username) { [weak self] isAvailable in
            guard let self = self else { return }

            if !isAvailable {
                self.isLoading = false
                self.errorMessage = "Username is already taken"
                print("Username already taken: \(username)")
                completion(false, "Username is already taken")
                return
            }

            // Create user with email and password
            self.auth.createUser(withEmail: email, password: password) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("Create user error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }

                guard let user = result?.user else {
                    self.isLoading = false
                    self.errorMessage = "Failed to create user"
                    print("Failed to create user: No user returned")
                    completion(false, "Failed to create user")
                    return
                }

                print("User created successfully: \(user.uid)")

                // Send verification email
                user.sendEmailVerification { [weak self] verificationError in
                    guard let self = self else { return }

                    if let verificationError = verificationError {
                        print("Error sending verification email: \(verificationError.localizedDescription)")
                        self.errorMessage = "Error sending verification email: \(verificationError.localizedDescription)"
                    } else {
                        print("Verification email sent successfully")
                    }
                }

                // Create user profile in Firestore
                let userData: [String: Any] = [
                    "userId": user.uid,
                    "email": email,
                    "username": username,
                    "dateJoined": Timestamp(date: Date()),
                    "profileImageUrl": UserDefaults.standard.string(forKey: "profileImageUrl") ?? "",
                    "stationsAdded": 0,
                    "favoriteStations": [],
                    "isVerified": false
                ]

                print("Creating user profile in Firestore")

                self.db.collection("users").document(user.uid).setData(userData) { error in
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error creating profile: \(error.localizedDescription)"
                        print("Error creating profile: \(error.localizedDescription)")
                        completion(false, "Error creating profile: \(error.localizedDescription)")
                        return
                    }

                    print("User profile created successfully in Firestore")

                    // Create User object
                    self.currentUser = User(
                        id: user.uid,
                        email: email,
                        username: username,
                        dateJoined: Date(),
                        profileImageUrl: UserDefaults.standard.string(forKey: "profileImageUrl"), // Load from UserDefaults
                        stationsAdded: 0,
                        favoriteStations: [],
                        isVerified: false
                    )

                    completion(true, nil)
                }
            }
        }
    }

    /// Sign out the current user
    func signOut(completion: @escaping (Bool, String?) -> Void) {
        print("Attempting to sign out")

        do {
            try auth.signOut()
            print("Successfully signed out")
            self.isAuthenticated = false
            self.currentUser = nil
            completion(true, nil)
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            self.errorMessage = "Error signing out: \(error.localizedDescription)"
            completion(false, "Error signing out: \(error.localizedDescription)")
        }
    }

    /// Send password reset email
    func resetPassword(email: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil

        print("Attempting to send password reset email to: \(email)")

        auth.sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                print("Error sending password reset: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                completion(false, error.localizedDescription)
                return
            }

            print("Password reset email sent successfully")
            completion(true, nil)
        }
    }

    // MARK: - User Data Methods

    /// Fetch user data from Firestore
    func fetchUserData(userId: String) {
        isLoading = true

        print("Fetching user data for userId: \(userId)")

        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                return
            }

            guard let data = snapshot?.data() else {
                print("User data not found for userId: \(userId)")
                self.errorMessage = "User data not found"
                return
            }

            print("Successfully fetched user data")

            // Create User object from Firestore data
            let dateJoined = (data["dateJoined"] as? Timestamp)?.dateValue() ?? Date()
            let favoriteStations = data["favoriteStations"] as? [String] ?? []
            let savedImageUrl = UserDefaults.standard.string(forKey: "profileImageUrl")

            self.currentUser = User(
                id: userId,
                email: data["email"] as? String ?? "",
                username: data["username"] as? String ?? "",
                dateJoined: dateJoined,
                profileImageUrl: savedImageUrl ?? (data["profileImageUrl"] as? String), // Prioritize UserDefaults
                stationsAdded: data["stationsAdded"] as? Int ?? 0,
                favoriteStations: favoriteStations,
                isVerified: data["isVerified"] as? Bool ?? false
            )

            self.isAuthenticated = true
            print("User authenticated: \(userId)")
        }
    }

    /// Update user profile
    func updateProfile(username: String?, profileImageUrl: String?, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            print("No user logged in")
            completion(false, "No user logged in")
            return
        }

        isLoading = true

        var updatedData: [String: Any] = [:]

        if let username = username {
            updatedData["username"] = username
            print("Updating username to: \(username)")
        }

        if let profileImageUrl = profileImageUrl {
            updatedData["profileImageUrl"] = profileImageUrl
            print("Updating profileImageUrl to: \(profileImageUrl)")
            UserDefaults.standard.set(profileImageUrl, forKey: "profileImageUrl") // Update UserDefaults
        }

        db.collection("users").document(userId).updateData(updatedData) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                print("Error updating profile: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                completion(false, error.localizedDescription)
                return
            }

            print("Profile updated successfully")

            // Update current user
            if let username = username {
                self.currentUser?.username = username
            }

            if let profileImageUrl = profileImageUrl {
                self.currentUser?.profileImageUrl = profileImageUrl
            }

            completion(true, nil)
        }
    }

    /// Add a station to user's favorites
    func addToFavorites(stationId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            print("No user logged in")
            completion(false, "No user logged in")
            return
        }

        print("Adding station to favorites: \(stationId)")

        db.collection("users").document(userId).updateData([
            "favoriteStations": FieldValue.arrayUnion([stationId])
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error adding to favorites: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                completion(false, error.localizedDescription)
                return
            }

            print("Successfully added to favorites")

            // Update local user object
            self.currentUser?.favoriteStations.append(stationId)
            completion(true, nil)
        }
    }

    /// Remove a station from user's favorites
    func removeFromFavorites(stationId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            print("No user logged in")
            completion(false, "No user logged in")
            return
        }

        print("Removing station from favorites: \(stationId)")

        db.collection("users").document(userId).updateData([
            "favoriteStations": FieldValue.arrayRemove([stationId])
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error removing from favorites: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                completion(false, error.localizedDescription)
                return
            }

            print("Successfully removed from favorites")

            // Update local user object
            if let index = self.currentUser?.favoriteStations.firstIndex(of: stationId) {
                self.currentUser?.favoriteStations.remove(at: index)
            }
            completion(true, nil)
        }
    }

    // MARK: - Helper Methods

    /// Check if a username is available
    private func checkUsernameAvailability(_ username: String, completion: @escaping (Bool) -> Void) {
        print("Checking username availability: \(username)")

        db.collection("users").whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                print("Error checking username: \(error.localizedDescription)")
                // If there's an error, assume username is available to allow sign-up to proceed
                completion(true)
                return
            }

            guard let snapshot = snapshot else {
                completion(true)
                return
            }

            // Username is available if no documents are found
            let isAvailable = snapshot.documents.isEmpty
            print("Username \(username) is \(isAvailable ? "available" : "already taken")")
            completion(isAvailable)
        }
    }
}

// User model
struct User: Identifiable {
    let id: String
    let email: String
    var username: String
    let dateJoined: Date
    var profileImageUrl: String?
    var stationsAdded: Int
    var favoriteStations: [String]
    var isVerified: Bool
}
