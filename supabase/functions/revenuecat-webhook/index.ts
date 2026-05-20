import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    // Note: Verify signature using REVENUECAT_WEBHOOK_SECRET in production
    const signature = req.headers.get('x-revenuecat-signature')

    const payload = await req.json()
    const { event } = payload

    if (!event || !event.app_user_id) {
      return new Response("Invalid payload", { status: 400 })
    }

    const userId = event.app_user_id // The auth.uid() mapped as app_user_id in RevenueCat

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let proStatus = false
    if (event.type === 'INITIAL_PURCHASE' || event.type === 'RENEWAL') {
      proStatus = true
    } else if (event.type === 'EXPIRATION' || event.type === 'CANCELLATION') {
      proStatus = false
    }

    // Update user's pro status (assuming a profiles table exists or we update metadata)
    const { error } = await supabaseAdmin.auth.admin.updateUserById(
      userId,
      { user_metadata: { is_pro: proStatus } }
    )

    if (error) throw error

    return new Response(JSON.stringify({ success: true, is_pro: proStatus }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
