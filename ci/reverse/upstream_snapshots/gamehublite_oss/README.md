# GameHub Lite Project

# Note: This project has been taken over by the EmuReady dev Producdevity https://github.com/Producdevity/gamehub-lite

Complete privacy-focused modification of the GameHub Android app. This project removes all tracking, authentication, and bloat while adding an automated patcher for future updates.

---

## Quick Start

**Want to patch a GameHub APK right now?**
→ Use the [Auto-Patcher](#auto-patcher) (scroll down)

**Want to understand what was changed?**
→ Read the [Security Analysis Reports](#security-analysis)

**Want to self-host everything?**
→ Check [Required Repositories](#required-repositories)

---

## What This Project Does

Takes the official GameHub APK (114MB) and converts it into a privacy-focused Lite version (51MB):

- **Removes tracking**: 11,838 telemetry/analytics files deleted (Firebase, Google Analytics, Umeng, JPush, etc.)
- **Optimizes size**: PNG images converted to WebP format, unused libraries removed
- **Bypasses authentication**: No login required, works offline
- **Removes permissions**: 31 invasive permissions eliminated (location, mic, camera, contacts, etc.)
- **Redirects network**: All API calls go to self-hostable Cloudflare Workers
- **Adds features**: External launcher support for Daijisho, Launchbox, etc.

**Result:** 114MB bloated APK → 51MB clean APK with zero tracking

---

## Auto-Patcher

The automated patcher applies all modifications to any GameHub APK version.

### Requirements

**macOS:**
```bash
brew install apktool
brew install openjdk@17
brew install --cask android-commandlinetools
```

**Linux:**
```bash
sudo apt-get install apktool
sudo apt-get install openjdk-17-jdk
# Install Android SDK command-line tools from https://developer.android.com/studio
```

### Running the Patcher

1. Download the official GameHub APK
2. Place it in this folder
3. Run:
```bash
./autopatcher.sh GameHub-5.1.0.apk
```

The script will:
- Decompile the APK
- Remove 11,838 telemetry files
- Copy 2,851 optimized WebP images
- Apply 201 code patches
- Rebuild and sign the APK

Output: `GameHub-Lite-20251017-003625-signed.apk` (takes 2-3 minutes)

### Install It

```bash
adb install -r GameHub-Lite-*.apk
```

Or drag the APK to your Android device and install normally.

---

## What Gets Changed

### Privacy & Bloat Removal
- **Firebase**: All analytics, crash reporting, messaging - gone
- **Google Analytics**: Completely removed
- **Umeng Analytics**: Chinese tracking service - deleted
- **JPush**: Push notification tracking - removed
- **JiGuang**: Core analytics - deleted
- **Alipay SDK**: Payment tracking - removed
- **Auth/Login**: Completely bypassed with hardcoded credentials
- **11,838 files total** removed

### Authentication Bypass
- Login completely bypassed
- Hardcoded token: `same token for everyone`
- User ID: `100000` (shared)
- All API calls redirected to self-hostable Cloudflare Workers
- Social login (WeChat, QQ, Alipay) disabled

### Size Optimization
- PNG images → WebP format (smaller, same quality)
- Removed unused native libraries
- Deleted tracking SDKs
- 114MB → 51MB (55% smaller)

### Permission Removal (31 total)
- Location tracking - **GONE**
- Microphone access - **GONE**
- Camera access - **GONE**
- Contact reading - **GONE**
- Phone state monitoring - **GONE**
- Device fingerprinting - **GONE**

### Features Added
- Package name changed to `gamehub.lite` (can install alongside original)
- External launcher support (Daijisho, Launchbox, RetroArch, etc.)
- Intent filter: `gamehub.lite.LAUNCH_GAME`
- Custom splash screen when games load
- Offline functionality (no internet required for installed games)

---

## Project Structure

```
GameHub-AutoPatcher/
├── autopatcher.sh                    # Main auto-patcher script
├── patches/                          # 201 code modification patches
├── lite_resources/                   # 2,851 optimized WebP images (18MB)
├── files_to_remove.txt               # List of 11,838 files to delete
├── conversion_rules.txt              # Fallback removal list
├── gamehub-release.keystore          # Auto-generated signing key
│
├── COMPREHENSIVE_SECURITY_ANALYSIS_REPORT.md  # Full technical analysis
├── GAMEHUB_API_ANALYSIS.md                   # API server setup guide
└── BLOAT_REMOVAL_ANALYSIS.md                 # Detailed bloat analysis
```

---

## Security Analysis

### Privacy Wins
- **Zero telemetry** sent to vendor now
- **No location tracking** - GPS permissions removed
- **No audio/video surveillance** - Mic/camera permissions gone
- **No device fingerprinting** - Tracking IDs removed
- **No behavioral analytics** - All SDKs deleted
- **No data to Chinese servers** - Network traffic redirected

### The Numbers
- **81 files** manually edited
- **3,389 files** deleted (tracking SDKs mostly)
- **2,872 files** added (optimized resources)
- **11,838 telemetry files** removed
- **31 permissions** eliminated
- **6 tracking SDKs** deleted (500+ files of spyware)

### Analysis Reports

**Want the quick version?**
→ Read `COMPREHENSIVE_SECURITY_ANALYSIS_REPORT.md` - Sections 1-3

**Want all technical details?**
→ Read the full `COMPREHENSIVE_SECURITY_ANALYSIS_REPORT.md` (13 sections)

**Want API server details?**
→ Read `GAMEHUB_API_ANALYSIS.md`

**Want bloat removal breakdown?**
→ Read `BLOAT_REMOVAL_ANALYSIS.md`

---

## Required Repositories

This project requires the following Cloudflare Worker repositories for full functionality:

1. **[gamehub-worker](https://github.com/gamehublite/gamehub-worker)** - Main API proxy worker
   - Handles all GameHub API requests
   - Token replacement and signature regeneration
   - Privacy features (IP protection, fingerprint sanitization)

2. **[gamehub_api](https://github.com/gamehublite/gamehub_api)** - Static API resources
   - Component manifests (Wine, Proton, DXVK, VKD3D)
   - Game configurations and profiles
   - Served via GitHub raw URLs

3. **[gamehub-news](https://github.com/gamehublite/gamehub-news)** - News aggregator worker
   - Aggregates gaming news from RSS feeds
   - Tracks GitHub releases for emulation projects
   - Custom HTML styling for mobile

4. **[gamehub-login-token-grabber](https://github.com/gamehublite/gamehub-login-token-grabber)** - Token refresher worker
   - Automated token refresh every 4 hours
   - OTP-based authentication via Mail.tm
   - Stores fresh tokens in KV storage

**Note:** You can self-host all Workers for complete privacy. Right now I'm using free Cloudflare Workers. Don't misuse the project.

---

## External Launcher Support

Launch Steam games directly from other Android frontends:

```bash
am start -n gamehub.lite/com.xj.landscape.launcher.ui.gamedetail.GameDetailActivity \
  -a gamehub.lite.LAUNCH_GAME \
  --es steamAppId "292030" \
  --ez autoStartGame true
```

This lets you use GameHub as a backend for:
- Daijisho
- Launchbox
- RetroArch
- Any Android launcher that supports custom intents

---

## Troubleshooting

**"apktool not found"**
- Install it: `brew install apktool` (macOS) or `sudo apt-get install apktool` (Linux)

**"Java not found"**
- Install JDK: `brew install openjdk@17` or download from Oracle

**"zipalign not found"**
- Install Android SDK build-tools
- Script will auto-detect if installed via Homebrew

**Some patches failed**
- That's normal. GameHub updates sometimes change code layout
- The script still applies all successful patches (usually 196+ out of 201)
- Failed patches are usually minor and could be manually fixable

**App crashes on launch**
- Something went wrong, check logcat
- Try: `adb uninstall gamehub.lite && adb install -r GameHub-Lite-*.apk`

---

## Customization

### Add Your Own Images
Put PNG/WebP files in `lite_resources/res/drawable-xxhdpi/` and they'll be included in all patched APKs.

Example: We added `wine_game_loading.jpg` (the blue splash screen when games launch).

### Change the Signing Key
Script will auto-generate a new keystore. Default password is `password123`.

### Modify Patches
To add new patches:
1. Make your changes to a decompiled APK
2. Generate diff: `diff -u original.xml modified.xml > patches/mychange.diff`
3. The autopatcher will automatically include it

---

## How the Auto-Patcher Works

The autopatcher does this automatically:

1. **Decompile APK** - Extract all code and resources
2. **Remove bloat** - Delete 11,838 tracking/analytics files
3. **Copy resources** - Add 2,851 optimized WebP images
4. **Apply patches** - Modify 201 code files
5. **Manual fixes** - Fix package name, add missing classes, remove Firebase providers
6. **Rebuild APK** - Recompile everything
7. **Sign APK** - Make it installable

More detailed info on removal: https://github.com/gamehublite/gamehub-oss

The whole process takes 2-3 minutes.

---

## Manual Replication

### Prerequisites
- apktool (decompilation)
- Text editor
- Java JDK 8+
- Android SDK (signing tools)

### Quick Steps
1. Decompile APK with apktool
2. Modify AndroidManifest.xml (remove permissions and components)
3. Modify UserManager.smali (hardcode credentials)
4. Modify EggGameHttpConfig.smali (redirect API)
5. Modify QrLoginHelper.smali and OneKeyAliHelper.smali (neutralize social login)
6. Remove SDK directories (optional)
7. Recompile with apktool
8. Sign with apksigner
9. Install and test

### Detailed Instructions
See `COMPREHENSIVE_SECURITY_ANALYSIS_REPORT.md` Section 8

---

## Security Implications

### The Good
- Your location isn't being tracked anymore
- No mic/camera surveillance
- They can't fingerprint your device
- No behavioral analytics tracking what you do
- Zero data going to the vendor or Chinese servers

### The Trade-offs
- API calls go through Cloudflare Workers (self-hostable)
- You won't get automatic updates from the vendor
- Some social features might break (login, friends, etc.)

**Bottom line:** Self-host all Workers for complete privacy. This is for personal privacy research. Don't distribute the modded APK.

---

## Stats

- **Input**: GameHub APK (114MB)
- **Output**: GameHub Lite APK (51MB)
- **Files removed**: 11,838 (telemetry/analytics)
- **Files added**: 2,851 (optimized images)
- **Code patches**: 201
- **Permissions removed**: 31
- **SDKs deleted**: 6 (Firebase, Google Analytics, Umeng, JPush, JiGuang, Alipay)
- **Processing time**: 2-3 minutes
- **Privacy**: 100% tracking-free

---

## Analysis Metadata

**Analysis Date:** October 7, 2025
**Patcher Version:** 1.0
**Last Tested:** GameHub 5.1.0 (October 2025)
**Total Documentation:** ~25,000 words
**Original APK Size:** 114MB
**Modified APK Size:** 51MB (55% reduction)

---

## Credits

This project was created to make GameHub usable without all the tracking, authentication, and bloat. All patches were manually analyzed and tested.

No affiliation with the official GameHub app.

Built using:
- apktool (open source APK decompilation tool)
- Android SDK tools (apksigner, zipalign)
- Cloudflare Workers (API proxy)
- Standard Unix tools

---

## Version History

**v1.0 (2025-10-17)**
- Auto-patcher released
- 201 patches included
- 11,838 file removal list
- 2,851 optimized resources
- Complete documentation

**v1.0 (2025-10-07)**
- Initial security analysis completed
- All tracking removed
- Authentication bypassed
- Comprehensive reports written

---

## Next Steps

### For Learning
1. Read the comprehensive security analysis report
2. Understand the tracking mechanisms
3. Learn about privacy-preserving techniques
4. Study the code modifications

### For Using
1. Run the auto-patcher on your GameHub APK
2. Install the patched APK
3. Self-host Cloudflare Workers (optional but recommended)
4. Enjoy a privacy-focused GameHub

### For Contributing
1. Fork the required repositories
2. Deploy your own Workers
3. Test with different GameHub versions
4. Submit improvements

---

## Contact & Support

This is an educational project provided as-is. For questions about:
- **Auto-patcher issues:** Check troubleshooting section above
- **Security analysis:** See comprehensive report
- **Android reverse engineering:** Refer to apktool documentation
- **Self-hosting Workers:** Check individual repository READMEs

---

**For detailed technical information, see:**
- `COMPREHENSIVE_SECURITY_ANALYSIS_REPORT.md` (full analysis)
- `GAMEHUB_API_ANALYSIS.md` (API server guide)
- `BLOAT_REMOVAL_ANALYSIS.md` (bloat breakdown)
