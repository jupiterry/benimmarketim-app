# PROJECT_MEMORY.md
> **Project Name:** Benim Marketim
> **Last Updated:** 2025-12-06
> **Current Phase:** Release & Refinement
> **Active Context:** Resolving App Store rejections (Version 2.0.7+22), UI Refinements, Bug Fixing.

---

## [1. PROJECT VISION & GOALS]
* **Core Concept:** A comprehensive mobile e-commerce application for "Benim Marketim", allowing users to browse products, manage carts, and place orders.
* **Target Audience:** Existing and potential customers of Benim Marketim.
* **Success Criteria:** Successful deployment to App Store and Play Store, bug-free shopping experience, seamless Firebase integration.

## [2. TECH STACK & CONSTRAINTS]
* **Language/Framework:** Flutter (Dart)
* **Backend/DB:** Firebase (Auth, Firestore, Messaging, Analytics, Crashlytics), External REST API (Dio)
* **State Management:** Provider
* **Key Packages:** go_router, flutter_local_notifications, hive, shared_preferences, cached_network_image.
* **Constraints:** 
  * Mobile First Design
  * Turkish Language Support (Localization)
  * iOS & Android Compatibility
  * App Store Guidelines Compliance

## [3. ARCHITECTURE & PATTERNS]
* **Design Pattern:** MVVM (Model-View-ViewModel) + Service Layer
* **Folder Structure:**
    * `/lib/core`: Utilities, constants, theme configuration.
    * `/lib/features`: (If applicable) Feature-specific modules.
    * `/lib/services`: API calls, Firebase interactions, Local Storage.
    * `/lib/views`: UI screens and widgets.
    * `/lib/viewmodels` (or `providers`): State management logic.
    * `/lib/models`: Data models.
* **Naming Conventions:** camelCase for variables/functions, snake_case for files, PascalCase for classes.

## [4. ACTIVE RULES (The "Laws")]
*(Yapay zekanın asla çiğnememesi gereken kurallar)*
1.  **Safety First:** API Key'leri asla koda gömme.
2.  **User Experience:** Kullanıcıyı engelleyen hataları (blocking bugs) önceliklendir.
3.  **Clean Code:** Kod tekrarından kaçın (DRY), fonksiyonları küçük ve tek işlevli tut.
4.  **Aesthetics:** Modern ve temiz bir UI tasarımı uygula (Benim Marketim temasına uygun).
5.  **Localization:** Metinleri kod içine gömmek yerine dinamik/lokalize edilebilir yapıda tutmaya çalış (özellikle Türkçe).

## [5. PROGRESS & ROADMAP]
- [x] Phase 1: Setup & Configuration (Firebase, Project Init)
- [x] Phase 2: Core Features (Auth, Products, Cart, Orders)
- [ ] Phase 3: UI Polish (Animations, Responsive Tweaks)
- [x] Phase 4: Testing & Deployment (Ongoing App Store Submission)
    - [x] Fix Version Conflict (2.0.7+22)
    - [ ] Resolve Metadata Rejections
    - [ ] Final Production Release

## [6. DECISION LOG & ANTI-PATTERNS]
*(Hatalardan ders çıkarma günlüğü)*
* **[Firebase - Integration]:** Kullanıcı yönetimi ve bildirimler için Firebase tercih edildi.
* **[Provider - State]:** Basitlik ve Flutter ekosistemiyle uyumu nedeniyle Provider seçildi.
* **[Anti-Pattern]:** `setState`'i karmaşık state yönetimi için kullanma -> `Provider` veya `ViewModel` kullan.
* **[Anti-Pattern]:** Büyük widget ağaçları -> Küçük, yeniden kullanılabilir widget'lara böl.

---
**OPERATIONAL DIRECTIVE:**
1.  **Read First:** Before answering any prompt, check this file for context.
2.  **Update Often:** If a task is completed, check the box [x]. If a tech decision changes, update Section 2.
3.  **Stay Consistent:** Do not suggest code that violates "Active Rules".
