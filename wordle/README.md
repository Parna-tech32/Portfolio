# Wordle Plus 🎮

A Flutter-based Wordle game inspired by the popular word-guessing puzzle. Wordle Plus challenges players to guess the daily five-letter word within a limited number of attempts while maintaining their winning streak.

## 🌐 Live Demo

**Play Wordle Plus:** [https://wordle-plus-4692a.web.app](https://wordle-plus-4692a.web.app)

## 📌 About the Project

Wordle Plus is a word puzzle game developed using Flutter and Dart. Players attempt to identify a hidden five-letter word within six guesses. Each guess provides visual feedback through colored tiles to help players determine the correct letters and their positions.

The game introduces a unique **Streak Freeze** feature that helps players preserve their streak even when they miss a day or fail to guess the daily word correctly.

## ✨ Features

- **Daily Word Challenge:** Guess the five-letter word of the day.
- **Six Attempts:** Players get a maximum of six guesses to solve the puzzle.
- **Color-Based Feedback:**
  - 🟩 Green – Correct letter in the correct position.
  - 🟨 Yellow – Correct letter in the wrong position.
  - ⬜ Grey – Letter is not present in the word.
- **Streak Tracking:** Track consecutive successful daily challenges.
- **Streak Freeze:** Preserve your current streak if you miss a day or fail to guess the word of the day.
- **Interactive Keyboard:** On-screen keyboard for entering guesses.
- **Responsive UI:** Designed to provide a smooth gaming experience across supported devices.
- **Flutter Cross-Platform Development:** Built using Flutter for cross-platform compatibility.

## 🚀 Unique Feature: Streak Freeze

Unlike the traditional Wordle game, Wordle Plus includes a Streak Freeze mechanism.

The feature allows players to protect their current streak when:
- They miss playing the game on a particular day.
- They fail to guess the daily word correctly.

This feature makes the game more forgiving and encourages players to continue playing without losing their accumulated progress.

## 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application logic and game development |
| Firebase Hosting | Hosting the web version of the game |
| Supabase | Backend integration, where configured |

## 📂 Project Structure

```text
wordle/
│
├── android/                  # Android platform configuration
├── ios/                      # iOS platform configuration
├── macos/                    # macOS platform configuration
├── linux/                    # Linux platform configuration
├── windows/                  # Windows platform configuration
├── web/                      # Web application files
│   ├── index.html
│   ├── manifest.json
│   └── icons/
│
├── assets/                   # Game assets
│
├── lib/                      # Main Flutter source code
│   ├── main.dart             # Main application and game logic
│   └── supabase_config.dart  # Supabase configuration
│
├── test/                     # Application tests
│   └── widget_test.dart
│
├── .firebase/                # Firebase deployment configuration
├── .gitignore                # Git ignored files
├── firebase.json             # Firebase configuration
├── pubspec.yaml              # Dependencies and project metadata
├── pubspec.lock              # Locked dependency versions
├── analysis_options.yaml      # Dart analysis configuration
└── README.md                 # Project documentation
```

## ▶️ Running the Project Locally

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Git

### Installation

1. Clone the repository:

```bash
git clone https://github.com/Parna-tech32/portfolio.git
```

2. Navigate to the Wordle project directory:

```bash
cd portfolio/wordle
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the application:

```bash
flutter run
```

### Run the Web Version

```bash
flutter run -d chrome
```

## 🌍 Deployment

The web version of Wordle Plus is deployed using Firebase Hosting.

**Live Application:** [Play Wordle Plus](https://wordle-plus-4692a.web.app)

## 🎯 Future Enhancements

- Daily leaderboard and player rankings.
- Statistics dashboard for wins, losses, and guess distribution.
- Dark mode and additional themes.
- Improved animations and user experience.
- Additional streak protection and game modes.

## 👩‍💻 Developer

**Saptaparna Santra**

B.Tech – Electrical and Computer Science Engineering  
VIT Vellore

GitHub: [Parna-tech32](https://github.com/Parna-tech32)

---

⭐ If you enjoy playing Wordle Plus, check out the live game and try to maintain your streak!



<img width="1440" height="810" alt="Screenshot 2026-11-09 at 9 33 12 PM" src="https://github.com/user-attachments/assets/177ec0f8-2f45-49b7-aaf2-c7627dad070a" />

<img width="1440" height="813" alt="Screenshot 2026-11-09 at 9 33 26 PM" src="https://github.com/user-attachments/assets/744883bd-ba8e-48c7-b9e0-7747fa7c9d3c" />


