-- Fix RLS Policies for Contacts and Storage
-- Run this in your Supabase SQL Editor

-- 1. FIX CONTACTS TABLE RLS POLICIES
-- Drop all existing policies first
DROP POLICY IF EXISTS "Users can view their own contacts" ON public.contacts;
DROP POLICY IF EXISTS "Users can insert their own contacts" ON public.contacts;
DROP POLICY IF EXISTS "Users can update their own contacts" ON public.contacts;
DROP POLICY IF EXISTS "Users can delete their own contacts" ON public.contacts;

-- Create new policies with proper syntax
CREATE POLICY "Users can view their own contacts" ON public.contacts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own contacts" ON public.contacts
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND 
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Users can update their own contacts" ON public.contacts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own contacts" ON public.contacts
    FOR DELETE USING (auth.uid() = user_id);

-- 2. FIX STORAGE POLICIES (after creating the bucket)
-- Drop existing storage policies
DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public can view chat attachments" ON storage.objects;

-- Create storage policies for avatars bucket
CREATE POLICY "Users can upload chat attachments" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Users can update their own chat attachments" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Users can delete their own chat attachments" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Public can view chat attachments" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

-- 3. VERIFY POLICIES ARE WORKING
-- Check if policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('contacts', 'objects') 
ORDER BY tablename, policyname;
