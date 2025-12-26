//
//  PaperBoxdApp.swift
//  PaperBoxd
//
//  Created by Hridyesh on 23/12/25.
//

import SwiftUI

@main
struct PaperBoxdApp: App {
<<<<<<< Updated upstream
=======
    init() {
        // Configure Google Sign-In
        // IMPORTANT: You MUST use an iOS OAuth Client ID, not a Web Client ID
        // To create an iOS Client ID:
        // 1. Go to Google Cloud Console → APIs & Services → Credentials
        // 2. Create OAuth client ID → Application type: iOS
        // 3. Bundle ID: com.paperboxd.PaperBoxd
        // 4. Copy the Client ID and add it here or in GoogleService-Info.plist
        
        if let clientID = ProcessInfo.processInfo.environment["893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com"], !clientID.isEmpty {
            GoogleSignInService.shared.configure(clientID: clientID)
        } else {
            // Will be configured from GoogleService-Info.plist if available
            // Replace this with your iOS Client ID from Google Cloud Console
            // Format: XXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com
            GoogleSignInService.shared.configure(clientID: "893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com")
        }
    }
    
>>>>>>> Stashed changes
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
        }
    }
}
