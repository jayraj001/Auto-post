# AutoPost AI – Full Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                    │
│  (Auth · Dashboard · Calendar · AI Studio · Analytics)  │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS / REST + WebSocket
┌──────────────────────▼──────────────────────────────────┐
│               API Gateway (Express.js)                   │
│  /auth  /posts  /ai  /analytics  /billing  /automation  │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┘
   │          │          │          │          │
┌──▼──┐  ┌───▼───┐  ┌───▼───┐  ┌───▼───┐  ┌──▼──────┐
│Auth │  │Post   │  │AI     │  │Social │  │Billing  │
│Svc  │  │Sched. │  │Engine │  │APIs   │  │Stripe/  │
│     │  │(Bull) │  │OpenAI │  │IG/FB/ │  │Razorpay │
└──┬──┘  └───┬───┘  └───────┘  │TW/LI  │  └─────────┘
   │          │                 └───────┘
┌──▼──────────▼──────────────────────────────────────────┐
│              Supabase (PostgreSQL + Storage)             │
│   users · posts · accounts · analytics · subscriptions  │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

| Concern | Choice | Reason |
|---|---|---|
| Mobile | Flutter | Single codebase iOS+Android, fast UI |
| Backend | Node.js + Express | Fast I/O, huge ecosystem |
| DB | Supabase/PostgreSQL | Relational + realtime + auth built-in |
| Queue | Bull + Redis | Reliable scheduled job execution |
| AI | OpenAI GPT-4o | Best caption/hashtag quality |
| Payments | Stripe + Razorpay | Global + India coverage |
| Storage | Supabase Storage / S3 | Media files for posts |

## Data Flow – Scheduled Post

1. User creates post in Flutter app
2. POST /api/posts → saved to DB with status=scheduled
3. Bull queue picks up job at scheduled_at time
4. Worker calls social platform API (IG/FB/TW/LI)
5. Response stored → analytics updated
6. Push notification sent to user

## Scaling Plan

- 0–1K users: Single Railway instance + Supabase free
- 1K–10K users: Horizontal scaling, Redis cluster, CDN for media
- 10K+ users: Microservices split, dedicated queue workers per platform
