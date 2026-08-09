# Pet assets

DeskPet ships with four default 512×512 RGBA white-cat illustrations:

- `pet_idle.png`
- `pet_listening.png`
- `pet_success.png`
- `pet_sleep.png`

The build and release scripts copy these files into `DeskPet.app/Contents/Resources`. `PetFaceView` selects the image that matches the current pet state and falls back to a neutral SwiftUI surface if an asset cannot be decoded.

The default artwork is AI-assisted redrawn artwork supplied and approved for public redistribution by the project maintainer. See [`ASSETS.md`](../../../ASSETS.md) for provenance and licensing notes.

Contributors may replace the artwork only with visually consistent transparent PNG files they have the right to redistribute.
