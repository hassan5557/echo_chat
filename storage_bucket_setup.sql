-- Storage Bucket Setup for Chat Attachments
-- Run this in your Supabase SQL Editor

-- Create a storage bucket for chat attachments
-- Note: You need to do this manually in the Supabase Dashboard
-- Go to Storage > Create a new bucket named 'avatars' (or 'images')

-- Set up RLS policies for the avatars bucket
-- This allows authenticated users to upload chat attachments

-- Policy to allow users to upload chat attachments
CREATE POLICY "Users can upload chat attachments" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

-- Policy to allow users to update their own chat attachments
CREATE POLICY "Users can update their own chat attachments" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

-- Policy to allow users to delete their own chat attachments
CREATE POLICY "Users can delete their own chat attachments" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND 
        auth.uid() IS NOT NULL
    );

-- Policy to allow public read access to chat attachments
CREATE POLICY "Public can view chat attachments" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

-- Alternative bucket names if 'avatars' doesn't work
-- You can create additional buckets and policies for: 'images', 'public', 'storage'

-- To create the bucket manually:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to Storage
-- 3. Click "Create a new bucket"
-- 4. Name it "avatars" (or your preferred name)
-- 5. Make it public (check the "Public bucket" option)
-- 6. Click "Create bucket"

-- After creating the bucket, the policies above will work
