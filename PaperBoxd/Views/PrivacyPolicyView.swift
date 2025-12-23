import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    SectionView(
                        title: "1. Introduction",
                        content: "Welcome to PaperBoxd (\"we,\" \"our,\" or \"us\"). We are committed to protecting your privacy and ensuring you have a positive experience on our platform. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our book tracking and social platform.\n\nBy using PaperBoxd, you agree to the collection and use of information in accordance with this policy. If you do not agree with our policies and practices, please do not use our service."
                    )
                    
                    SectionView(
                        title: "2. Information We Collect",
                        content: "2.1 Information You Provide\n• Account Information: When you create an account, we collect your username, email address, and password. If you sign up using Google OAuth, we collect your name, email, and profile picture from your Google account.\n• Profile Information: You may choose to provide additional information such as a profile picture, bio, and reading preferences.\n• Reading Data: We collect information about books you add to your bookshelf, liked books, books you want to read (TBR), ratings, reviews, and reading notes.\n• Social Interactions: Information about users you follow, followers, and your activity on the platform.\n• Onboarding Preferences: Information you provide during the onboarding questionnaire to help us personalize your recommendations.\n\n2.2 Automatically Collected Information\n• Usage Data: We collect information about how you interact with our platform, including pages visited, features used, and time spent on the platform.\n• Device Information: We may collect information about your device, including browser type, operating system, IP address, and device identifiers.\n• Cookies and Tracking Technologies: We use cookies and similar tracking technologies to track activity on our platform and store certain information."
                    )
                    
                    SectionView(
                        title: "3. How We Use Your Information",
                        content: "We use the information we collect for various purposes, including:\n• To provide, maintain, and improve our services\n• To personalize your experience and provide book recommendations based on your reading preferences\n• To enable social features such as following other users, viewing activity feeds, and sharing your reading progress\n• To communicate with you about your account, updates to our services, and promotional materials (with your consent)\n• To analyze usage patterns and improve our platform's functionality\n• To detect, prevent, and address technical issues and security threats\n• To comply with legal obligations and enforce our terms of service"
                    )
                    
                    SectionView(
                        title: "4. Data Sharing and Disclosure",
                        content: "We do not sell your personal information. We may share your information in the following circumstances:\n\n4.1 Public Information\nYour username, profile information, and public reading activity (books you've read, ratings, reviews) are visible to other users on the platform. You can control the visibility of certain information through your privacy settings.\n\n4.2 Service Providers\nWe may share your information with third-party service providers who perform services on our behalf, such as hosting, data analysis, email delivery, and customer service. These providers are contractually obligated to protect your information.\n\n4.3 Legal Requirements\nWe may disclose your information if required by law, court order, or government regulation, or if we believe disclosure is necessary to protect our rights, your safety, or the safety of others.\n\n4.4 Business Transfers\nIn the event of a merger, acquisition, or sale of assets, your information may be transferred to the acquiring entity."
                    )
                    
                    SectionView(
                        title: "5. Data Storage and Security",
                        content: "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet or electronic storage is 100% secure.\n\nYour data is stored on secure servers, and we use encryption for sensitive information. We regularly review and update our security practices to protect your information."
                    )
                    
                    SectionView(
                        title: "6. Your Rights and Choices",
                        content: "You have the following rights regarding your personal information:\n• Access: You can access and review your personal information through your account settings\n• Correction: You can update or correct your personal information at any time\n• Deletion: You can request deletion of your account and associated data by contacting us or using the account deletion feature\n• Data Portability: You can request a copy of your data in a machine-readable format\n• Opt-Out: You can opt out of marketing communications by adjusting your notification preferences\n• Cookie Preferences: You can manage cookie preferences through your browser settings"
                    )
                    
                    SectionView(
                        title: "7. Cookies and Tracking Technologies",
                        content: "We use cookies and similar tracking technologies to enhance your experience on our platform. Cookies are small data files stored on your device that help us remember your preferences and improve our services.\n\nYou can control cookies through your browser settings. However, disabling cookies may limit your ability to use certain features of our platform."
                    )
                    
                    SectionView(
                        title: "8. Changes to This Privacy Policy",
                        content: "We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new Privacy Policy on this page and updating the \"Last updated\" date. We encourage you to review this Privacy Policy periodically."
                    )
                    
                    SectionView(
                        title: "9. Contact Us",
                        content: "If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us at:\n\nEmail: hridyesh2309@gmail.com\npaperboxd@gmail.com"
                    )
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

