# Demo walkthrough

Run the default demo without Firebase configuration. Use the fictional shared login for each role; logout keeps the running clinic so the next role sees the same booking. Restart or confirmed reset clears the changes.

1. Sign in as **Patient**. Open Doctors, choose Dr. Ahmed Hassan, select the first future date and a free half-hour slot, then confirm. The visit appears under Appointments.
2. Open Profile and logout. Sign in as **Doctor** with the shared demo email. The schedule contains the patient's reservation. Doctors can confirm pending visits; starting/completing a visit follows the scheduled-time rules.
3. Logout from the doctor profile and sign in as **Admin**. Review source-derived analytics, doctor/patient management and invoices. Issue a consultation invoice only for an unpaid completed visit; settlements and refunds record status without moving money.

The walkthrough uses fictional records and amounts in USD. It demonstrates the in-memory mode; [Firebase browser tests](FIREBASE.md) separately exercise actual Auth/Firestore transactions and Security Rules.

## Capture your own walkthrough

Install matching Chromium/ChromeDriver, Python 3, ImageMagick and ffmpeg. From the repository root:

```bash
flutter build web --release --no-pub
python3 tool/capture_demo.py --output /tmp/mediflow-showcase
```

The helper serves that build locally, opens an isolated headless browser at phone dimensions, checks that the app is in demo mode, and records actual interactions. It exports an MP4, full-resolution screenshots, chapter timings and browser evidence to the output directory; compact screenshots go to `docs/media`. Renderer/font/backend internet endpoints are blocked during capture. The helper rejects severe browser errors or external requests and never signs into a live clinic.

The MP4 preserves the observed screen timing, encodes H.264 at 720×1280 / 24 fps, and has no audio. Raw frames are local output and should not be committed. For a connected-clinic walkthrough, use the emulator integration commands rather than this demo capture script.
