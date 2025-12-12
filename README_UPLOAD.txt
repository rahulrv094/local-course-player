FULL PROJECT ZIP for Codemagic (Option 2)
--------------------------------------------

This archive contains a Flutter project skeleton ready to be pushed to GitHub and built on Codemagic.
Codemagic's workflow will run `flutter create .` to generate android/ios folders on the CI, then build the APK.

Files included:
- lib/main.dart       -> app code (player, playlist, subtitles toggle)
- pubspec.yaml        -> dependencies
- codemagic.yaml      -> CI workflow (runs `flutter create .`, `flutter pub get`, `flutter build apk`)
- README_UPLOAD.txt   -> this file

How to upload to GitHub using web UI:
1. Create a new repository on GitHub (public/private) named e.g. "local-course-player".
2. On the repo page click "Add file" -> "Upload files".
3. Drag & drop the files from this ZIP (lib/, pubspec.yaml, codemagic.yaml, README_UPLOAD.txt).
   - Ensure the lib/ folder is uploaded with main.dart inside it.
4. Commit the changes to the main branch.
5. In Codemagic, connect the GitHub repo and start a build (it will use codemagic.yaml).

If Codemagic build fails with missing plugins or version issues, paste the build log here and I will fix the project files immediately.
