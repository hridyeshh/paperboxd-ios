import SwiftUI

struct TermsOfServiceView: View {
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
                        title: "1. Acceptance of Terms",
                        content: "By accessing and using PaperBoxd (\"the Service\"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.\n\nThese Terms of Service (\"Terms\") govern your access to and use of PaperBoxd, a book tracking and social platform. By creating an account, accessing, or using our Service, you agree to be bound by these Terms."
                    )
                    
                    SectionView(
                        title: "2. Description of Service",
                        content: "PaperBoxd is a platform that allows users to:\n• Track and organize books they have read, want to read, or are currently reading\n• Rate and review books\n• Create and share reading lists and collections\n• Follow other users and view their reading activity\n• Discover new books through personalized recommendations\n• Participate in a community of book enthusiasts"
                    )
                    
                    SectionView(
                        title: "3. User Accounts",
                        content: "3.1 Account Creation\nTo use certain features of the Service, you must create an account. You can create an account by providing a username, email address, and password, or by using a third-party authentication service such as Google OAuth.\n\n3.2 Account Responsibility\n• You are responsible for maintaining the confidentiality of your account credentials\n• You are responsible for all activities that occur under your account\n• You must provide accurate, current, and complete information during registration\n• You must update your information to keep it accurate, current, and complete\n\n3.3 Account Termination\nYou may delete your account at any time through your account settings. We reserve the right to suspend or terminate your account if you violate these Terms or engage in any fraudulent, abusive, or illegal activity."
                    )
                    
                    SectionView(
                        title: "4. User Content",
                        content: "4.1 Content You Post\nYou retain ownership of any content you post on PaperBoxd, including reviews, ratings, reading notes, and profile information. By posting content, you grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, and display your content on the Service.\n\n4.2 Content Guidelines\nYou agree not to post content that:\n• Is illegal, harmful, threatening, abusive, or discriminatory\n• Infringes on intellectual property rights of others\n• Contains spam, malware, or malicious code\n• Is false, misleading, or defamatory\n• Violates the privacy or rights of others\n• Contains personal information of others without consent\n\n4.3 Content Moderation\nWe reserve the right to review, edit, or remove any content that violates these Terms or is otherwise objectionable. We are not obligated to monitor user content but may do so at our discretion."
                    )
                    
                    SectionView(
                        title: "5. Intellectual Property",
                        content: "5.1 Our Content\nThe Service, including its original content, features, and functionality, is owned by PaperBoxd and is protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.\n\n5.2 Book Information\nBook information, including covers, descriptions, and metadata, is provided by third-party services and is subject to their respective copyrights and terms of use. We do not claim ownership of book-related content provided by third parties.\n\n5.3 Limited License\nWe grant you a limited, non-exclusive, non-transferable license to access and use the Service for personal, non-commercial purposes. You may not reproduce, distribute, modify, or create derivative works from the Service without our express written permission."
                    )
                    
                    SectionView(
                        title: "6. Prohibited Activities",
                        content: "You agree not to:\n• Use the Service for any illegal purpose or in violation of any laws\n• Attempt to gain unauthorized access to the Service or other users' accounts\n• Interfere with or disrupt the Service or servers connected to the Service\n• Use automated systems (bots, scrapers) to access the Service without permission\n• Impersonate any person or entity or falsely state your affiliation with any person or entity\n• Harass, abuse, or harm other users\n• Collect or store personal data about other users without their consent\n• Use the Service to transmit viruses, malware, or other harmful code\n• Reverse engineer, decompile, or disassemble any part of the Service"
                    )
                    
                    SectionView(
                        title: "7. Third-Party Services",
                        content: "The Service may contain links to third-party websites or services that are not owned or controlled by PaperBoxd. We have no control over, and assume no responsibility for, the content, privacy policies, or practices of any third-party services.\n\nYou acknowledge and agree that PaperBoxd shall not be responsible or liable for any damage or loss caused by your use of any third-party service. We encourage you to read the terms and conditions and privacy policies of any third-party services you access."
                    )
                    
                    SectionView(
                        title: "8. Disclaimers and Limitations of Liability",
                        content: "8.1 Service Availability\nThe Service is provided \"as is\" and \"as available\" without warranties of any kind, either express or implied. We do not guarantee that the Service will be uninterrupted, secure, or error-free.\n\n8.2 Content Accuracy\nWe do not warrant the accuracy, completeness, or usefulness of any information on the Service. Book information is provided by third-party services, and we are not responsible for any errors or omissions in such information.\n\n8.3 Limitation of Liability\nTo the maximum extent permitted by law, PaperBoxd shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from your use of the Service."
                    )
                    
                    SectionView(
                        title: "9. Indemnification",
                        content: "You agree to indemnify, defend, and hold harmless PaperBoxd, its officers, directors, employees, and agents from and against any claims, liabilities, damages, losses, and expenses, including reasonable attorneys' fees, arising out of or in any way connected with your access to or use of the Service, your violation of these Terms, or your violation of any rights of another."
                    )
                    
                    SectionView(
                        title: "10. Changes to Terms",
                        content: "We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days' notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion. Your continued use of the Service after any changes constitutes acceptance of the new Terms."
                    )
                    
                    SectionView(
                        title: "11. Termination",
                        content: "We may terminate or suspend your account and access to the Service immediately, without prior notice or liability, for any reason, including if you breach these Terms.\n\nUpon termination, your right to use the Service will cease immediately. All provisions of these Terms that by their nature should survive termination shall survive, including ownership provisions, warranty disclaimers, and limitations of liability."
                    )
                    
                    SectionView(
                        title: "12. Governing Law",
                        content: "These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which PaperBoxd operates, without regard to its conflict of law provisions. Any disputes arising from these Terms or the Service shall be resolved in the appropriate courts of that jurisdiction."
                    )
                    
                    SectionView(
                        title: "13. Contact Information",
                        content: "If you have any questions about these Terms of Service, please contact us at:\n\nEmail: hridyesh2309@gmail.com\npaperboxd@gmail.com"
                    )
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
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

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TermsOfServiceView()
}

