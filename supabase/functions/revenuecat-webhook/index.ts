/**
 * RevenueCat Webhook Handler
 *
 * This Supabase Edge Function processes webhook events from RevenueCat
 * to sync subscription status to the database in real-time.
 *
 * Setup:
 * 1. Deploy: supabase functions deploy revenuecat-webhook --no-verify-jwt
 * 2. Configure in RevenueCat dashboard:
 *    - Webhook URL: https://[your-project].supabase.co/functions/v1/revenuecat-webhook
 *    - Events: INITIAL_PURCHASE, RENEWAL, EXPIRATION, CANCELLATION, UNCANCELLATION
 * 3. Set webhook secret: supabase secrets set REVENUECAT_WEBHOOK_SECRET=your-secret-here
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface RevenueCatWebhookEvent {
  event: {
    type: string;
    app_user_id: string;
    product_id: string;
    period_type: string;
    purchased_at_ms: number;
    expiration_at_ms: number | null;
    store: string;
    environment: string;
    is_trial_conversion?: boolean;
    cancel_reason?: string;
  };
  api_version: string;
}

serve(async (req) => {
  // Set CORS headers for all responses
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify webhook signature (recommended in production)
    const signature = req.headers.get("X-Revenuecat-Signature");
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

    if (webhookSecret && signature) {
      // TODO: Implement signature verification
      // const body = await req.text();
      // const computedSignature = await crypto.subtle.sign(...);
      // if (signature !== computedSignature) {
      //   return new Response("Unauthorized", { status: 401 });
      // }
    }

    const payload: RevenueCatWebhookEvent = await req.json();
    const { event } = payload;

    console.log(
      `RevenueCat webhook: ${event.type} for user ${event.app_user_id}`
    );

    // Initialize Supabase client with service role key (bypasses RLS)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Determine subscription tier based on product ID
    const tier = determineTier(event);

    // Map event type to subscription status
    let subscriptionUpdate: any = {
      updated_at: new Date().toISOString(),
    };

    switch (event.type) {
      case "INITIAL_PURCHASE":
        console.log(`Initial purchase for user ${event.app_user_id}`);
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscribed: true,
          subscription_tier: tier,
          role: tier,
          subscription_end: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
          revenuecat_customer_id: event.app_user_id,
        };
        break;

      case "RENEWAL":
        console.log(`Renewal for user ${event.app_user_id}`);
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscribed: true,
          subscription_tier: tier,
          role: tier,
          subscription_end: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
          revenuecat_customer_id: event.app_user_id,
        };
        break;

      case "UNCANCELLATION":
        console.log(`Uncancellation for user ${event.app_user_id}`);
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscribed: true,
          subscription_tier: tier,
          role: tier,
          subscription_end: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
        };
        break;

      case "CANCELLATION":
        console.log(
          `Cancellation for user ${event.app_user_id}, reason: ${event.cancel_reason}`
        );
        // Don't revoke immediately - let expiration handle it
        // Just update the subscription_end date to reflect when it expires
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscription_end: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
        };
        break;

      case "EXPIRATION":
        console.log(`Expiration for user ${event.app_user_id}`);
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscribed: false,
          subscription_tier: "free",
          role: "free",
          subscription_end: null,
        };
        break;

      case "BILLING_ISSUE":
        console.log(`Billing issue for user ${event.app_user_id}`);
        // Keep subscription active but flag the issue
        // Optionally notify the user
        break;

      case "PRODUCT_CHANGE":
        console.log(`Product change for user ${event.app_user_id}`);
        subscriptionUpdate = {
          ...subscriptionUpdate,
          subscription_tier: tier,
          role: tier,
          subscription_end: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
        };
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
        return new Response(
          JSON.stringify({ success: true, message: "Event ignored" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    // Update subscriber record
    const { data, error } = await supabase
      .from("subscribers")
      .update(subscriptionUpdate)
      .eq("user_id", event.app_user_id);

    if (error) {
      console.error("Failed to update subscriber:", error);

      // If user doesn't exist, create a new subscriber record
      if (error.code === "PGRST116") {
        console.log(`Creating new subscriber for user ${event.app_user_id}`);

        const { error: insertError } = await supabase
          .from("subscribers")
          .insert({
            user_id: event.app_user_id,
            revenuecat_customer_id: event.app_user_id,
            ...subscriptionUpdate,
          });

        if (insertError) {
          console.error("Failed to create subscriber:", insertError);
          return new Response(
            JSON.stringify({ error: insertError.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      } else {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    console.log(
      `Successfully processed ${event.type} for user ${event.app_user_id}`
    );

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json"
      },
    });
  }
});

/**
 * Determine subscription tier from product ID
 */
function determineTier(event: any): string {
  const productId = event.product_id.toLowerCase();

  // Detect founder products (lifetime access)
  const founderProducts = ["founder", "lifetime"];
  if (founderProducts.some((id) => productId.includes(id))) {
    return "founder";
  }

  // If no expiration date, it's a lifetime purchase = founder
  if (event.expiration_at_ms === null) {
    return "founder";
  }

  // Regular pro subscription
  return "pro";
}
