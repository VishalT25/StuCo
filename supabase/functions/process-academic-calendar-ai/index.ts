import "https://deno.land/x/xhr@0.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as pdfjsLib from 'npm:pdfjs-dist@4.0.379';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ACADEMIC_CALENDAR_PROMPT = `You are an academic calendar parsing assistant. I will provide you with text/image/document containing academic calendar information. Please extract all academic breaks, important dates, and semester information.

IMPORTANT INSTRUCTIONS:
- Output only valid JSON — no text, explanations, or markdown
- Extract semester/term dates, breaks, reading weeks, exam periods, holidays
- Use ISO date format (YYYY-MM-DD) for all dates
- Break types should be: "winter", "spring", "summer", "reading", "exam", "holiday", "other"

Required JSON structure:
{
  "calendarName": "extracted or provided name",
  "academicYear": "extracted or provided year",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD",
  "breaks": [
    {
      "name": "Break Name",
      "startDate": "YYYY-MM-DD",
      "endDate": "YYYY-MM-DD",
      "type": "winter|spring|summer|reading|exam|holiday|other"
    }
  ]
}`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const {
      method,
      textInput,
      fileURL,
      calendarName,
      academicYear,
      startDate,
      endDate
    } = await req.json();

    console.log('Processing academic calendar with method:', method);

    // Parse request and verify user
    const { user, supabase } = await parseRequest(req);

    // Check subscription status
    const { data: subscriber } = await supabase
      .from('subscribers')
      .select('role')
      .eq('user_id', user.id)
      .single();

    if (!subscriber || (subscriber.role !== 'premium' && subscriber.role !== 'founder')) {
      return jsonError('Premium subscription required for AI calendar processing', 403);
    }

    let content = '';

    // Extract content based on method
    if (method === 'text') {
      content = textInput || '';
      console.log('Using text input, length:', content.length);
    } else if (method === 'image' && fileURL) {
      console.log('Extracting text from image...');
      content = await extractTextFromImage(fileURL);
    } else if (method === 'pdf' && fileURL) {
      console.log('Extracting text from PDF...');
      content = await extractTextFromPDF(fileURL);
    } else {
      return jsonError('Invalid method or missing required parameters', 400);
    }

    if (!content || content.trim().length === 0) {
      return jsonError('No content could be extracted from the input', 400);
    }

    console.log('Extracted content length:', content.length);

    // Construct the prompt with context
    const contextPrompt = `
Context provided:
- Calendar Name: ${calendarName}
- Academic Year: ${academicYear}
- Expected Start: ${startDate}
- Expected End: ${endDate}

Extract information from the following content and return only JSON:

${content}`;

    const fullPrompt = ACADEMIC_CALENDAR_PROMPT + '\n\n' + contextPrompt;

    // Call ChatGPT to parse the calendar
    console.log('Sending to ChatGPT for parsing...');
    const aiResponse = await askGPT(fullPrompt);

    console.log('ChatGPT response:', aiResponse);

    // Parse JSON response
    const parsedData = tryParseJson(aiResponse);

    if (!parsedData || !parsedData.calendarName || !parsedData.breaks) {
      console.error('Failed to parse AI response. Response was:', aiResponse);
      return jsonError('Failed to parse calendar data from AI response', 500);
    }

    console.log('Successfully parsed', parsedData.breaks.length, 'breaks');

    // Return successful response
    return new Response(
      JSON.stringify({
        success: true,
        method,
        confidence: 0.85,
        calendarData: parsedData
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    );

  } catch (error) {
    console.error('Error in process-academic-calendar-ai:', error);
    return jsonError(
      error instanceof Error ? error.message : 'Unknown error occurred',
      500,
      error
    );
  }
});

async function parseRequest(req: Request) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) throw new Error('Missing authorization header');

  const jwt = authHeader.replace('Bearer ', '');

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const { data: { user }, error } = await supabase.auth.getUser(jwt);

  if (error || !user) {
    throw new Error('Invalid authentication token');
  }

  return { user, supabase };
}

function jsonError(message: string, status = 500, raw?: any) {
  console.error('Error:', message, raw);
  return new Response(
    JSON.stringify({ error: message }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status
    }
  );
}

async function extractTextFromImage(imageUrl: string): Promise<string> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiKey) throw new Error('OpenAI API key not configured');

  console.log('Calling GPT-4o vision for image...');

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Extract all text from this academic calendar image, preserving dates, break names, and all relevant information. Include everything you see.'
            },
            {
              type: 'image_url',
              image_url: {
                url: imageUrl,
                detail: 'high'
              }
            }
          ]
        }
      ],
      max_tokens: 4000
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  const extractedText = data.choices?.[0]?.message?.content || '';

  console.log('Extracted from image:', extractedText.substring(0, 200) + '...');

  return extractedText;
}

async function extractTextFromPDF(pdfUrl: string): Promise<string> {
  console.log('Downloading PDF from:', pdfUrl);

  // Download the PDF file
  const pdfResponse = await fetch(pdfUrl);
  if (!pdfResponse.ok) {
    throw new Error(`Failed to download PDF: ${pdfResponse.status}`);
  }

  const pdfBuffer = await pdfResponse.arrayBuffer();
  console.log('PDF downloaded, size:', pdfBuffer.byteLength, 'bytes');

  // Extract text using PDF.js
  console.log('Extracting text with PDF.js...');

  const loadingTask = pdfjsLib.getDocument({
    data: new Uint8Array(pdfBuffer),
    useSystemFonts: true,
  });

  const pdf = await loadingTask.promise;
  console.log('PDF loaded, pages:', pdf.numPages);

  let fullText = '';

  // Extract text from all pages
  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum);
    const textContent = await page.getTextContent();

    const pageText = textContent.items
      .map((item: any) => item.str)
      .join(' ');

    fullText += pageText + '\n\n';
    console.log(`Extracted text from page ${pageNum}, length: ${pageText.length}`);
  }

  console.log('Total extracted text length:', fullText.length);

  if (!fullText || fullText.trim().length < 10) {
    throw new Error('Failed to extract meaningful text from PDF. The PDF might be empty or consist of images.');
  }

  return fullText.trim();
}

async function askGPT(prompt: string): Promise<string> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiKey) throw new Error('OpenAI API key not configured');

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are a specialized academic calendar parser. Return only valid JSON with no additional text or markdown. Be thorough and extract ALL breaks, holidays, and important dates you can find.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 4000,
      response_format: { type: "json_object" }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content || '';
}

function tryParseJson(text: string): any {
  try {
    // Remove markdown code blocks if present
    let cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }

    const parsed = JSON.parse(cleaned);
    console.log('Successfully parsed JSON with', parsed.breaks?.length || 0, 'breaks');
    return parsed;
  } catch (error) {
    console.error('JSON parse error:', error);
    console.error('Failed to parse text:', text);
    return null;
  }
}
