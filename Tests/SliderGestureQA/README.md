# Slider gesture checks (simulator only)

Build and install the current Debug StillarcStudio app on a simulator first. Then run:

```sh
xcodebuild -project Tests/SliderGestureQA/StudioGestureQA.xcodeproj -scheme GestureTests -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' test
```

The isolated Debug-only screen checks actual double taps and dragging on the shared reset modifier. A second test opens the actual photo editor with the owned sample, changes Exposure, double-taps it to zero, then verifies Undo restores the changed value. Tests create sample projects only in the simulator app; they do not touch Photos. The harness is unsigned and intended for simulator use, not installation on a physical phone. Release builds exclude the diagnostic screen.
