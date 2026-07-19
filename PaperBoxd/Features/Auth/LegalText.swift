import Foundation

// Bundled full legal text — generated from paperboxd/content/legal/*.md.
// Rendered natively in the signup consent bottom sheet (LegalSheetView).
// Canonical source: paperboxd-backend/docs/{PRIVACY_POLICY,TERMS_OF_SERVICE}.md.
// Regenerate if the policy changes; do not hand-edit the body text here.

enum LegalText {
    static let privacyPolicy = #"""
## 1. Who We Are

PaperBoxd ("we," "us," "our") is a social book-tracking platform operated by Hridyesh (sole individual operator), based in Bangalore, India, accessible at [paperboxd.in](https://paperboxd.in) and through our iOS and Android apps.

This Policy explains what personal data we collect when you use PaperBoxd, why we collect it, who we share it with, and the rights you have over it.

## 2. Grievance Officer

In accordance with India's Digital Personal Data Protection Act, 2023 (DPDP Act), PaperBoxd is operated by a single individual, who also serves as the contact for questions or complaints about your personal data:

- **Name:** Hridyesh
- **Email:** paperboxd@gmail.com
- **Response commitment:** We aim to acknowledge grievances within 7 business days and resolve them within 30 days.

## 3. Information We Collect

| Data | Collected When | Notes |
|---|---|---|
| Email address | Registration | Required for login and account recovery |
| Password | Registration | Stored as a bcrypt hash (cost factor 12) — we never see or store your plain-text password |
| Username, profile info (bio, pronouns, birthday, links, avatar) | Registration / profile edit | Birthday is also used to confirm you meet our minimum age requirement (see §9) |
| Google account info | If you sign in with Google | Limited to the fields Google provides for identity verification; we validate the token audience against an allowlist before trusting it |
| OTP codes | Passwordless / verification login | Codes are hashed at rest and rate-limited; they are never stored in plain text |
| Reading activity | When you log a book, write a diary entry, create a list, rate, or like a book | This is the core content of the app and is visible per your privacy/sharing settings |
| Book identifiers (ISBN) scanned via **Scan & Know** | When you use the barcode scanner | The barcode is decoded **on your device** (iOS: AVCaptureMetadataOutput; Android: ML Kit barcode scanning). **We do not capture, upload, or store a photo of the book or its cover** — only the decoded ISBN text is sent to our servers. |
| Session/device data | Every request | IP address (used for rate-limiting and abuse prevention), device type |
| Account deletion requests | If you delete your account | See §8 for retention and purge timeline |

We do **not** currently collect: push notification tokens (we have no push notification system), payment information (we do not yet process payments), or location data.

## 4. How We Use Your Information

- To create and secure your account (authentication, password/OTP verification)
- To operate core app features: bookshelf, diary, lists, likes, follows, activity feed, leaderboard
- To power **Scan & Know**: we send the book's metadata (title, author, genre, etc. — never an image) along with relevant context about your reading profile to Anthropic's Claude API to generate a personalized recommendation. **This context can include the usernames of people you follow**, where relevant to the recommendation. This is disclosed here specifically so it's not buried — if you'd rather this not happen, contact us (see §11 — self-serve controls for this are on our roadmap).
- To send account-related emails (OTP codes, password reset) via our email provider
- To detect and prevent abuse (rate limiting, fraud prevention)
- To improve the product — we track first-party product usage events (e.g. which features are used) in our own database. **We do not use third-party analytics or advertising trackers.**

## 5. Who We Share Your Data With

We share data only with the service providers needed to run PaperBoxd, and only the minimum needed for their function:

| Provider | What They Receive | Purpose |
|---|---|---|
| ISBNdb, Google Books, Open Library, Hardcover | Book search queries (not your personal identity) | Book metadata lookup |
| Anthropic (Claude API) | Book metadata + relevant reading-profile context (including followed usernames where relevant) — **never an image** | Powers Scan & Know recommendations |
| Cohere | Book/content text for embedding generation | Powers recommendation and search relevance |
| Cloudinary | Profile pictures / uploaded images | Image hosting and delivery |
| Resend | Your email address | Sending OTP codes and account emails |
| Railway | All application data (hosted in [PLACEHOLDER — confirm region, e.g. Singapore]) | Database and backend hosting |
| Vercel | Web traffic | Frontend hosting/CDN |
| Google | OAuth token, if you use Google Sign-In | Identity verification |

We do not sell your personal data. We do not share your data with advertisers.

**Legacy note:** As part of a March 2026 backend migration, a subset of web user data was originally stored in MongoDB Atlas alongside our current PostgreSQL database. This legacy store is in the process of being decommissioned — see §8.

## 6. Cookies & Local Storage

- **Web:** We use a session cookie (httpOnly) for authentication. We do not use third-party advertising or analytics cookies.
- **iOS:** Your authentication token is stored in the iOS Keychain, not in app storage or UserDefaults.
- **Android:** Your authentication token is stored using EncryptedSharedPreferences (AES-256-GCM), not in plain SharedPreferences.

## 7. AI-Generated Content

Scan & Know results are generated by a third-party AI model (Anthropic's Claude) based on book metadata and your reading context. **This content is labeled as AI-generated within the app** and may occasionally be inaccurate or unexpected — treat it as a starting point for discovery, not authoritative advice.

## 8. Data Retention & Deletion

- If you delete your account, your data is soft-deleted immediately (hidden from the product) and **permanently purged from our production database within 30 days**, including cascading deletion of related records (diary entries, lists, activity, etc.).
- **Manual export/portability:** We do not yet offer self-serve data export. To request a copy of your data, email us at paperboxd@gmail.com and we will provide it within 30 days.
- **Legacy MongoDB data:** [PLACEHOLDER — update once decommission is complete] We are in the process of migrating remaining web authentication off our legacy MongoDB database and permanently retiring it. Until this is complete, a legacy copy of some web account data may exist in that system in parallel with our primary database; deletion requests are honored across both systems during this transition.

## 9. Age Eligibility

PaperBoxd is intended for users aged 18 and over. [PLACEHOLDER — update once shipped: we ask you to confirm your date of birth at signup and will not create an account for users who indicate they are under 18.] We do not knowingly collect data from children. If we learn a child's account was created, we will delete it.

## 10. International Data Transfers

Our infrastructure is hosted primarily in [PLACEHOLDER — confirm: Railway Singapore region]. Some of our service providers (Anthropic, Cohere, Cloudinary, Resend) may process data on servers located outside India, including in the United States. By using PaperBoxd, you consent to this transfer, which is necessary to provide the service.

## 11. Your Rights

Subject to applicable law (including the DPDP Act if you are in India), you have the right to:
- Access the personal data we hold about you
- Correct inaccurate data
- Request deletion of your account and data
- Request a copy of your data (currently via manual request — see §8)
- Withdraw consent for optional processing, where applicable
- Lodge a complaint with our Grievance Officer (§2) or, where applicable, your local data protection authority

To exercise any of these rights, contact us at paperboxd@gmail.com.

## 12. Security

We take reasonable technical measures to protect your data, including:
- Password hashing with bcrypt (cost factor 12) — we never store plain-text passwords
- OTP codes hashed at rest and rate-limited
- JWT-based authentication with platform-appropriate secure storage (Keychain / EncryptedSharedPreferences / httpOnly cookies)
- Google OAuth token audience validation against an explicit allowlist
- HTTPS for all data in transit

No system is perfectly secure, and we cannot guarantee absolute security.

## 13. Changes to This Policy

We may update this Policy from time to time. We'll update the "Effective date" above and, for material changes, notify you via email or an in-app notice.

## 14. Contact Us

Questions about this Policy or your data: paperboxd@gmail.com
Grievance contact: see §2.
"""#

    static let termsOfService = #"""
## 1. Acceptance of Terms

By creating an account or using PaperBoxd (the "Service"), you agree to these Terms of Service ("Terms") and our [Privacy Policy](/privacy). If you don't agree, please don't use the Service.

## 2. Eligibility

You must be at least 18 years old to use PaperBoxd. [PLACEHOLDER — update once shipped: by creating an account, you confirm your date of birth meets this requirement.] We may suspend or terminate accounts found to violate this requirement.

## 3. Your Account

- You're responsible for keeping your login credentials secure and for all activity under your account.
- Notify us immediately if you suspect unauthorized access.
- You may sign in with an email/password or with Google Sign-In. You're responsible for the accuracy of the information you provide at registration.

## 4. Acceptable Use

You agree not to:
- Scrape, bulk-download, or programmatically access PaperBoxd data outside our documented API
- Attempt to circumvent rate limits, authentication, or other security controls
- Impersonate another person or misrepresent your affiliation
- Upload content that is unlawful, harassing, hateful, or infringes someone else's rights
- Use the Service to harm, stalk, or harvest data about other users
- Interfere with the normal operation of the Service (e.g., spamming, denial-of-service behavior)

We may suspend or terminate accounts that violate this section.

## 5. Your Content

- **You own what you create.** Diary entries, reviews, lists, and other content you post ("User Content") remain yours.
- **You grant us a license to use it.** By posting User Content, you grant PaperBoxd a non-exclusive, worldwide, royalty-free license to host, display, and distribute that content within the Service (e.g., showing your review to your followers, displaying your public lists) — solely for the purpose of operating and improving PaperBoxd.
- **You're responsible for what you post.** You confirm you have the right to post your User Content and that it doesn't violate any law or third party's rights.
- If you delete a piece of content or your account, we'll remove it from the Service per our retention timeline (see Privacy Policy §8).

## 6. AI-Generated Content

Some features, including **Scan & Know**, use a third-party AI model (Anthropic's Claude) to generate recommendations based on book metadata and your reading activity. This content is labeled as AI-generated within the app.

**AI-generated content is provided for discovery and entertainment purposes only.** It may be inaccurate, out of date, or not reflect the actual content or quality of a book. Don't rely on it as authoritative literary, educational, or professional advice.

## 7. Third-Party Book Data

Book information (titles, covers, descriptions, ISBNs) is sourced from third-party providers including ISBNdb, Google Books, Open Library, and Hardcover. We don't guarantee the accuracy or completeness of this data and aren't responsible for errors originating from these sources.

## 8. Intellectual Property & Takedown Requests

PaperBoxd's branding, design, and software are our intellectual property (or licensed to us) and may not be copied or used without permission.

If you believe content on PaperBoxd infringes your intellectual property rights, contact us at paperboxd@gmail.com with:
- A description of the copyrighted/trademarked work
- The specific content you believe infringes it (e.g. a link or screenshot)
- Your contact information and a statement of good-faith belief that the use is unauthorized

We'll review and remove infringing content where warranted.

## 9. Subscriptions & Payments

**PaperBoxd does not currently offer any paid subscriptions or process payments.** [PLACEHOLDER — this section will be updated with full billing terms, refund policy, and auto-renewal disclosures before any paid feature (e.g. Scan & Know premium tier) is launched. Do not treat this as final.]

## 10. Termination

- **By you:** You may delete your account at any time from Settings. See our Privacy Policy §8 for what happens to your data afterward.
- **By us:** We may suspend or terminate your account if you violate these Terms, to comply with legal obligations, or to protect the Service or other users. Where practical, we'll notify you first.

## 11. Disclaimers & Limitation of Liability

- The Service is provided **"as is"** without warranties of any kind, express or implied, including fitness for a particular purpose or non-infringement.
- We don't guarantee the Service will be uninterrupted, error-free, or secure at all times.
- To the maximum extent permitted by law, PaperBoxd and its operator won't be liable for indirect, incidental, or consequential damages arising from your use of the Service.
- Nothing in these Terms limits liability that cannot be excluded under applicable law.

## 12. Governing Law & Dispute Resolution

[PLACEHOLDER — **business decision needed, not a drafting default**: These Terms will be governed by the laws of India, with courts in [PLACEHOLDER — e.g. Bangalore, Karnataka] having jurisdiction. Decide whether disputes should go through Indian courts or a binding arbitration clause — arbitration is common for consumer apps to limit litigation cost/exposure, but has tradeoffs (harder for users to challenge, may need specific arbitration-body language to be enforceable). Get legal input before finalizing this section.]

## 13. Changes to These Terms

We may update these Terms from time to time. We'll update the "Effective date" above and, for material changes, notify you via email or an in-app notice. Continued use of the Service after changes take effect constitutes acceptance.

## 14. Miscellaneous

- If any provision of these Terms is found unenforceable, the rest remain in effect.
- These Terms, together with our Privacy Policy, constitute the entire agreement between you and PaperBoxd regarding the Service.
- We may assign these Terms in connection with a merger, acquisition, or sale of assets; you may not assign your account or rights under these Terms.

## 15. Contact

Questions about these Terms: paperboxd@gmail.com
"""#
}
