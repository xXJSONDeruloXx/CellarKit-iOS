# CellarKit — End-to-End Container Create → Launch QA Loop

## Goal
Drive the iOS simulator autonomously until:
1. Hello Cube DX11 container is visible in the list after tapping the button
2. Launching it completes without errors
3. The launch surface sheet appears with the spinning cube
4. All tests pass

## Device
DEVICE_ID=8D849DA8-9EB6-4E73-9513-9038A8AE80EC
APP=com.cellarkit.ios.app
PROJECT=/Users/dhimebauch/Developer/personal/CellarKit-iOS
DERIVED=/Users/dhimebauch/Library/Developer/Xcode/DerivedData/CellarApp-glpoqhpowaczbpevwwkollbexjag/Build/Products/Debug-iphonesimulator/CellarApp.app

## Checklist
- [x] XCTest UI test passes: createHelloCubeButton found, tapped, container created (status message confirmed)
- [x] XCTest UI test passes: container row appears in list after create
- [x] XCTest UI test passes: Launch Selected fires, session state = exitedCleanly
- [x] XCTest UI test passes: launchSurfaceLogText contains DX11 DXVK log lines
- [x] All tests pass (swift test 35 unit + 6 E2E UI tests all green)
- [x] Clean build, reinstall, relaunch — app is fresh on simulator

## Rules
- Write/update XCTest UI tests to verify each step
- Fix any code issues found along the way
- Rebuild + reinstall + relaunch after every code change
- Use `xcrun simctl launch --console-pty` + grep for runtime errors
- Keep iterating until every checkbox above is checked
