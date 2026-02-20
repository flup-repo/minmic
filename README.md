# MinMic

### 💖 Support This Project

If you find MinMic useful and would like to support its continued development, consider buying me a coffee! Your support helps keep this project alive and enables new features.

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-blue.svg?logo=paypal)](https://www.paypal.com/donate/?business=6SUDEH9BDL3WQ&no_recurring=0&item_name=Appreciate+your+kind+support%21&currency_code=EUR)

Every contribution, no matter how small, is greatly appreciated! 🙏

---

MinMic is a lightweight, fast, and low-resource macOS background utility that automatically lowers system and media volume. Designed as a companion alongside dictation applications (like Wispr Flow), it ensures that background audio, especially on external devices, is successfully ducked when you start dictating.

## Features

- **External Device Support:** Uses low-level CoreAudio APIs to target all active audio streams and channels on hardware devices, allowing volume reduction on Bluetooth headsets, USB DACs, and Thunderbolt docks.
- **Microphone Monitoring:** Actively monitors your microphone and intelligently ducks audio only when necessary.
- **Smooth Transitions:** Fast and smooth fade-out/fade-in (over ~100-200ms) rather than jarring audio cuts.
- **Lightweight Agent:** Runs silently in the background as an accessory app with near-zero CPU consumption when idle, with no Dock icon.
- **Menu Bar Integration:** Easy access to settings, status diagnostics (like the active output device), and trigger configuration through a discrete Menu Bar interface.

## Installation & Usage

1. Download the latest `.dmg` release and drag `MinMic.app` to your Applications folder.
2. Launch the app. It will appear in your Menu Bar.
3. On the first launch, you will be prompted to grant Accessibility permissions, which are necessary to capture global keyboard events or microphone usage in the background.
4. Configure your ducking percentage and trigger within the Menu Bar popover.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) https://github.com/flup-repo
