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
| File uploads | `multer` on the server; files stored in **Supabase Storage** online (local `server/uploads` on a computer); `file_picker` / `image_picker` in the app |
| Reports | `exceljs` (Excel) and `pdfkit` (PDF) for downloadable reports |
| Email | `nodemailer` (OTP codes, account approval notices; needs SMTP settings, see 3) |
| Hosting | Vercel (app + API together), Neon (database), Supabase (files) |
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
            ├── migration_requirement_details.sql
            ├── migration_company_department.sql
            ├── migration_unique_sections.sql
            ├── migration_password_resets.sql
            ├── migration_documents_revision.sql
            └── migration_scheduled_requirements.sql        # run last
```

Other useful places: `server/utils/storage.js` (file storage),
`server/utils/requirementPhases.js` (the four stages, shared by student and
instructor), `server/utils/scheduledRequirements.js` (scheduled
requirements and reminders), `server/scripts/` (backup and one-time
scripts), `lib/utils/app_portal.dart` (Student vs Staff portal) and
`lib/widgets/common/motion.dart` / `trackit_splash.dart` (animations and the
loading screen).

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
Requires `trackit_app/.env` (see `trackit_app/.env.example`, never commit
`.env`):

| Variable | Needed for |
|---|---|
| `DATABASE_URL`, `JWT_SECRET`, `PORT`, `NODE_ENV` | Always |
| `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_BUCKET` (`trackit-files`, public) | Saving uploads to Supabase Storage. Without them, uploads are saved under `server/uploads` on the computer. |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | Emails: Change Password codes for admins/instructors and account approval notices. For Gmail: turn on 2-Step Verification, create an App Password, use `smtp.gmail.com` port `465`. **Not set up yet.** |

The same variables go in Vercel → Project → Settings → Environment Variables.

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
32. `migration_documents_revision.sql` (System Revision 2: the official document list per stage, "download only" documents like MOU / MOA, Stage 4 Final Details form; old documents retired, their submissions kept)
33. `migration_scheduled_requirements.sql` (Scheduled Requirements: the admin posts requirements like the Supervisor Evaluation Form per period with a due date and time for every student of an academic year; notifications when posted and the day before; late uploads flagged)

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

### 4.1 Portals and Sign-in
- **Two portals.** Students use the main address (and the **TrackIT**
  Android app). Instructors and the Admin use **`/staff`** (and the
  **TrackIT Staff** app). Each portal signs in, and reopens saved sessions
  for, its own roles only (`lib/utils/app_portal.dart`).
- **One Staff sign-in.** There is no "Admin or Instructor" choice: the
  server checks the account and opens the right portal
  (`POST /api/staff-auth/login`).
- **Students** register with their section's class code; the account stays
  **pending** until that section's instructor approves it.
- **Instructors** register with a single-use code (`INS-XXXX-XXXX`) from
  the Admin, then wait for approval and section assignment.
- **Password rules** (at least 8 characters, upper- and lowercase letter,
  number and symbol) are shown as a live checklist wherever a password is
  created or changed, and enforced by the server
  (`server/utils/passwordPolicy.js`).
- **Student Forgot Password:** the student enters their email; their
  instructor sees the request on the Students page, clicks **Reset** and
  gives the student a one-time temporary password; the student must set a
  new password right after signing in with it.
- JWT issued on login, stored via `flutter_secure_storage`, sent with every
  API request. "Remember me" keeps the session; otherwise it ends when the
  browser/app closes.
- **Loading screen:** on opening, the TrackIT logo pops in and the school
  name rises into place on maroon, then it fades into the login page (or
  the signed-in home). The website shows the same screen while the app
  downloads (`web/index.html`).
- All OJT dates and times are shown in Philippine Standard Time.

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
A hub with four cards: **HTE Directory**, **OJT Requirements**, **Weekly
Submissions** and **Scheduled Requirements**.

**HTE Directory** — partner companies maintained by the Admin (name,
industry, address). Supervisor contact persons are not shown to students.

**OJT Requirements** — four stages, done in order (each unlocks when the
previous one is complete). The list (System Revision 2, from Ma'am Ellen /
the Figma) is managed by the Admin:

| Stage | Documents |
|---|---|
| 1 Pre-Application | Pre-Application Form (template), Curriculum Vitae, Application Letter |
| 2 Requirements | Endorsement Letter (template), Acceptance Letter (template), MOU / MOA (**download only**), Parental Consent |
| 3 Internship Docs | Enrollment Form (from the Library), Medical Certificate (from the Clinic), Psychological Certificate, Notarized MOU/MOA, Notarized Parental Consent |
| 4 Final Details | No documents: the **OJT Final Information** form |

Each document card has **Download Template** (when the Admin uploaded one)
and **Upload / Re-upload**, its status (Pending for Verification /
Approved / Re-upload with the instructor's note). **Download only**
documents (MOU / MOA) have no upload and never hold up a stage. Documents
**issued by an office** (Clinic, Library) have no template: students upload
the actual issued document.

**Stage 4 — Final Details** opens the **OJT Final Information** form:
student name (with extension), company name and industry, company address
(province, city, barangay, street), OJT start date, and supervisor name and
contact. It is **entered once**; afterwards only the supervisor can be
updated. The company is added to the HTE Directory automatically if it isn't
there yet. Stage 4 is complete once the form is submitted.

**Scheduled Requirements** — requirements with a deadline: the ones the
OJT office schedules for everyone (e.g. the **Supervisor Evaluation Form**
for "1st Semester" and again for "Final") and any Additional Requirements
from the instructor. Each shows its period and exact due date and time,
**Due soon** (orange), **Overdue** / **Submitted late** (red). Students are
notified when one is posted and again the day before it's due. Late uploads
are accepted but marked late.

### 4.5 Notifications Tab
- Categorized (Admin / Instructor / System), searchable, filterable
  (category + unread-only).
- Read/unread state, swipe to delete, badge count on the bottom nav.
- Tapping a notification marks it read and deep-links to the relevant tab.

### 4.6 Profile Tab
- Compact header; editable avatar (camera or gallery upload).
- Adviser / Company / Supervisor rows (Company and Supervisor come from the
  Stage 4 Final Details form).
- **Help Center**: FAQs, guides, policies (static content, DB-backed).
- **Settings**: account info, **Change Password** (with the password
  guide), logout.

### 4.7 Instructor Module
Five tabs (Home, Students, Document, Notification, Profile). On a phone they
are a bottom bar; on a laptop or desktop (900 px wide or more) they become a
**left side menu** and the content is centered at a readable width.
- **Home**: assigned students summary and *Needs your Attention*:
  registration requests, requirements to review, and weekly DTR & AR to
  review (with counts).
- **Students**: class information and class code, **Registration
  Requests** (approve, or decline with a reason; the student is emailed
  when SMTP is configured), **Password Reset Requests** (Reset gives a
  one-time temporary password to hand to the student), the student list
  with search/filters, and each student's details.
- **Download Records**: on the Students tab, exports every assigned
  student as **Excel** (sheets *Students* and *Weekly DTR & AR*) or **PDF**
  (summary table plus each student's weekly log).
- **Document**: **Weekly DTR & AR Review** (open the files, approve the
  claimed hours, or return the week with remarks) and **OJT Requirements**
  review by student: the upload documents of Stages 1–3, whether Stage 4
  (Final Details) is submitted, and the student's **Scheduled / Additional
  Requirements** (OJT office ones show "From the OJT office · due …" and
  "submitted late" when late).
- **Notification / Profile**: notices, announcements, account settings.

### 4.8 Admin Module (web)
- **Dashboard**: totals for the selected academic year, OJT completion
  (donut), HTE industries and student locations.
- **Faculty** (Instructors & Sections): instructor requests (approve and
  assign sections, or decline), single-use registration codes, sections
  (one per program + section + academic year) and the faculty list.
- **Documents** has two tabs:
  - **Stage Requirements** — the only place the stage list is managed: add,
    edit, reorder, move between stages, upload/replace templates, set the
    photocopies required, the issuing office and **"Students upload this
    document"** (off = download only). Office-issued documents show
    **Locked** ("Managed by the Clinic / Library"), with editing in the ⋮
    menu. **Stage 4 · Final Details** opens a panel with what students fill
    in, an editable stage description and how many students submitted.
    Deleting a document that students already submitted removes it from the
    list but keeps their submissions (retired).
  - **Scheduled Requirements** — **Post Requirement** with a name, period
    (1st Semester, 2nd Semester, Midterm, Final or any), due date and time,
    instructions and an optional form. Every OJT student of the selected
    academic year is notified; the list shows Open / Due soon / Closed and
    "X of Y submitted · approved · late"; **View Students** lists each
    student's status with filters. Changing the due date notifies students
    and re-arms the day-before reminder.
- **HTE Directory**: companies with the students placed there, filters
  (location, sections, sort), search, **Merge Duplicates** (finds
  look-alike company names; moves students, weekly reports, supervisors and
  contacts into the kept record) and **Generate Report** (Excel or PDF; one
  sorted table per location).
- **Announcements**, **Profile** and **Archive** (archive the active
  academic year after confirming with the admin's email and password; saves
  a snapshot of the HTE Directory and makes the next year active).

---

## 5. Database Schema (high level)

| Table | Purpose |
|---|---|
| `students` | Identity, course/section, avatar, required hours |
| `student_profiles` | 1:1 extension: phone, adviser link, self-reported company (name/address/industry/supervisor/contact/lat/lng/**ojt_start_date**) |
| `advisers` | OJT adviser directory |
| `hte_companies` | HTE Directory listings (reference only) |
| `attendance_records` / `attendance_corrections` | Retired clock in/out data (kept, no longer used) |
| `ojt_requirement_phases` | The 4 stages (`kind`: `documents`, or `final_details` for Stage 4) |
| `ojt_requirement_templates` | Stage documents: template, issuing office, photocopies, `upload_required` (false = download only), `retired_at` (retired documents are hidden but kept) |
| `student_requirement_submissions` | One row per student per stage document, incl. `remarks` |
| `custom_requirements` / `custom_requirement_targets` | Additional Requirements (instructor, for chosen sections) and **Scheduled Requirements** (admin, `audience = all_students` of an `academic_year`, with `period`, `due_at`, `reminder_sent_at`) |
| `student_custom_requirement_submissions` | Uploads for those, incl. `is_late` |
| `password_reset_requests` | Student Forgot Password requests (instructor resets) |
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
| POST | `/api/auth/login` | Student: get a JWT |
| POST | `/api/staff-auth/login` | Instructor or Admin: get a JWT; the server decides the role |
| POST | `/api/auth/forgot-password` | Student: ask the instructor to reset the password |
| PATCH | `/api/profile/password` | Change password (also the forced change after a reset) |
| GET | `/api/teacher/students/password-resets` | Instructor: Forgot Password requests |
| POST | `/api/teacher/students/password-resets/:id/reset` / `.../dismiss` | Instructor: reset (returns a one-time temporary password) or dismiss |
| GET | `/api/attendance/progress` | Student: credited/pending hours, weeks, pace badge (old path kept; numbers come from approved weeks) |
| GET | `/api/hte-companies` | HTE Directory listing |
| GET | `/api/requirements` | The 4 stages with documents, status and Stage 4 completion |
| POST | `/api/requirements/:templateId/submit` | Upload a stage document (refused for download-only or retired ones) |
| GET | `/api/custom-requirements` | Student: Scheduled and Additional Requirements (period, due date and time, late) |
| POST | `/api/custom-requirements/:id/submit` | Student: upload one (marked late after the due time) |
| GET | `/api/teacher/requirements/students[/:studentId]` | Instructor: requirement progress / one student's stages and scheduled requirements |
| PATCH | `/api/teacher/requirements/submissions/:id` / `custom-submissions/:id` | Instructor: approve or request a re-upload |
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
| GET/POST | `/api/admin/requirements` | Admin: stages with documents (+ Stage 4 progress) / add a document `{ phaseId, name, description, issuedBy, copiesRequired, uploadRequired }` |
| PATCH/DELETE | `/api/admin/requirements/:id` | Admin: edit a document (incl. `uploadRequired`, stage), or delete (retired instead when students already submitted it) |
| PATCH | `/api/admin/requirements/:id/move` | Admin: `{ direction: up\|down }` within its stage |
| POST/DELETE | `/api/admin/requirements/:id/template` | Admin: upload/replace or remove the template file |
| PATCH | `/api/admin/requirements/phases/:id` | Admin: `{ description }` of a stage |
| GET/POST | `/api/admin/scheduled-requirements[?academicYear=]` | Admin: list with counts / post one (multipart: `title`, `period`, `dueAt`, `description`, `academicYear`, `template`); notifies the year's students |
| PATCH/DELETE | `/api/admin/scheduled-requirements/:id` | Admin: edit (new due date notifies students) / delete with its uploads |
| GET | `/api/admin/scheduled-requirements/:id/submissions` | Admin: every student's status for one |
| GET | `/api/admin/hte-companies/duplicates` | Admin: groups of look-alike companies |
| POST | `/api/admin/hte-companies/:id/merge` | Admin: `{ mergeIds, dryRun }` merge companies into :id |
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

- **Email isn't configured** (no SMTP settings yet), so Change Password codes
  and approval emails aren't sent. The admin account's email is still a
  placeholder (`admin@trackit.local`); set a real Gmail and the SMTP
  variables (see 3).
- **Acceptance Letter** has no template file yet (Admin → Documents).
- **Day-before reminders** are sent when a student first opens TrackIT
  within 24 hours of the deadline (there is no always-on server); a
  scheduled job would make them exact-time.
- **25 files uploaded before the move to Supabase** (two 4E students) were
  lost with the suspended Vercel Blob store and need to be uploaded again.
- **Retired server routes** — the old clock in/out endpoints are still
  mounted but unused.
- **Push/real-time notifications** — the feed is fetched on load; no push
  infrastructure yet.

## 8. Deploying to Vercel

The app (Flutter web) and the API (Express) deploy together as one Vercel
project, so they share one address. The database stays on Neon. Config
lives in `trackit_app/vercel.json`, `trackit_app/vercel/*.sh` and
`trackit_app/api/index.js`.

**Uploaded files.** Vercel wipes the server's disk, so uploads (requirement
documents, weekly DTR/AR files, avatars, templates, announcement images) go
to **Supabase Storage** (`server/utils/storage.js`) when `SUPABASE_URL` and
`SUPABASE_SERVICE_KEY` are set: bucket `trackit-files` (public), files at
`https://<project>.supabase.co/storage/v1/object/public/trackit-files/...`.
Vercel Blob is still supported as a fallback but is no longer used (the
store was suspended for exceeding the free limits). Without either, as on a
local computer, files are saved under `server/uploads`.

**One-time setup**
1. vercel.com → sign in with GitHub → **Add New → Project** → import
   `trackit-ojt-system`.
2. **Root Directory:** `trackit_app`. Leave the framework as "Other"; the
   build settings come from `vercel.json`.
3. **Environment Variables:** `DATABASE_URL`, `JWT_SECRET`,
   `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_BUCKET` (and the SMTP
   settings when email is set up), for Production and Preview.
4. In Supabase: create the project, then **Storage → New bucket**
   `trackit-files`, **Public**. The secret key is under Project Settings →
   API Keys.
5. To move existing files (local `server/uploads` or old Blob links) into
   Supabase and update their links, run once from `trackit_app/server`:
   ```
   node scripts/migrate_files_to_supabase.js          # dry run
   node scripts/migrate_files_to_supabase.js --apply
   ```

After setup, every push to `main` redeploys automatically. After changing
environment variables, redeploy the latest deployment.

**Database updates.** The database is shared by the live site and local
testing, so new `sql/migration_*.sql` files are applied once (they're
non-destructive and safe to re-run) and take effect for both.

**Backups.** From `trackit_app/server`:
```
npm run backup
```
saves every database table (JSON) and every Supabase file into
`backups/backup-<date-time>/` with a `summary.txt`. It changes nothing
online. The `backups/` folder is git-ignored (personal data); keep a copy
off the laptop too (USB drive or Google Drive). Back up before big changes.

**Limits to know**
- Vercel accepts request bodies up to **4.5 MB**, so a single upload
  larger than that fails online (locally the limit stays 10 MB). Phone
  photos are usually under this; large scans may need compressing.
- Uploaded files are public links with random, unguessable names, the
  same level of protection as the old `/uploads` folder.
- Supabase's free plan has 1 GB of storage; free projects can be paused
  after a long time without activity (restore them from the Supabase
  dashboard).
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
