import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from 'https://deno.land/x/jose@v5.1.0/index.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Decode and verify Apple ID token
async function verifyAppleToken(idToken: string, expectedNonce: string) {
  try {
    // Decode the token header to get the key ID
    const decoded = jose.decodeProtectedHeader(idToken)
    const kid = decoded.kid

    if (!kid) {
      throw new Error('No key ID in token header')
    }

    // Get Apple's public keys
    const jwksResponse = await fetch('https://appleid.apple.com/auth/keys')
    const jwks = await jwksResponse.json()

    // Find the matching public key
    const key = jwks.keys.find((k: any) => k.kid === kid)
    if (!key) {
      throw new Error('Public key not found')
    }

    // Import the public key
    const publicKey = await jose.importJWK(key, 'RS256')

    // Verify the token
    const { payload } = await jose.jwtVerify(idToken, publicKey, {
      issuer: 'https://appleid.apple.com',
      audience: 'com.vishal.StudentCompanion', // Accept App ID as audience
    })

    console.log('Token payload:', JSON.stringify(payload))
    console.log('Nonce in payload:', payload.nonce)
    console.log('Expected nonce (raw):', expectedNonce)

    // Verify nonce if provided
    if (expectedNonce) {
      // Hash the expected nonce (Apple stores SHA256 hash in the token)
      const encoder = new TextEncoder()
      const data = encoder.encode(expectedNonce)
      const hashBuffer = await crypto.subtle.digest('SHA-256', data)
      const hashArray = Array.from(new Uint8Array(hashBuffer))
      const hashedNonce = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

      console.log('Expected nonce (hashed):', hashedNonce)
      console.log('Actual nonce from token:', payload.nonce)
      console.log('Do they match?', payload.nonce === hashedNonce)

      if (payload.nonce !== hashedNonce) {
        console.error('❌ Nonce mismatch!')
        console.error('Expected (hashed):', hashedNonce)
        console.error('Got from Apple:', payload.nonce)
        console.error('Type of expected:', typeof hashedNonce)
        console.error('Type of actual:', typeof payload.nonce)
        throw new Error('Nonce mismatch')
      }
    }

    return {
      sub: payload.sub as string, // Apple user ID
      email: payload.email as string | undefined,
      email_verified: payload.email_verified === 'true' || payload.email_verified === true,
    }
  } catch (error) {
    console.error('Token verification failed:', error)
    throw new Error(`Invalid Apple token: ${error.message}`)
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { idToken, nonce } = await req.json()

    console.log('📱 Received request')
    console.log('Has idToken:', !!idToken)
    console.log('Has nonce:', !!nonce)
    console.log('Nonce value:', nonce)
    console.log('Nonce length:', nonce?.length)

    if (!idToken) {
      return new Response(
        JSON.stringify({ error: 'Missing idToken' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify the Apple token
    const appleUser = await verifyAppleToken(idToken, nonce)

    // Create Supabase admin client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    // Check if user exists with this Apple ID (stored in user_metadata or identities)
    const { data: existingUsers } = await supabase.auth.admin.listUsers()

    // First, check if user exists with this Apple ID
    let existingUser = existingUsers?.users.find(u => {
      const appleIdentity = u.identities?.find(i =>
        i.provider === 'apple' && i.provider_id === appleUser.sub
      )
      return !!appleIdentity
    })

    // If not found by Apple ID, check if user exists with this email
    if (!existingUser && appleUser.email) {
      existingUser = existingUsers?.users.find(u =>
        u.email?.toLowerCase() === appleUser.email?.toLowerCase()
      )
      console.log('Found existing user by email:', !!existingUser)
    }

    let userId: string
    let userEmail: string
    let userMetadata: any

    if (existingUser) {
      // User exists (either by Apple ID or email), use their ID
      userId = existingUser.id
      userEmail = existingUser.email || `${appleUser.sub}@appleid.apple.com`
      userMetadata = existingUser.user_metadata || {}
      console.log('✅ Using existing user:', userId)

      // Check if Apple identity already linked
      const hasAppleIdentity = existingUser.identities?.some(i =>
        i.provider === 'apple' && i.provider_id === appleUser.sub
      )

      if (!hasAppleIdentity) {
        console.log('🔗 Linking Apple identity to existing user')
        // Update user metadata to track Apple sign-in
        const linkedProviders = userMetadata.linked_providers || []
        if (!linkedProviders.includes('apple')) {
          linkedProviders.push('apple')
        }

        userMetadata = {
          ...userMetadata,
          apple_user_id: appleUser.sub,
          linked_providers: linkedProviders
        }

        await supabase.auth.admin.updateUserById(userId, {
          user_metadata: userMetadata
        })
      }
    } else {
      // Create new user
      const email = appleUser.email || `${appleUser.sub}@privaterelay.appleid.com`

      console.log('👤 Creating new user with email:', email)

      userMetadata = {
        provider: 'apple',
        apple_user_id: appleUser.sub,
        linked_providers: ['apple']
      }

      const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
        email: email,
        email_confirm: true,
        user_metadata: userMetadata,
      })

      if (createError) {
        console.error('❌ Create user error:', createError)
        throw new Error(`Failed to create user: ${createError.message}`)
      }

      userId = newUser.user.id
      userEmail = newUser.user.email!
      console.log('✅ Created new user:', userId)
    }

    // Use Admin API to generate OTP, then verify it to get session tokens
    console.log('🔐 Generating authenticated session...')

    // Step 1: Generate a magic link which gives us an OTP code
    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email: userEmail,
    })

    if (linkError || !linkData) {
      console.error('❌ Failed to generate magic link:', linkError)
      throw new Error('Failed to generate authentication link')
    }

    const otpCode = linkData.properties.email_otp
    console.log('✅ Generated OTP code')

    if (!otpCode) {
      console.error('❌ No OTP in response')
      throw new Error('Failed to get OTP code')
    }

    // Step 2: Verify the OTP to get a proper session with tokens
    const { data: sessionData, error: verifyError } = await supabase.auth.verifyOtp({
      email: userEmail,
      token: otpCode,
      type: 'magiclink'
    })

    if (verifyError || !sessionData?.session) {
      console.error('❌ Failed to verify OTP:', verifyError)
      throw new Error('Failed to create session from OTP')
    }

    const session = sessionData.session
    console.log('✅ Successfully created session')
    console.log('   User ID:', session.user.id)
    console.log('   Email:', session.user.email)
    console.log('   Access token length:', session.access_token.length)

    return new Response(
      JSON.stringify({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in,
        expires_at: session.expires_at,
        token_type: 'bearer',
        user: {
          id: session.user.id,
          email: session.user.email,
          app_metadata: session.user.app_metadata,
          user_metadata: session.user.user_metadata
        }
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
