# TopWatt

Minimal macOS menu bar app that shows the attached charger wattage as `45W` in the menu bar and shows the full `AC Charger Information` block when clicked.

## Open in Xcode

```bash
open TopWatt.xcodeproj
```

## Build from Terminal

```bash
xcodebuild -project TopWatt.xcodeproj -target TopWatt -configuration Debug -derivedDataPath ./.DerivedData build CODE_SIGNING_ALLOWED=NO
```
