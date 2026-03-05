# RevenueCat Webhook Edge Function

This Supabase Edge Function processes webhook events from RevenueCat to sync subscription status to the database in real-time.

## Setup Instructions

### 1. Deploy the Edge Function

```bash
cd supabase
supabase functions deploy revenuecat-webhook
```

### 2. Set Webhook Secret (Optional but Recommended)

```bash
supabase secrets set REVENUECAT_WEBHOOK_SECRET=your-secret-key-here
```

Generate a secure secret:
```bash
openssl rand -base64 32
```

### 3. Configure RevenueCat Dashboard

1. Go to your RevenueCat project settings
2. Navigate to **Integrations** > **Webhooks**
3. Add a new webhook with these settings:
   - **URL**: `https://[your-project-ref].supabase.co/functions/v1/revenuecat-webhook`
   - **Authorization Header**: (leave blank if using signature verification)
   - **Events to send**:
     - ✅ INITIAL_PURCHASE
     - ✅ RENEWAL
     - ✅ EXPIRATION
     - ✅ CANCELLATION
     - ✅ UNCANCELLATION
     - ✅ PRODUCT_CHANGE
     - ✅ BILLING_ISSUE (optional)
   - **Webhook Version**: Latest

4. Click "Create Webhook"
5. Note the webhook secret and set it in Supabase secrets

### 4. Test the Webhook

#### Using RevenueCat Dashboard:
1. Go to Webhooks settings
2. Click "Send Test Event"
3. Select event type (e.g., INITIAL_PURCHASE)
4. Check logs: `supabase functions logs revenuecat-webhook --tail`

#### Using curl:
```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/revenuecat-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "type": "INITIAL_PURCHASE",
      "app_user_id": "test-user-123",
      "product_id": "monthly",
      "period_type": "normal",
      "purchased_at_ms": 1704067200000,
      "expiration_at_ms": 1706745600000,
      "store": "app_store",
      "environment": "SANDBOX"
    },
    "api_version": "1.0"
  }'
```

## Event Handling

| Event Type | Action |
|-----------|--------|
| `INITIAL_PURCHASE` | Creates or updates subscriber with active subscription |
| `RENEWAL` | Updates subscription end date |
| `UNCANCELLATION` | Restores active subscription |
| `CANCELLATION` | Keeps subscription active until expiration |
| `EXPIRATION` | Revokes subscription, sets tier to 'free' |
| `PRODUCT_CHANGE` | Updates subscription tier based on new product |
| `BILLING_ISSUE` | Logs issue (subscription remains active) |

## Tier Mapping

The function automatically determines the subscription tier:

- **Founder**:
  - Product ID contains "founder" or "lifetime"
  - OR expiration_at_ms is null (lifetime access)

- **Pro**:
  - Regular subscriptions (monthly, yearly, etc.)
  - Has expiration date

- **Free**:
  - After subscription expires
  - Default tier

## Database Updates

The webhook updates the `subscribers` table with:
- `subscription_tier`: "free", "pro", or "founder"
- `role`: Matching the tier
- `subscribed`: Boolean flag
- `subscription_end`: ISO date or null for lifetime
- `revenuecat_customer_id`: RevenueCat app_user_id
- `updated_at`: Timestamp of update

## Monitoring

View real-time logs:
```bash
supabase functions logs revenuecat-webhook --tail
```

View specific time range:
```bash
supabase functions logs revenuecat-webhook --since 1h
```

## Security

### Signature Verification (Recommended for Production)

Enable signature verification to ensure webhooks are from RevenueCat:

1. Get your webhook secret from RevenueCat dashboard
2. Set it in Supabase: `supabase secrets set REVENUECAT_WEBHOOK_SECRET=your-secret`
3. Uncomment signature verification code in `index.ts`

### RLS Policies

Ensure Row Level Security is enabled on the `subscribers` table to prevent unauthorized access.

## Troubleshooting

### Webhook Not Triggering

1. Check webhook URL is correct
2. Verify events are enabled in RevenueCat dashboard
3. Check Edge Function logs for errors
4. Test with RevenueCat's "Send Test Event" feature

### Database Update Failures

1. Verify user exists in `subscribers` table
2. Check RLS policies allow service role updates
3. Ensure all required columns exist
4. Check Edge Function logs for specific errors

### User ID Mismatch

- RevenueCat `app_user_id` must match Supabase `user_id`
- Ensure user IDs are synced via PurchaseManager in the app
- Check that `configureRevenueCat()` passes the correct user ID

## Local Development

Test locally with Supabase CLI:

```bash
supabase functions serve revenuecat-webhook
```

Then send test requests to `http://localhost:54321/functions/v1/revenuecat-webhook`

## Production Checklist

- [ ] Edge Function deployed
- [ ] Webhook secret set in Supabase secrets
- [ ] Signature verification enabled
- [ ] Webhook configured in RevenueCat dashboard
- [ ] All relevant events enabled
- [ ] Test webhook with sandbox purchases
- [ ] Monitor logs after deployment
- [ ] Verify database updates correctly
- [ ] Test expiration handling
- [ ] Test tier changes (pro <-> founder)
