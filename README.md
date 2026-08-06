# CanvasApp

An iOS app I built to check my Canvas grades without fighting the official app.
It talks to Cedarville's Canvas instance directly and puts the stuff I actually
care about — current grades, upcoming assignments, and "what do I need on the
final" — on one screen.

## What it does

- **Course cards** — all your active courses at a glance, with current grades.
  Cards are customizable so you can tell your classes apart quickly.
- **Grades breakdown** — every assignment in a course with its score, grouped
  the way the professor weights them.
- **What-if calculator** — plug in hypothetical scores on ungraded assignments
  and see how your grade moves. It handles weighted assignment groups, and it
  can work backwards too: give it a goal grade and it tells you what you need
  on each remaining assignment (or tells you it's not possible, which is
  useful information in its own way).
- **To-do list** — upcoming assignments across courses so nothing sneaks up
  on you.

## How it works

Written in SwiftUI. You log in with a Canvas **personal access token**
(Canvas → Account → Settings → New Access Token), which gets validated against
the API and then stored in the iOS Keychain — it never leaves the device.
After that the app pulls courses, assignments, and grades straight from the
Canvas REST API.

The base URL is currently hardcoded to `cedarville.instructure.com`, so if you
go to a different school you'd need to change one line in `CanvasApp.swift`
and `AuthenticationManager.swift`.

## Running it

1. Open `CanvasApp/CanvasApp.xcodeproj` in Xcode
2. Pick a simulator or your phone
3. Cmd + R
4. Paste in a Canvas access token when it asks

## Project layout

```
CanvasApp/
  Authentication/   token login + Keychain storage
  Models/           Course, Assignment, AssignmentGroup, CourseGrades
  Services/         Canvas REST API client
  ViewModels/       CourseViewModel, GradeCalculator
  Views/            course cards, grade breakdown, to-do list
```
