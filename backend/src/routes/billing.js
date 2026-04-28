const router = require('express').Router();
const Stripe = require('stripe');
const Razorpay = require('razorpay');
const { authenticate } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

const PLANS = {
  basic:   { name: 'Basic',   price_inr: 199,  price_usd: 3,  stripe_price: process.env.STRIPE_BASIC_PRICE_ID },
  pro:     { name: 'Pro',     price_inr: 499,  price_usd: 7,  stripe_price: process.env.STRIPE_PRO_PRICE_ID },
  premium: { name: 'Premium', price_inr: 999,  price_usd: 13, stripe_price: process.env.STRIPE_PREMIUM_PRICE_ID }
};

const PLAN_LIMITS = {
  free:    { posts_per_month: 10,  accounts: 1, ai_credits: 5,  bulk_upload: false, automation: false },
  basic:   { posts_per_month: 50,  accounts: 3, ai_credits: 50, bulk_upload: true,  automation: false },
  pro:     { posts_per_month: 200, accounts: 7, ai_credits: 200,bulk_upload: true,  automation: true  },
  premium: { posts_per_month: -1,  accounts: 15,ai_credits: -1, bulk_upload: true,  automation: true  }
};

// ── List plans ────────────────────────────────────────────────
router.get('/plans', (req, res) => {
  res.json({ plans: PLANS, limits: PLAN_LIMITS });
});

// ── Create Stripe subscription ────────────────────────────────
router.post('/subscribe/stripe', authenticate, async (req, res) => {
  const { plan, payment_method_id } = req.body;
  if (!PLANS[plan]) return res.status(400).json({ error: 'Invalid plan' });

  try {
    // Create or retrieve Stripe customer
    let customerId = req.user.stripe_customer_id;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: req.user.email,
        name: req.user.name,
        metadata: { user_id: req.user.id }
      });
      customerId = customer.id;
      await supabase.from('users').update({ stripe_customer_id: customerId }).eq('id', req.user.id);
    }

    await stripe.paymentMethods.attach(payment_method_id, { customer: customerId });
    await stripe.customers.update(customerId, {
      invoice_settings: { default_payment_method: payment_method_id }
    });

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: PLANS[plan].stripe_price }],
      trial_period_days: req.user.trial_ends_at ? 0 : 7,
      expand: ['latest_invoice.payment_intent']
    });

    await supabase.from('subscriptions').insert({
      user_id: req.user.id,
      plan,
      status: subscription.status,
      stripe_sub_id: subscription.id,
      current_period_start: new Date(subscription.current_period_start * 1000),
      current_period_end: new Date(subscription.current_period_end * 1000)
    });

    await supabase.from('users').update({ plan }).eq('id', req.user.id);

    res.json({ subscription_id: subscription.id, status: subscription.status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Create Razorpay order ─────────────────────────────────────
router.post('/subscribe/razorpay', authenticate, async (req, res) => {
  const { plan } = req.body;
  if (!PLANS[plan]) return res.status(400).json({ error: 'Invalid plan' });

  try {
    const order = await razorpay.orders.create({
      amount: PLANS[plan].price_inr * 100, // paise
      currency: 'INR',
      receipt: `order_${req.user.id}_${Date.now()}`,
      notes: { user_id: req.user.id, plan }
    });

    res.json({ order_id: order.id, amount: order.amount, currency: order.currency, key: process.env.RAZORPAY_KEY_ID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Stripe webhook ────────────────────────────────────────────
router.post('/webhook/stripe', require('express').raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  switch (event.type) {
    case 'invoice.payment_succeeded': {
      const sub = event.data.object;
      await supabase.from('subscriptions').update({ status: 'active' }).eq('stripe_sub_id', sub.subscription);
      break;
    }
    case 'invoice.payment_failed': {
      const sub = event.data.object;
      await supabase.from('subscriptions').update({ status: 'past_due' }).eq('stripe_sub_id', sub.subscription);
      break;
    }
    case 'customer.subscription.deleted': {
      const sub = event.data.object;
      await supabase.from('subscriptions').update({ status: 'cancelled' }).eq('stripe_sub_id', sub.id);
      // Downgrade user
      const { data: dbSub } = await supabase.from('subscriptions').select('user_id').eq('stripe_sub_id', sub.id).single();
      if (dbSub) await supabase.from('users').update({ plan: 'free' }).eq('id', dbSub.user_id);
      break;
    }
  }

  res.json({ received: true });
});

// ── Cancel subscription ───────────────────────────────────────
router.post('/cancel', authenticate, async (req, res) => {
  const { data: sub } = await supabase.from('subscriptions')
    .select('*').eq('user_id', req.user.id).eq('status', 'active').single();

  if (!sub) return res.status(404).json({ error: 'No active subscription' });

  if (sub.stripe_sub_id) {
    await stripe.subscriptions.update(sub.stripe_sub_id, { cancel_at_period_end: true });
  }

  await supabase.from('subscriptions').update({ cancel_at_period_end: true }).eq('id', sub.id);
  res.json({ message: 'Subscription will cancel at period end' });
});

module.exports = router;
