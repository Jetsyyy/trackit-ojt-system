# TRACKIT — System Manual

**TRACKIT** (Centralized OJT Tracking and Documentation System) is a capstone
project for DCSE at Dalubhasaan ng Lungsod ng San Pablo. This manual covers
the three modules — **Student**, **Instructor** and **Admin** (one Flutter
codebase, run on mobile and the web) — and their shared backend
(Node/Express + PostgreSQL on Neon).

After the capstone defense, the panel's System Revisions replaced daily
clock in/out attendance with **weekly DTR & AR submissions**: each week the
student uploads that week's Daily Time Record (DTR) and Accomplishment
Report (AR) and enters the hours claimed. **Only weeks the instructor
approves count as OJT hours.**

---

## 1. Tech Stack

| Layer | Technology |
|---|---|
| App (Student, Instructor, Admin) | Flutter (mobile + Flutter Web), Material 3 |
| Backend API | Node.js + Express |
| Database | PostgreSQL (hosted on Neon, serverless) |
| Auth | JWT (`jsonwebtoken`) + `bcrypt` password hashing |
| File uploads | `multer` (avatars, requirement docs, weekly DTR/AR files, templates); `file_picker` / `image_picker` in the app |
| Reports | `exceljs` (Excel) and `pdfkit` (PDF) for downloadable reports |
| Email | `nodemailer` (OTP codes, account approval notices; optional) |
| Client state | `flutter_secure_storage` (JWT token), `ChangeNotifier` (notifications badge) |

**Why this stack:** Flutter was chosen so the Student and Instructor mobile
apps — and eventually an Admin web dashboard — can share the same Dart
codebase (Flutter Web) instead of maintaining separate frontends. Express +
PostgreSQL is a conventional, well-documented combination that's easy for a
small team to run and deploy, and Neon gives free serverless Postgres
hosting with no server to manage.

---

## 2. Project Structure

```
trackit-ojt-system/
├── package.json              # root convenience script: `npm start` from anywhere
├── run-app.ps1                # convenience script: launches Flutter regardless of cwd
└── trackit_app/
    ├── lib/
    │   ├── main.dart           # launches AuthGate
    │   ├── models/             # plain Dart data classes (Student, OjtProgress, ...)
    │   ├── services/           # repository-style API clients (Http*Service)
    │   ├── screens/
    │   │   ├── auth/           # login / register
    │   │   ├── student/        # Home, Weekly, Document, Notification, Profile
    │   │   ├── teacher/        # Instructor: Home, Students, Document, Notification, Profile
    │   │   └── admin/          # Admin web dashboard
    │   ├── widgets/
    │   │   ├── common/         # shared UI (headers, badges, empty states, skeletons)
    │   │   └── student/        # feature-specific widgets
    │   └── utils/               # app_colors.dart, ph_time.dart, file_download.dart, ...
    └── server/
        ├── index.js             # Express app entry point
        ├── db.js                # PostgreSQL connection pool
        ├── middleware/auth.js   # JWT verification
        ├── routes/               # one file per resource
        └── sql/
            ├── schema.sql                                  # run first
            ├── schema_notifications_profile.sql
            ├── migration_company_details_remarks.sql
            ├── migration_attendance_geofence_corrections.sql
            ├── migration_ojt_start_date.sql
            ├── migration_weekly_accomplishment_reports.sql
            ├── migration_instructor_auth_and_dashboard.sql
            ├── migration_instructor_classes.sql
            ├── migration_teacher_notifications_announcements.sql
            ├── migration_teacher_documents.sql
            ├── migration_announcement_images.sql
            ├── migration_attendance_daily_attempts.sql
            ├── migration_student_profile_enhancements.sql
            ├── migration_admin.sql
            ├── migration_admin_announcements.sql
            ├── migration_admin_announcements_attachments.sql
            ├── migration_hte_directory.sql
            ├── migration_admin_profile.sql
            ├── migration_requirement_templates.sql
            ├── migration_admin_sections.sql
            ├── migration_admin_instructors.sql
            ├── migration_weekly_dtr_submissions.sql
            ├── migration_phase2_accounts.sql
            ├── migration_phase3_requirements.sql
            ├── migration_phase4_hte.sql
            ├── migration_account_activity.sql
            ├── migration_final_documents_ready.sql
            └── migration_requirement_details.sql              # run last
```

Every feature follows the same pattern: a Dart **model**, an abstract
**service interface** with an `Http*Service` implementation that calls the
real API, a **screen**, and small reusable **widgets**. Nested nav ("Tab
Navigators") are used inside the tabs so pushing a sub-screen keeps the
bottom nav bar (or, on a wide screen, the side menu) visible.

---

## 3. Running It

### Server
```powershell
# from the repo root, works from anywhere thanks to package.json
npm start
```
Requires `trackit_app/.env` (see `trackit_app/.env.example`) with
`DATABASE_URL`, `JWT_SECRET`, `PORT`, `NODE_ENV`. The Admin Profile's
"Change Password" email OTP flow additionally needs `SMTP_HOST`,
`SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` -- see the comment in
`.env.example` for a Gmail App Password walkthrough.

### Database setup (Neon SQL Editor, in order)
1. `schema.sql`
2. `schema_notifications_profile.sql`
3. `migration_company_details_remarks.sql`
4. `migration_attendance_geofence_corrections.sql`
5. `migration_ojt_start_date.sql`
6. `migration_weekly_accomplishment_reports.sql`
7. `migration_instructor_auth_and_dashboard.sql`
8. `migration_instructor_classes.sql`
9. `migration_teacher_notifications_announcements.sql`
10. `migration_teacher_documents.sql`
11. `migration_announcement_images.sql`
12. `migration_attendance_daily_attempts.sql`
13. `migration_student_profile_enhancements.sql`
14. `migration_admin.sql`
15. `migration_admin_announcements.sql`
16. `migration_admin_announcements_attachments.sql`
17. `migration_hte_directory.sql`
18. `migration_admin_profile.sql`
19. `migration_requirement_templates.sql`
20. `migration_admin_sections.sql`
21. `migration_admin_instructors.sql`
22. `migration_weekly_dtr_submissions.sql`
23. `migration_phase2_accounts.sql`
24. `migration_phase3_requirements.sql`
25. `migration_phase4_hte.sql`
26. `migration_account_activity.sql` (Profile: last password change, login and account activity)
27. `migration_final_documents_ready.sql` (Final Documents: "I have all the Documents Ready")
28. `migration_requirement_details.sql` (Admin Documents: photocopies required, last updated / updated by, template size)
29. `migration_company_department.sql` (HTE Directory: the student's department at their company)
30. `migration_unique_sections.sql` (Faculty: one section per program + section + academic year)
31. `migration_password_resets.sql` (Student Forgot Password: reset requests and the change-on-next-sign-in flag)

All migrations are non-destructive (`ADD COLUMN IF NOT EXISTS`, etc.) and
safe to re-run. Migrations 4 and 12 belong to the retired clock in/out
feature; they are still run so the older tables exist, but the app no
longer uses them.

### App
```powershell
# from the repo root
.\run-app.ps1
# or manually:
cd trackit_app
flutter pub get
flutter run -d chrome
```

---

## 4. Features

### 4.1 Authentication
- Register / Login with email + password (`bcrypt` hashed).
- **Students** register with their section's class code. The account stays
  **pending** until that section's instructor approves it; a pending or
  declined student is blocked at login with a message.
- **Instructors** register with a single-use **instructor registration
  code** (`INS-XXXX-XXXX`) generated by the Admin, then wait for the Admin
  to approve them and assign their sections.
- JWT issued on login, stored via `flutter_secure_storage`, attached to
  every API request as a bearer token.
- `AuthGate` decides whether to show the login flow or the Student Shell
  based on whether a valid token is stored. All OJT dates and times are shown
in Philippine Standard Time.

### 4.2 Home Tab
- **Profile card**: student name, program, section.
- **Company card**: shows a muted **"Not yet deployed"** placeholder until
  the student completes *Confirm Company Details*; once confirmed, shows
  the company name with a logo-style icon avatar (there's no real logo
  upload — this is a generic building-icon avatar consistent with the
  rest of the app's avatar style).
- **OJT Hours Progress**: credited/required hours (approved weeks only),
  hours awaiting approval, percentage bar, approved weeks, estimated
  completion date and weekly average. The required hours can differ per
  student, so OJT length is flexible.
- **Status badge**: **On Track / Behind / Needs Attention / Ahead of
  Schedule**, computed server-side from the student's **OJT Start Date**
  (self-reported) against an assumed standard pace (8 hrs/weekday, about 40
  hrs/week), plus a "Needs Attention" trigger if the student has gone too
  long without a weekly submission. Once credited hours reach the
  requirement, it becomes a **"Completed"** banner.
- **Latest Announcement/Notification preview**: the 3 most recent
  notifications (real data, shared with the Notifications tab), tap to
  mark read and jump to the relevant tab, "See All" to open Notifications.

### 4.3 Weekly Tab (DTR & AR)
- One slot per **OJT week**, generated from the student's OJT Start Date
  through the current week.
- **Submitting a week**: upload the week's **DTR** and **AR** (1–5 files
  each; PDF or image, since a DTR is usually a phone photo or a scan) and
  enter the **hours claimed** from that DTR (more than 0, at most 168, up
  to 2 decimal places).
- **Statuses**: *Submitted* (awaiting instructor review) → *Approved* (the
  claimed hours are now credited) or *Returned* (rejected with the
  instructor's remarks; the student fixes it and resubmits).
- Replaced files are deleted from the server on resubmit, so old uploads
  don't pile up.
- Once the required hours are complete, no more weekly submissions are
  accepted.
- The summary at the top shows credited hours, hours awaiting approval and
  the pace badge (same numbers as Home).

### 4.4 Documents Tab
Reached from a hub screen (weekly DTR & AR moved to its own Weekly tab):

**HTE Directory** — a read-only list of partner companies maintained by
the Admin (name, industry, address, contact info, available slots). For
reference only; students apply directly, not through the app.

**OJT Requirements** — a 4-phase sequential workflow (Pre-Application →
Requirements → Internship Docs → Final Documents). Each phase unlocks once
the previous one is fully submitted. The list itself is managed only by the
Admin (Official Requirements). Each document supports:
- Download Template (where the Admin uploaded one). Documents **issued by
  an office** (e.g. the registrar) have no download — the student gets them
  from that office and uploads the signed copy.
- Upload / Re-upload
- Submission status (Missing/Submitted/Approved/Rejected)
- **Remarks** — the instructor's feedback when a document is rejected

Once all 4 phases hit 100%, a **Confirm Company Details** step appears
(not counted in the progress bar):
- Manual, self-reported entry: company name, address, industry,
  supervisor name, contact number, and **OJT Start Date**. Company names
  are suggested as the student types.
- **Entered once.** After saving, the company details are locked; only the
  **supervisor** (name and contact) can still be updated.
- A company the student enters that isn't in the HTE Directory yet is added
  to it automatically, and the student is linked to it as a placement. No
  Admin approval is needed.
- This is the source of truth for the Home/Profile company card.

### 4.5 Notifications Tab
- Categorized (Admin / Instructor / System), searchable, filterable
  (category + unread-only).
- Read/unread state, swipe to delete, badge count on the bottom nav.
- Tapping a notification marks it read and deep-links to the relevant tab.

### 4.6 Profile Tab
- Editable avatar (camera or gallery upload).
- Adviser / Company / Supervisor contact rows (Company/Supervisor come
  from Confirm Company Details).
- **Help Center**: FAQs, guides, policies (static content, DB-backed).
- **Settings**: account info, logout.

### 4.7 Instructor Module
Five tabs (Home, Students, Document, Notification, Profile). On a phone they
are a bottom bar; on a laptop or desktop (900 px wide or more) they become a
**left side menu** and the content is centered at a readable width.
- **Home**: assigned students summary and *Needs your Attention*:
  registration requests, requirements to review, and weekly DTR & AR to
  review (with counts).
- **Students**: class information and class code, **Registration
  Requests** (approve, or decline with a reason; the student is emailed
  when SMTP is configured), the student list with search/filters, and each
  student's details.
- **Download Records**: on the Students tab, exports every assigned
  student as **Excel** (sheets *Students* and *Weekly DTR & AR*) or **PDF**
  (summary table plus each student's weekly log).
- **Document**: **Weekly DTR & AR Review** (open the files, approve the
  claimed hours, or return the week with remarks) and **Official
  Requirements** review by student.
- **Notification / Profile**: notices, announcements, account settings.

### 4.8 Admin Module (web)
- **Overview**: totals for the selected academic year; weekly DTR & AR to
  review; a *Weekly DTR & AR Submissions* chart (approved / awaiting review
  / returned) with a **Weekly List** per student (Awaiting Review,
  Returned, No Recent Submission, Up to Date, Not Started); OJT completion
  status; overall hours; pending tasks; and **students at risk** (below 50%
  of required hours, no DTR & AR in the last 2 weeks, behind schedule).
- **Instructors & Sections**: *Requests* (approve an instructor and assign
  sections, or decline), *Registration Codes* (generate / revoke single-use
  instructor codes), *Sections* (a simple list of sections with their
  instructor), and *Faculty*.
- **Official Requirements**: the only place the requirements list is
  managed — add, edit, delete (only if nothing was submitted), reorder
  within a phase, set the issuing office, and upload template files.
- **HTE Directory**: companies with the students placed there, filter by
  region/city, search, and **Download Report** (Excel or PDF).
- **Announcements** and **Profile**.
- **Archive**: archive the active academic year after confirming with the
  admin's email and password. This saves a snapshot of the HTE Directory
  placements and makes the next academic year active. Archived snapshots
  can be downloaded as Excel or PDF.

---

## 5. Database Schema (high level)

| Table | Purpose |
|---|---|
| `students` | Identity, course/section, avatar, required hours |
| `student_profiles` | 1:1 extension: phone, adviser link, self-reported company (name/address/industry/supervisor/contact/lat/lng/**ojt_start_date**) |
| `advisers` | OJT adviser directory |
| `hte_companies` | HTE Directory listings (reference only) |
| `attendance_records` / `attendance_corrections` | Retired clock in/out data (kept, no longer used) |
| `ojt_requirement_phases` / `ojt_requirement_templates` | The 4 fixed phases and their document templates |
| `student_requirement_submissions` | One row per student per requirement document, incl. `remarks` |
| `activity_reports` | Weekly DTR & AR submissions, keyed by `(student_id, week_number)`: `claimed_hours`, `status` (submitted/approved/rejected), `remarks`, reviewer |
| `activity_report_attachments` | DTR and AR files attached to a week |
| `instructor_classes` | Sections (program, section, academic year, class code, instructor) |
| `app_settings` | System settings such as `active_academic_year` |
| `notifications` / `notification_preferences` | Notification feed and per-category toggles |
| `help_center_articles` | Static Help Center content |

Two deliberate design choices worth knowing:
- **Computed, not stored.** Credited OJT hours are the sum of
  `claimed_hours` of **approved** weeks in `activity_reports`, computed on
  every request in one place (`server/utils/creditedHours.js`), so the
  student, instructor and admin always see the same number.
- **Additive migrations.** Every schema change after the initial
  `schema.sql` is a separate, non-destructive `migration_*.sql` file
  (`ADD COLUMN IF NOT EXISTS`, etc.) so real student data is never at risk.

---

## 6. API Endpoints

All routes below (except `/api/auth/*`) require a `Bearer` JWT. Student
routes are scoped to the logged-in student, `/api/teacher/*` to the
logged-in instructor's own students, and `/api/admin/*` to admins.

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Get a JWT |
| GET | `/api/attendance/progress` | Student: credited/pending hours, weeks, pace badge (old path kept; numbers come from approved weeks) |
| GET | `/api/hte-companies` | HTE Directory listing |
| GET | `/api/requirements` | 4-phase requirements + submission status |
| POST | `/api/requirements/:templateId/submit` | Upload/submit a requirement doc |
| GET | `/api/activity-reports` | Weekly DTR/AR slots + credited/pending hours summary |
| POST | `/api/activity-reports/:weekNumber/submit` | Submit a week: multipart `dtr` + `ar` files (PDF/image, up to 5 each) and `claimedHours` |
| GET | `/api/teacher/weekly-reports/students` | Instructor: assigned students' weekly progress, pending reviews first |
| GET | `/api/teacher/weekly-reports/students/:studentId` | Instructor: one student's weeks with DTR/AR files |
| PATCH | `/api/teacher/weekly-reports/students/:studentId/weeks/:weekNumber` | Instructor: `{ decision: approved\|rejected, remarks }` (remarks required to reject) |
| GET | `/api/teacher/students/export?format=xlsx\|pdf` | Instructor: download all assigned students' records |
| GET | `/api/teacher/students/requests` | Instructor: students waiting for registration approval |
| PATCH | `/api/teacher/students/requests/:studentId` | Instructor: `{ decision, reason }` (reason required to decline) |
| GET/POST | `/api/admin/instructors/registration-codes` | Admin: list / generate single-use instructor codes |
| PATCH | `/api/admin/instructors/registration-codes/:id/revoke` | Admin: revoke an unused code |
| GET | `/api/admin/instructors/requests` | Admin: instructors waiting for approval |
| PATCH | `/api/admin/instructors/requests/:id` | Admin: `{ decision, sectionIds, reason }` (approve needs ≥1 unassigned section) |
| GET | `/api/admin/overview?academicYear=` | Admin: Overview dashboard data (weekly DTR & AR counts, completion, hours, at-risk, Weekly List) |
| PATCH | `/api/admin/classes/:id/instructor` | Admin: assign/unassign a section's instructor |
| PATCH | `/api/profile/company/supervisor` | Student: update supervisor after the one-time company entry |
| GET | `/api/hte-companies/suggest?q=` | Student: company name suggestions |
| GET/POST | `/api/admin/requirements` | Admin: Official Requirements by phase / add one `{ phaseId, name, description, issuedBy }` |
| PATCH/DELETE | `/api/admin/requirements/:id` | Admin: edit name/description/issuing office, or delete (only if no submissions) |
| PATCH | `/api/admin/requirements/:id/move` | Admin: `{ direction: up\|down }` within its phase |
| POST/DELETE | `/api/admin/requirements/:id/template` | Admin: upload/replace or remove the template file |
| GET | `/api/admin/hte-companies?academicYear=&location=&search=` | Admin: HTE Directory with each company's students (location = city or region, e.g. `Metro Manila`) |
| GET | `/api/admin/hte-companies/locations` | Admin: regions and cities with company counts |
| GET | `/api/admin/hte-companies/report?format=xlsx\|pdf&location=` | Admin: downloadable HTE placement report |
| GET | `/api/admin/archive/status` | Admin: active academic year, next year, already archived? |
| POST | `/api/admin/archive/academic-year` | Admin: `{ email, password }` — archive the active year's HTE Directory and make the next year active |
| GET | `/api/admin/archive/hte-snapshots[/:year?format=xlsx\|pdf]` | Admin: archived HTE Directory records |
| GET | `/api/notifications` | Notification feed |
| PATCH | `/api/notifications/:id/read` | Mark one read |
| PATCH | `/api/notifications/read-all` | Mark all read |
| DELETE | `/api/notifications/:id` | Delete a notification |
| GET | `/api/profile` | Full student profile |
| PATCH | `/api/profile` | Update phone/address/etc. |
| POST | `/api/profile/company` | Confirm Company Details (one-time; 409 if already entered) |
| POST | `/api/profile/avatar` | Upload avatar image |

---

## 7. Known Gaps

- **Official Requirements list (System Revisions item 7)** — waiting for the
  panel's corrected list; the Admin can enter it in *Official Requirements*.
- **Retired server routes** — the old clock in/out endpoints
  (`/api/attendance/*` except `/progress`, `/api/teacher/attendance`) and
  the old Class Management import/export routes are still mounted, but the
  app no longer calls them.
- **Push/real-time notifications** — the feed is pull-based (fetched on
  load), no WebSocket/push infrastructure yet.

## 8. Deploying to Vercel

The app (Flutter web) and the API (Express) deploy together as one Vercel
project, so they share one address. The database stays on Neon. Config
lives in `trackit_app/vercel.json`, `trackit_app/vercel/*.sh` and
`trackit_app/api/index.js`.

**Uploaded files.** Vercel wipes the server's disk, so uploads (requirement
documents, weekly DTR/AR files, avatars, templates, announcement images) go
to **Vercel Blob** whenever the project has a Blob store connected
(`server/utils/storage.js`). Newer stores sign in with `BLOB_STORE_ID` plus a
per-request token Vercel issues automatically; older ones use
`BLOB_READ_WRITE_TOKEN`. Either works. Without it, as on a local computer, they are
saved under `server/uploads` as before.

**One-time setup**
1. vercel.com → sign in with GitHub → **Add New → Project** → import
   `trackit-ojt-system`.
2. **Root Directory:** `trackit_app`. Leave the framework as "Other"; the
   build settings come from `vercel.json`.
3. **Environment Variables:** add `DATABASE_URL` and `JWT_SECRET` (same
   values as `trackit_app/.env`). Add the mail settings too if email is
   used.
4. Deploy. Then **Storage → Create → Blob**, connect it to the project
   (Production and Preview), and **Redeploy**.
5. Move the files already uploaded on your computer into Blob (run once,
   from `trackit_app/server`, with `BLOB_READ_WRITE_TOKEN` copied from the
   Blob store's `.env.local` tab into `trackit_app/.env`):
   ```
   node scripts/migrate_uploads_to_blob.js          # dry run
   node scripts/migrate_uploads_to_blob.js --apply
   ```
   After this, remove `BLOB_READ_WRITE_TOKEN` from `.env` if you want local
   uploads to keep saving to disk.

After setup, every push to `main` redeploys automatically.

**Limits to know**
- Vercel accepts request bodies up to **4.5 MB**, so a single upload
  larger than that fails online (locally the limit stays 10 MB). Phone
  photos are usually under this; large scans may need compressing.
- Blob files are public links with random, unguessable names, the same
  level of protection as the old `/uploads` folder.
- `FLUTTER_VERSION` in `vercel/install.sh` should match your local
  `flutter --version` when you upgrade Flutter.

## 9. Android Apps

There are two Android apps. Both use the live site's server and accounts:

| App | For | Opens |
|---|---|---|
| **TrackIT** | Students | Student sign-in |
| **TrackIT Staff** | Instructors and the Admin | Staff sign-in (the server decides Admin or Instructor) |

They have different app IDs (`com.example.trackit_app` and
`com.example.trackit_app.staff`), so one phone can have both installed.

Build them from `trackit_app` (each takes a few minutes):

```
flutter build apk --release --dart-define=API_BASE_URL=https://trackit-ojt-system.vercel.app
flutter build apk --release --dart-define=API_BASE_URL=https://trackit-ojt-system.vercel.app --dart-define=TRACKIT_PORTAL=staff
```

Each build writes `build/app/outputs/flutter-apk/app-release.apk`, so copy
it somewhere (e.g. `TrackIT.apk` / `TrackIT-Staff.apk`) before building the
other one. `TRACKIT_PORTAL=staff` is what turns a build into TrackIT Staff
(see `android/app/build.gradle.kts` and `lib/utils/app_portal.dart`).
Screen changes reach phones only when a new APK is installed; server and
data changes reach them right away.
