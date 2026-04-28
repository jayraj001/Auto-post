# AutoPost AI – Smart Social Media Automation Platform

## Project Structure

```
autopost-ai/
├── backend/          # Node.js + Express API
├── frontend/         # Flutter mobile app
├── docs/             # Architecture, schema, API docs
└── scripts/          # DB migrations, seed data
```

## Quick Start

### Backend
```bash
cd backend
npm install
cp .env.example .env   # fill in your keys
npm run dev
```

### Flutter App
```bash
cd frontend
flutter pub get
flutter run
```

## Tech Stack
- Backend: Node.js + Express + Supabase (PostgreSQL)
- Mobile: Flutter (iOS + Android)
- AI: OpenAI GPT-4o + DALL-E 3
- Payments: Stripe + Razorpay
- Queue: Bull (Redis)
- Hosting: Railway (backend) + Supabase (DB)
