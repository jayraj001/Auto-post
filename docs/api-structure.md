# AutoPost AI – API Structure

Base URL: `https://api.autopostai.com/v1`

## Authentication
All protected routes require: `Authorization: Bearer <jwt_token>`

---

## AUTH
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/register | Email signup |
| POST | /auth/login | Email login → JWT |
| POST | /auth/google | Google OAuth |
| POST | /auth/refresh | Refresh JWT |
| POST | /auth/logout | Invalidate token |
| GET  | /auth/me | Current user profile |

---

## SOCIAL ACCOUNTS
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /accounts | List connected accounts |
| POST | /accounts/connect/:platform | OAuth connect (IG/FB/TW/LI) |
| DELETE | /accounts/:id | Disconnect account |
| GET  | /accounts/:id/stats | Account stats |

---

## POSTS
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /posts | List posts (filter: status, platform, date) |
| POST | /posts | Create post (draft or scheduled) |
| GET  | /posts/:id | Get single post |
| PUT  | /posts/:id | Update post |
| DELETE | /posts/:id | Delete post |
| POST | /posts/:id/publish | Publish immediately |
| POST | /posts/bulk | Bulk create posts |
| GET  | /posts/calendar | Posts grouped by date |
| POST | /posts/:id/repost | Repost a post |

---

## AI ENGINE
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /ai/caption | Generate caption |
| POST | /ai/hashtags | Generate hashtags |
| POST | /ai/hook | Generate viral hook |
| POST | /ai/image | Generate image (DALL-E) |
| POST | /ai/content-ideas | Get content ideas |
| POST | /ai/best-time | Suggest best posting time |
| GET  | /ai/trending | Trending topics by niche |

---

## ANALYTICS
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /analytics/overview | Dashboard summary |
| GET  | /analytics/posts | Per-post analytics |
| GET  | /analytics/top-posts | Best performing posts |
| GET  | /analytics/growth | Follower growth over time |
| GET  | /analytics/engagement | Engagement rate trends |
| POST | /analytics/sync | Force sync from platforms |

---

## AUTOMATION
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /automation/rules | List rules |
| POST | /automation/rules | Create rule |
| PUT  | /automation/rules/:id | Update rule |
| DELETE | /automation/rules/:id | Delete rule |
| GET  | /automation/replies | List auto-reply templates |
| POST | /automation/replies | Create template |

---

## BILLING
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /billing/plans | List plans + pricing |
| POST | /billing/subscribe | Create subscription |
| POST | /billing/cancel | Cancel subscription |
| GET  | /billing/invoices | Invoice history |
| POST | /billing/webhook/stripe | Stripe webhook |
| POST | /billing/webhook/razorpay | Razorpay webhook |

---

## REFERRALS
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | /referrals | My referral stats |
| POST | /referrals/apply | Apply referral code |

---

## Request/Response Examples

### POST /posts
```json
{
  "caption": "Check out our new product! 🚀",
  "hashtags": ["#startup", "#product"],
  "media_urls": ["https://storage.../image.jpg"],
  "media_type": "image",
  "platforms": ["instagram", "facebook"],
  "scheduled_at": "2026-04-26T10:00:00Z"
}
```

### POST /ai/caption
```json
// Request
{ "topic": "new product launch", "tone": "excited", "length": "short" }

// Response
{
  "caption": "Something big is coming... 🚀 Introducing our game-changing product!",
  "alternatives": ["...", "..."],
  "tokens_used": 120
}
```

### POST /ai/hashtags
```json
// Request
{ "niche": "fitness", "post_topic": "morning workout routine", "count": 20 }

// Response
{
  "trending": ["#FitnessMotivation", "#MorningWorkout"],
  "niche": ["#FitLife", "#GymLife"],
  "long_tail": ["#MorningWorkoutRoutine", "#FitnessJourney2026"]
}
```
