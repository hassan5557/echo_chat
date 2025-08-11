-- Create contacts table
-- Run this in your Supabase SQL Editor

-- Create contacts table
CREATE TABLE IF NOT EXISTS public.contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, contact_id)
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON public.contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_contact_id ON public.contacts(contact_id);

-- Enable Row Level Security
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own contacts" ON public.contacts;
DROP POLICY IF EXISTS "Users can insert their own contacts" ON public.contacts;
DROP POLICY IF EXISTS "Users can delete their own contacts" ON public.contacts;

-- Create RLS policies
-- Users can view their own contacts
CREATE POLICY "Users can view their own contacts" ON public.contacts
    FOR SELECT USING (
        auth.uid() = user_id
    );

-- Users can insert their own contacts (fixed policy)
CREATE POLICY "Users can insert their own contacts" ON public.contacts
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        auth.uid() IS NOT NULL
    );

-- Users can update their own contacts
CREATE POLICY "Users can update their own contacts" ON public.contacts
    FOR UPDATE USING (
        auth.uid() = user_id
    );

-- Users can delete their own contacts
CREATE POLICY "Users can delete their own contacts" ON public.contacts
    FOR DELETE USING (
        auth.uid() = user_id
    );

-- Grant permissions
GRANT ALL ON public.contacts TO authenticated; 