# UTMHackathon_EcoPal

# 🌿 EcoPal — Natural Finance

> *Your money, your ecosystem. Spend wisely, grow naturally.*

**Live Demo:** [https://utmhackathon-ecopal.netlify.app](https://utmhackathon-ecopal.netlify.app)

EcoPal is a gamified personal finance app built with Flutter that turns your financial habits into a living, breathing garden. Instead of staring at dry charts, you tend to plants that grow or wilt based on how well you manage your money — with an AI-powered pet companion guiding you every step of the way.

---

## 🎯 Project Aim

Most budgeting apps fail because they feel like chores. EcoPal addresses this by making financial management **visual, emotional, and fun**. The core belief: if people can *see* the consequences of their spending habits reflected in something they care about — a thriving garden, a happy pet — they are more likely to build lasting, healthy financial behaviours.

EcoPal targets young adults and students who want to start managing their finances but find traditional tools intimidating or boring.

---

## ✨ Key Features

### 🌱 The Living Ledger (Dashboard Garden)
The home screen is a dynamic, pannable, and zoomable ecosystem that mirrors your financial health in real time.

- **Flora (Savings Pockets):** Each savings goal is represented as a plant. The more you save toward a target, the bigger and healthier the plant grows. You can have up to 5 money pockets simultaneously.
- **Interactive Map:** Pan and zoom around your garden. Click on any plant to view or modify the details of that savings pocket. A recenter button snaps the view back to the default position.
- **Weather System:** The garden's weather reflects your overall spending behaviour:
  - ☀️ **Sunny** — You are under budget. Plants grow faster.
  - ⛅ **Overcast** — Approaching your spending limit. Caution advised.
  - ⛈️ **Storming** — Over budget or in a debt trap. Plants begin to wilt.
- **Quick-Access Landmarks:** Tap on in-world objects (pet house, bookshelf, computer, profile statue) to navigate directly to the Pet Room, Scanner, AI Insights, or Profile pages without using the bottom bar.
- **Savings Progress Panel:** A frosted glass overlay on the left side of the garden shows all active pockets with their progress bars at a glance.

### 🤖 AI-Powered Insights (Powered by Google Gemini 2.5 Flash)
Three AI modules give you a 360° view of your financial behaviour.

- **Reality-Check Predictor:** Analyses your recent transaction history and forecasts your financial trajectory. It flags if you're on track to overspend and grades your habits as *Healthy*, *Moderate*, or *Unhealthy*.
- **Spending Behaviour Analysis:** Evaluates historical patterns across daily (D), monthly (M), and yearly (Y) timeframes. Displays an interactive line chart of your spending trends alongside an AI-written suggestion.
- **AI Receipt Scanner:** Upload a photo (JPG/PNG) or PDF of any receipt. Gemini Vision automatically extracts the merchant name, total amount, and spending category — no manual typing required. Falls back gracefully if the AI quota is exceeded.

### 📋 Receipt Keeper & Manual Entry
A dedicated scanner page where you can log every expense.

- Upload image or PDF receipts for automatic AI extraction via file picker (supports web and mobile).
- Manual entry form with spend type, amount, optional custom category, and optional description.
- Confirmation dialog before any record is saved.
- Recent records list (top 3) with a "View All" bottom sheet supporting time (All Time / This Week / This Month) and category filters.
- Each record shows an AI-assessed spending grade (*Healthy / Moderate / Unhealthy*) displayed inline.
- Tapping any record opens a detailed view with full AI analysis.

### 💰 Money Pockets (Savings Goals)
Visual savings buckets tied directly to the garden plants.

- Create up to 5 pockets with a name, target amount, and starting balance.
- **Auto Deduct:** Automatically channels a set amount from your Main Account balance into a pocket on each transaction log.
- **Full Release:** Withdraw all funds back to your Main Account — this deletes the pocket and returns the funds.
- **Partial Release:** Withdraw a specific amount from a pocket back to your Main Account without deleting it.
- Growth stages (small → medium → large plant) automatically recalculated based on progress toward the target.
- A pocket is marked "locked" (goal met) when its balance reaches the target.

### 🪙 Habit Tax (Habit Tabung)
An automated micro-savings mechanism that turns guilty spending into forced savings.

- Every time you log a transaction in a "guilty" category (Entertainment, Shopping, Guilty Pleasure), **RM 1.00** is automatically deducted and deposited into a locked Habit Tabung.
- The Habit Tabung toggle can be enabled or disabled from the AI Insights page.
- Funds are **locked** until you maintain a *Healthy* spending grade, at which point a withdrawal button becomes available.
- The accumulated amount is displayed on the AI Insights page.

### 🐱 Pet Companion System
A virtual cat lives in your garden and reacts to your financial behaviour.

- Choose between two species at onboarding:
  - **Tabby** — Calm, observant personality.
  - **Orange** — Playful, energetic personality.
- The pet has a **hunger level** and **happiness level**, both of which change over time based on interactions.
- **Feed** your pet by spending Reward Points (costs 50 points per feed). Feeding increases hunger EXP and can trigger a level-up.
- **Tap** your pet for free to increase happiness.
- **Touch** interaction also decays happiness over time based on hours elapsed since last interaction.
- The pet's GIF animation changes based on its current state: *idle*, *happy*, *eating*, or *sleeping*.
- A **floating pet widget** is accessible from every page — it snaps to the left or right edge of the screen, can be dragged freely, and displays AI savings tips when tapped.
- The floating pet also celebrates when you earn reward points and delivers periodic cheers about your pocket savings progress.

### ⭐ Reward Points System
Healthy spending earns points that can be used to care for your pet.

| Transaction Category | Points Earned |
|---|---|
| Add Money | +20 points |
| Food, Groceries, Utilities, Bills, Transport | +15 points |
| Other | +5 points |
| Entertainment / Shopping / Guilty Pleasure | +0 points |

- Points are computed on the frontend and synced to the backend profile.
- Points are deducted when feeding the pet (50 points per feed).
- Points are displayed on the Pet Room page and persist across sessions.

### 🏆 Community & Social Features

#### Global Leaderboard
- Ranks all EcoPal users by pet level in real time.
- Top 3 places have special gold, silver, and bronze styled cards.
- 1st place gets a premium gold glow card.
- Leaderboard data is cached on the server for 5 minutes to reduce load.
- Accessible from the Pet Room page via the trophy button.

#### Friends System
- Add friends by entering their unique User ID (UID) or scanning their QR code.
- Each user has a personal QR code on the Friends page that others can scan to send a request instantly.
- Incoming friend requests can be accepted or rejected inline.
- Friends list supports filtering by garden weather status (Sunny / Overcast / Storm), time added (Newest / Oldest), and pet level (High to Low / Low to High), plus a live search bar.
- Tapping a friend opens a profile popup showing their pet, level, weather status, and all their active savings pocket progress bars.

#### Chat System
- Real-time one-to-one chat between friends powered by Supabase Realtime.
- Send text messages and **stickers** (10 available stickers using the in-app cat GIFs).
- Chat history is loaded on entry; new messages appear instantly via a live listener.
- The friend's pet avatar appears next to their messages in the chat.

### 👤 Profile & Progress Sharing
- View your username, pet level, savings streak, and **Total Harvest** (combined balance across all accounts and pockets).
- **Streak-based badge system:**
  - 🥉 Bronze — Default (0–6 day streak)
  - 🥈 Silver — 7+ day streak
  - 🥇 Gold — 30+ day streak
- **Share Progress:** Generate a shareable card showing your pet, level, streak, and total harvest to post on social media (captured as a PNG and shared via native share sheet).
- Edit username in-app.
- **Manage Companion:** Change pet species or rename your pet at any time.
- Friends preview card on the profile page shows pending requests and pal count.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Database & Auth | Supabase (PostgreSQL + Row-Level Security) |
| AI & Vision | Google Gemini 2.5 Flash |
| Real-time Messaging | Supabase Realtime (PostgreSQL changes) |
| Charts | fl_chart |
| QR Code Generation | qr_flutter |
| QR Code Scanning | mobile_scanner |
| Animations | GIF assets created via Procreate |
| File Sharing | share_plus |
| File Picking | file_picker |
| HTTP Client | http, Dio |

---

## 📱 Application Pages

| Page | Description |
|---|---|
| Login / Sign Up | Email/password and Google OAuth via Supabase Auth |
| Pet Selection | Choose and name your companion (Tabby or Orange cat), with animated preview |
| Dashboard (Garden) | The main living ledger — pannable/zoomable garden with plants, weather, and in-world navigation |
| Pet Room | Interact with, feed, and level up your pet; access the global leaderboard |
| Receipt Scanner | Log spending via AI scan or manual entry; view and filter all records |
| AI Insights | Behaviour analysis with dynamic chart, reality-check predictor, habit tax management |
| Friends | Friend list with filters, friend requests, QR code generation and scanning, UID search |
| Chat | Real-time one-to-one messaging with text and sticker support |
| Leaderboard | Global pet level ranking with medal-styled top-3 cards |
| Profile | Stats, streak badges, total harvest, progress sharing, companion management, logout |

---

## 🗄️ Database Schema (Supabase)

| Table | Key Columns |
|---|---|
| `profiles` | `id`, `username`, `safe_to_spend_balance`, `reward_points`, `streak` |
| `pets` | `user_id`, `name`, `species`, `level`, `hunger_level`, `happiness_level`, `last_interacted_at` |
| `pockets` | `user_id`, `name`, `target_amount`, `current_balance`, `growth_stage`, `is_locked`, `is_auto_deduct`, `auto_deduct_amount` |
| `transactions` | `user_id`, `amount`, `category`, `description`, `type`, `is_fixed`, `created_at` |
| `habit_tax` | `user_id`, `amount`, `available` |
| `friendships` | `id`, `request_from_id`, `address_to_id`, `status`, `created_at` |
| `messages` | `id`, `sender_id`, `receiver_id`, `text`, `sticker_path`, `created_at` |

---

## 🔌 Backend API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/profile` | Get user profile, spending grade, and balance |
| `POST` | `/profile/update` | Update username, balance, or reward points |
| `GET` | `/transactions` | Get all transactions for the current user |
| `POST` | `/transactions` | Log a new transaction; triggers Habit Tax if applicable |
| `GET` | `/pockets` | Get all money pockets |
| `POST` | `/pockets` | Create a new money pocket |
| `PUT` | `/pockets/{id}` | Update a money pocket |
| `DELETE` | `/pockets/{id}` | Delete a money pocket |
| `POST` | `/pockets/{id}/release` | Release all funds and delete pocket |
| `POST` | `/pockets/{id}/release-partial` | Release a partial amount from a pocket |
| `GET` | `/pet` | Get pet data |
| `POST` | `/pet/update` | Create or update pet (used at onboarding) |
| `POST` | `/pet/interact` | Interact with pet (`tap` or `feed`) |
| `POST` | `/pet/feed` | Feed the pet (legacy endpoint) |
| `POST` | `/pet/touch` | Touch/pet the pet (legacy endpoint) |
| `GET` | `/habit-tax` | Get habit tax balance and status |
| `POST` | `/habit-tax/update` | Enable or disable habit tax |
| `GET` | `/ai/reality-check` | Get AI-generated reality check message |
| `GET` | `/ai/behavior` | Get AI spending behaviour analysis |
| `POST` | `/ai/scan-receipt` | Upload and scan a receipt image or PDF |
| `GET` | `/community/leaderboard` | Get top 10 users by pet level (cached 5 min) |
| `GET` | `/friends` | Get friends list, incoming requests, and outgoing requests |
| `POST` | `/friends/add` | Send a friend request by UID |
| `POST` | `/friends/accept` | Accept or reject a friend request |
| `DELETE` | `/friends/{friend_id}` | Remove a friend or ignore a request |
| `GET` | `/users/search/{target_uid}` | Search for a user by their UID |
| `POST` | `/messages/send` | Send a text message or sticker to a friend |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x or later)
- Python 3.10+
- A Supabase project with the tables listed above
- A Google Gemini API key

### Backend Setup

```bash
cd backend
pip install fastapi uvicorn supabase google-genai python-dotenv python-multipart
```

Create a `.env` file in the `backend/` directory:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_API_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_role_key
GEMINI_API_KEY=your_google_gemini_api_key
```

> ⚠️ The `SUPABASE_SERVICE_KEY` (service role key) is required for the friends accept/reject endpoint, which bypasses Row-Level Security to update friendship status.

Run the server:

```bash
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

### Frontend Setup

```bash
cd frontend/ecopal
flutter pub get
flutter run
```

Update `lib/services/api_service.dart` — change the `baseUrl` constant to point to your running backend:

```dart
static const String baseUrl = 'http://127.0.0.1:8000'; // local
// or your deployed backend URL for production
```

#### Development / Mock Mode

`ApiService` includes a `isMockData` flag. Set it to `true` to load data from local JSON asset files without hitting the backend:

```dart
static bool isMockData = true;
```

Mock data files are expected at `assets/backend/data/*.json`.

---

## 📂 Project Structure

```
UTMHackathon_EcoPal/
├── backend/
│   └── main.py                  # FastAPI application with all endpoints
├── frontend/
│   └── ecopal/
│       └── lib/
│           ├── main.dart         # App entry point & AuthGate
│           ├── screens/
│           │   ├── login_page.dart
│           │   ├── pet_selection_page.dart
│           │   ├── garden_page.dart
│           │   ├── pet_room_page.dart
│           │   ├── scanner_page.dart
│           │   ├── ai_insight_page.dart
│           │   ├── friend.dart
│           │   ├── chat_page.dart
│           │   ├── leaderboard_page.dart
│           │   └── profile_page.dart
│           ├── services/
│           │   └── api_service.dart  # Centralised API client
│           └── widgets/
│               ├── bottom_nav_bar.dart
│               └── floating_pet.dart
└── README.md
```

---

## 🎮 How It Works — User Flow

```
Sign Up / Login
      │
      ▼
Pet Selection (first-time only)
   Choose Tabby or Orange, give it a name
      │
      ▼
Garden Dashboard (main hub)
   ├── Tap plants → Manage money pockets
   ├── Weather changes with your spending health
   ├── Tap pet house → Pet Room
   ├── Tap bookshelf → Scanner
   ├── Tap computer → AI Insights
   └── Tap statue → Profile
      │
      ▼
Log Expenses (Scanner)
   ├── Scan a receipt (AI auto-fills)
   └── Manual entry
      │
      ├── Habit Tax deducted for guilty categories
      ├── Reward points earned for healthy categories
      └── Garden weather and plant health updated
      │
      ▼
Pet Room
   ├── Drag fish to feed (costs 50 pts → pet levels up)
   ├── Tap pet → happiness boost
   └── View Global Leaderboard
      │
      ▼
Friends & Community
   ├── Add friends via UID or QR code scan
   ├── View their garden weather & savings goals
   └── Chat with stickers in real time
```

---

## 🔐 Authentication

- **Email/Password** sign-up and login via Supabase Auth.
- **Google OAuth** supported on both web and mobile platforms.
- On every app launch, `AuthGate` checks for an existing session and routes the user to the correct page:
  - No session → Login page
  - Session exists but no pet configured → Pet Selection page
  - Session exists with pet configured → Garden Dashboard
- JWT access tokens from Supabase are attached to every backend request as `Bearer` tokens.

---

## 🤖 AI Behaviour Details

| Feature | Model | Fallback |
|---|---|---|
| Reality-Check Predictor | Gemini 2.5 Flash | Returns a friendly static message |
| Spending Behaviour Analysis | Gemini 1.5 Flash | Returns a static tip |
| Receipt Scanner | Gemini 2.5 Flash (vision) | Returns a demo receipt entry |

The receipt scanner:
1. Determines if the uploaded file is actually a financial document.
2. If yes, extracts the amount, category, and merchant title.
3. Flags whether the purchase is in a "taxable" (habit tax) category.
4. Returns structured JSON — all Markdown formatting is stripped before parsing.

---

## 🌐 Deployment

The frontend is deployed on **Netlify** as a Flutter web build.

The backend is designed for deployment on a platform such as **Render** (the CORS configuration references the Netlify domain). To deploy:

1. Set all environment variables (`SUPABASE_URL`, `SUPABASE_API_KEY`, `SUPABASE_SERVICE_KEY`, `GEMINI_API_KEY`) in your hosting platform's settings.
2. Start with `uvicorn main:app --host 0.0.0.0 --port 8000`.
3. Update `baseUrl` in `api_service.dart` to your deployed backend URL before building the Flutter web app.

---

## 👥 Team

Built for **UTM Hackathon** — a project exploring how gamification and AI can make personal finance accessible, engaging, and genuinely useful for young Malaysians.

---

## 📄 License

This project was created for hackathon purposes. All rights reserved by the team.

---

## 🌐 Try It Now

Visit: [https://utmhackathon-ecopal.netlify.app](https://utmhackathon-ecopal.netlify.app)
