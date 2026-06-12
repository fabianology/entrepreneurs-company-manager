import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRole) {
      throw new Error('Supabase environment variables missing')
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, { 
      global: { headers: { Authorization: authHeader } } 
    })
    
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)
    if (authError || !user) throw new Error('Unauthorized')

    const bodyText = await req.text()
    if (!bodyText) throw new Error("Empty request body")
    const { item_id, institution_id } = JSON.parse(bodyText)
    
    if (!item_id || !institution_id) throw new Error("Missing item_id or institution_id")

    // Update the plaid_items row to link it to the newly created institution
    const adminClient = createClient(supabaseUrl, supabaseServiceRole)
    const { error: updateError } = await adminClient
      .from('plaid_items')
      .update({ institution_id })
      .eq('item_id', item_id)
      .eq('user_id', user.id) // Ensure user owns the item

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true }), { 
      status: 200,
      headers: { 'Content-Type': 'application/json' } 
    })
  } catch (error) {
    const errObj = error instanceof Error ? error : new Error(String(error))
    return new Response(JSON.stringify({ error: errObj.message }), { 
      status: 400,
      headers: { 'Content-Type': 'application/json' } 
    })
  }
})
