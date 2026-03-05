import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WeatherRequest {
  latitude: number
  longitude: number
}

interface WeatherResponse {
  currentWeather: {
    main: {
      temp: number
      tempMin?: number
      tempMax?: number
      humidity: number
    }
    weather: Array<{
      main: string
      description: string
      icon: string
    }>
    wind: {
      speed?: number
    }
    name: string
  }
  forecast: {
    list: Array<{
      dt: number
      main: {
        temp: number
        tempMin?: number
        tempMax?: number
        humidity: number
      }
      weather: Array<{
        main: string
        description: string
        icon: string
      }>
    }>
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const requestData: WeatherRequest = await req.json()
    const { latitude, longitude } = requestData

    // Validate input
    if (typeof latitude !== 'number' || typeof longitude !== 'number') {
      return new Response(
        JSON.stringify({ error: 'Invalid latitude or longitude' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Get API key from Supabase secrets
    const apiKey = Deno.env.get('OPENWEATHER_API_KEY')
    if (!apiKey) {
      console.error('OPENWEATHER_API_KEY not set in environment')
      return new Response(
        JSON.stringify({ error: 'Weather service not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`Fetching weather for coordinates: ${latitude}, ${longitude}`)

    // Fetch current weather
    const currentWeatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${latitude}&lon=${longitude}&appid=${apiKey}&units=metric`
    const currentWeatherResponse = await fetch(currentWeatherUrl)

    if (!currentWeatherResponse.ok) {
      const errorText = await currentWeatherResponse.text()
      console.error('OpenWeatherMap API error (current):', errorText)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch current weather' }),
        {
          status: currentWeatherResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const currentWeatherData = await currentWeatherResponse.json()

    // Fetch forecast
    const forecastUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${latitude}&lon=${longitude}&appid=${apiKey}&units=metric`
    const forecastResponse = await fetch(forecastUrl)

    if (!forecastResponse.ok) {
      const errorText = await forecastResponse.text()
      console.error('OpenWeatherMap API error (forecast):', errorText)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch forecast' }),
        {
          status: forecastResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const forecastData = await forecastResponse.json()

    // Combine responses
    const response: WeatherResponse = {
      currentWeather: currentWeatherData,
      forecast: forecastData
    }

    console.log(`Successfully fetched weather data for ${currentWeatherData.name}`)

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error processing weather request:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : String(error)
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
