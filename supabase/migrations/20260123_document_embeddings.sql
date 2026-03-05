-- Migration: Add document embeddings for AI course assistant
-- Date: 2026-01-23

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create document_embeddings table
CREATE TABLE IF NOT EXISTS document_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL,
    document_id UUID REFERENCES course_documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    embedding VECTOR(1536),  -- OpenAI text-embedding-3-small dimension
    metadata JSONB,  -- {page_number, section_title, file_name}
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_document_embeddings_user_id ON document_embeddings(user_id);
CREATE INDEX IF NOT EXISTS idx_document_embeddings_course_id ON document_embeddings(course_id);
CREATE INDEX IF NOT EXISTS idx_document_embeddings_document_id ON document_embeddings(document_id);

-- HNSW index for fast vector similarity search
CREATE INDEX IF NOT EXISTS idx_document_embeddings_vector
    ON document_embeddings
    USING hnsw (embedding vector_cosine_ops);

-- Enable RLS
ALTER TABLE document_embeddings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own embeddings"
    ON document_embeddings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own embeddings"
    ON document_embeddings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own embeddings"
    ON document_embeddings FOR DELETE
    USING (auth.uid() = user_id);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION search_document_embeddings(
    query_embedding VECTOR(1536),
    course_id_param UUID,
    user_id_param UUID,
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    chunk_text TEXT,
    metadata JSONB,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        de.id,
        de.chunk_text,
        de.metadata,
        1 - (de.embedding <=> query_embedding) AS similarity
    FROM document_embeddings de
    WHERE de.course_id = course_id_param
        AND de.user_id = user_id_param
        AND 1 - (de.embedding <=> query_embedding) > match_threshold
    ORDER BY de.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update course_documents table to add processing status
ALTER TABLE course_documents
ADD COLUMN IF NOT EXISTS processing_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS embeddings_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_processed_at TIMESTAMPTZ;

-- Add check constraint for processing_status
ALTER TABLE course_documents
ADD CONSTRAINT IF NOT EXISTS course_documents_processing_status_check
CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed'));
