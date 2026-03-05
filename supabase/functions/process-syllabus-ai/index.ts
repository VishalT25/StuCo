import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
// @deno-types="npm:@types/pdf-parse"
import pdf from "npm:pdf-parse@1.1.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SyllabusRequest {
  method: string // 'text', 'image', or 'pdf'
  textInput?: string
  fileURL?: string
  courseId: string
  userRole: string
}

interface AssignmentItem {
  name: string
  dueDate?: string | null // ISO 8601 date string
  weight?: number | null // 0.0 to 1.0 (e.g., 0.25 for 25%)
  category: string // 'homework', 'quiz', 'exam', 'project', 'participation', 'lab', 'other'
  notes: string
}

interface SyllabusResponse {
  success: boolean
  assignments: AssignmentItem[]
  confidence: number
  missingFields: string[]
  courseMetadata?: {
    courseName?: string
    courseCode?: string
    instructor?: string
    semester?: string
    totalWeight?: number
  }
  error?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const requestData: SyllabusRequest = await req.json()
    console.log('Processing syllabus import request:', {
      method: requestData.method,
      courseId: requestData.courseId,
      userRole: requestData.userRole,
      hasFileURL: !!requestData.fileURL,
      textLength: requestData.textInput?.length || 0
    })

    // Validate request
    if (!requestData.courseId) {
      throw new Error('Course ID is required')
    }

    if (!requestData.textInput && !requestData.fileURL) {
      throw new Error('Either textInput or fileURL must be provided')
    }

    // Get OpenAI API key from environment
    const openAIKey = Deno.env.get('OPENAI_API_KEY')
    if (!openAIKey) {
      throw new Error('OpenAI API key not configured')
    }

    // Prepare the prompt for ChatGPT
    const systemPrompt = `You are a course syllabus parser. Extract ALL assignments, exams, quizzes, and projects from the provided syllabus.

For each item, extract:
- name: Assignment/exam name
- dueDate: ISO 8601 date string (or null if not specified)
- weight: Percentage as decimal from 0.0 to 1.0 (e.g., 0.15 for 15%)
- category: One of [homework, quiz, exam, project, participation, lab, other]
- notes: Any additional details (requirements, chapters covered, etc.)

Return ONLY valid JSON in this exact format:
{
  "assignments": [
    {
      "name": "Midterm Exam",
      "dueDate": "2024-03-15T00:00:00Z",
      "weight": 0.25,
      "category": "exam",
      "notes": "Chapters 1-5"
    }
  ],
  "confidence": 0.95,
  "missingFields": ["dueDate for Assignment 3"],
  "courseMetadata": {
    "courseName": "Introduction to Computer Science",
    "courseCode": "CS 101",
    "instructor": "Dr. Smith",
    "semester": "Fall 2024"
  }
}

IMPORTANT:
- Extract ALL graded items, even if some information is missing
- For missing dueDates, use null
- For missing weights, use null
- Infer category from item name if not explicitly stated
- Set confidence between 0.0 and 1.0 based on clarity of information
- List any missing critical information in missingFields array`

    let userContent: string

    if (requestData.method === 'text') {
      userContent = requestData.textInput!
    } else if (requestData.method === 'pdf' && requestData.fileURL) {
      // Extract text from PDF
      console.log('Downloading PDF from:', requestData.fileURL)
      const pdfResponse = await fetch(requestData.fileURL)
      if (!pdfResponse.ok) {
        throw new Error(`Failed to download PDF: ${pdfResponse.statusText}`)
      }

      const pdfBuffer = await pdfResponse.arrayBuffer()
      console.log('PDF downloaded, size:', pdfBuffer.byteLength, 'bytes')

      // Parse PDF to extract text
      // Convert ArrayBuffer to Uint8Array for pdf-parse
      const pdfData = await pdf(new Uint8Array(pdfBuffer))
      userContent = pdfData.text
      console.log('Extracted text from PDF, length:', userContent.length, 'characters')

      if (!userContent || userContent.trim().length === 0) {
        throw new Error('Could not extract text from PDF. The PDF might be an image-based scan.')
      }
    } else if (requestData.fileURL) {
      // For images, we'll use vision API
      userContent = `Please process the syllabus from this file: ${requestData.fileURL}`
    } else {
      throw new Error('Invalid request: no content provided')
    }

    // Call OpenAI API
    let messages: any[]

    if (requestData.method === 'image') {
      // Use vision model for images only
      messages = [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Extract all assignments, exams, and graded items from this syllabus:'
            },
            {
              type: 'image_url',
              image_url: {
                url: requestData.fileURL
              }
            }
          ]
        }
      ]
    } else {
      // Text mode (includes PDF text extraction)
      messages = [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: userContent
        }
      ]
    }

    const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: messages,
        temperature: 0.1, // Low temperature for more consistent parsing
        response_format: { type: 'json_object' }
      }),
    })

    if (!openAIResponse.ok) {
      const errorData = await openAIResponse.text()
      console.error('OpenAI API error:', errorData)
      throw new Error(`OpenAI API error: ${openAIResponse.statusText}`)
    }

    const openAIData = await openAIResponse.json()
    const aiContent = openAIData.choices[0]?.message?.content

    if (!aiContent) {
      throw new Error('No response from OpenAI')
    }

    console.log('OpenAI response:', aiContent.substring(0, 500))

    // Parse the AI response
    const parsedData = JSON.parse(aiContent)

    // Validate and normalize the response
    const response: SyllabusResponse = {
      success: true,
      assignments: parsedData.assignments || [],
      confidence: parsedData.confidence || 0.8,
      missingFields: parsedData.missingFields || [],
      courseMetadata: parsedData.courseMetadata
    }

    // Validate each assignment
    response.assignments = response.assignments.map(assignment => {
      // Ensure category is valid
      const validCategories = ['homework', 'quiz', 'exam', 'project', 'participation', 'lab', 'other']
      if (!validCategories.includes(assignment.category?.toLowerCase())) {
        assignment.category = 'other'
      } else {
        assignment.category = assignment.category.toLowerCase()
      }

      // Ensure weight is in valid range
      if (assignment.weight !== null && assignment.weight !== undefined) {
        if (assignment.weight > 1) {
          assignment.weight = assignment.weight / 100 // Convert percentage to decimal
        }
        assignment.weight = Math.max(0, Math.min(1, assignment.weight))
      }

      // Ensure notes is a string
      if (!assignment.notes) {
        assignment.notes = ''
      }

      return assignment
    })

    console.log(`Successfully parsed ${response.assignments.length} assignments with confidence ${response.confidence}`)

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Error processing syllabus:', error)

    const errorResponse: SyllabusResponse = {
      success: false,
      assignments: [],
      confidence: 0,
      missingFields: [],
      error: error.message || 'Unknown error occurred'
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Return 200 even for errors to allow client-side handling
      }
    )
  }
})
