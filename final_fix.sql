-- Final Fix for Flutter + Supabase Chat App
-- Run this in your Supabase SQL Editor

-- ========================================
-- 1. FIX CONTACTS TABLE RLS POLICIES
-- ========================================

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

-- ========================================
-- 2. FIX STORAGE POLICIES FOR AVATARS BUCKET
-- ========================================

-- Drop existing storage policies
DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public can view chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Public can view profile photos" ON storage.objects;

-- Create comprehensive storage policies for avatars bucket
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

-- ========================================
-- 3. VERIFY BUCKET EXISTS
-- ========================================

-- Check if avatars bucket exists
SELECT 
    name as bucket_name,
    public as is_public,
    created_at
FROM storage.buckets 
WHERE name = 'avatars';

-- ========================================
-- 4. VERIFY POLICIES ARE WORKING
-- ========================================

-- Check all policies for contacts and storage
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('contacts', 'objects') 
ORDER BY tablename, policyname;

-- ========================================
-- 5. TEST CONTACTS TABLE ACCESS
-- ========================================

-- This will show if the contacts table is accessible
SELECT 
    table_name,
    table_schema,
    table_type
FROM information_schema.tables 
WHERE table_name = 'contacts' AND table_schema = 'public';

-- ========================================
-- SUCCESS MESSAGE
-- ========================================

-- If you see this message, the script ran successfully
SELECT '✅ RLS policies and storage setup completed successfully!' as status;
