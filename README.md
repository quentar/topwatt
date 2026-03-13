# TopWatt

Minimal macOS menu bar app that shows the attached charger wattage as `45W` in the menu bar and shows the full `AC Charger Information` block when clicked.

I used to have it as terminal command:
`alias watts="system_profiler SPPowerDataType | grep -A 10 \"AC Charger Information\" | grep -i wattage"` -> Wattage (W): 20

`alias watts="system_profiler SPPowerDataType | grep -A 10 \"AC Charger Information\""` -> prints full details of AC charger.

## Open in Xcode

```bash
open TopWatt.xcodeproj
```

## Build from Terminal

```bash
xcodebuild -project TopWatt.xcodeproj -target TopWatt -configuration Debug -derivedDataPath ./.DerivedData build CODE_SIGNING_ALLOWED=NO
```
