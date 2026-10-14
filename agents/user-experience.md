# User experience

See mockups /Users/maksim/repos/tldraw/offload/offload.tldraw

I like  - Idea 1 with some adjustments — PhotosExport.app: the one-button Mac app.

I want clean intuitive, not overloaded, minimalistic design. Ideally max 3 points of attention on each screen / surface. Use progressive disclosure, minimize cognitive load.
Confirmation after each step / permission to go next step. Allow user go back.
Allow user see global progress

Prerequisites

1. Download a notarized DMG from GitHub Releases → drag to Applications → double-click. No toolchain, no Terminal, no flags
2. App is launched (gran permissions if needed)

## Main flow (steps)

1. Show user concise list of what to expect (steps and outcome and analysis of current number of photos, size, estimated time to export)
2. Ask user to connect USB
3. Pick a destination — the folder is created automatically
4. Scope defaults to small batch photos (the lats 10 photos (preselected),  this year, Year chips (2026 / 2025 / 2024 / 2023, multi-select, year chips, number of photos to export)
5. Human progress (“Copying 342 of 4,812 · about 10 minutes left”), plain-language error summary, Show in Finder
6. The Photos permission prompt comes from the app itself
7. Keep json, plist edits + metadata
8. Ask user permission to delete exported
9. Output the summary: before, after, inputs, outputs, how to view  edits + metadata
10. Ask to work on next or quit

## Questions

1. What will be required for us to go from this design to published app on GitHub today?
2. Can we potentially reuse open source projects in my GitHub bookmarks to speed up process?

## Step 1 - Show user concise list of what to expect

Here's the plan:

1. Connect iPhone via USB cable.
2. Select photos to copy
3. Select destination folder
4. Complete copying process
5. Confirm if you want to delete photos fom iPhone
6. Nothing is deleted.
