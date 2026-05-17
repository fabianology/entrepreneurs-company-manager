import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, role, resourceType, inviterId } = await req.json()

    if (!email || !role || !resourceType) {
      throw new Error("Missing required parameters")
    }

    // Get API key from environment or fallback to user-provided one
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "re_5rQXDHi6_JF8LjWyhvAsTK783EjhosARj"

    const resourceNameMap: Record<string, string> = {
      'company': 'an Entity',
      'institution': 'a Financial Institution',
      'card': 'a Financial Card',
      'loan': 'a Loan',
      'subscription': 'a Subscription',
      'document': 'a Document'
    }

    const readableResource = resourceNameMap[resourceType] || 'a resource'

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
      </head>
      <body style="margin: 0; padding: 0; background-color: #000000; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #ffffff;">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #000000; padding: 40px 20px;">
          <tr>
            <td align="center">
              <div style="max-width: 600px; width: 100%; background-color: #111111; border: 1px solid #333333; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.5); text-align: left;">
                
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #4f46e5 0%, #0A84FF 100%); padding: 32px 24px; text-align: center;">
                  <h1 style="margin: 0; font-size: 28px; font-weight: 800; letter-spacing: -0.5px; color: #ffffff;">Zifr</h1>
                </div>
                
                <!-- Body -->
                <div style="padding: 40px 32px;">
                  <h2 style="margin-top: 0; margin-bottom: 24px; font-size: 22px; font-weight: 600; color: #ffffff;">You've been invited!</h2>
                  
                  <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #A2A2A2;">
                    You have been invited to collaborate on <strong style="color: #ffffff;">${readableResource}</strong> with the role of <strong style="color: #ffffff;">${role}</strong>.
                  </p>
                  
                  <p style="margin: 0 0 32px 0; font-size: 16px; line-height: 1.6; color: #A2A2A2;">
                    Open your Zifr app to view the details, access insights, and start collaborating instantly.
                  </p>
                  
                  <!-- CTA Button -->
                  <div style="text-align: center; margin-top: 40px; margin-bottom: 20px;">
                    <a href="https://zifr.com" style="display: inline-block; padding: 16px 32px; background-color: #ffffff; color: #000000; font-size: 16px; font-weight: 600; text-decoration: none; border-radius: 30px; letter-spacing: 0.5px;">
                      Open Zifr App
                    </a>
                  </div>
                </div>
                
                <!-- Footer -->
                <div style="padding: 24px 32px; background-color: #0A0A0A; border-top: 1px solid #222222; text-align: center;">
                  <p style="margin: 0; font-size: 13px; color: #666666;">
                    © 2026 Zifr. All rights reserved.<br>
                    Secure entity and financial management.
                  </p>
                </div>

              </div>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'Zifr <onboarding@resend.dev>',
        to: email,
        subject: `You've been invited to view ${readableResource}`,
        html: htmlContent,
      }),
    })

    const data = await res.json()

    if (res.ok) {
      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    } else {
      return new Response(
        JSON.stringify({ error: data }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
      )
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
    )
  }
})
