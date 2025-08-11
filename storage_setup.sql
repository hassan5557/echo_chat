-- Storage Bucket Setup for Profile Photos
-- Run this in your Supabase SQL Editor

-- Create a storage bucket for profile photos
-- Note: You need to do this manually in the Supabase Dashboard
-- Go to Storage > Create a new bucket named 'avatars'

-- Set up RLS policies for the avatars bucket
-- This allows authenticated users to upload their own profile photos

-- Policy to allow users to upload their own profile photos
CREATE POLICY "Users can upload their own profile photos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Policy to allow users to update their own profile photos
CREATE POLICY "Users can update their own profile photos" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Policy to allow users to delete their own profile photos
CREATE POLICY "Users can delete their own profile photos" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Policy to allow public read access to profile photos
CREATE POLICY "Public can view profile photos" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

-- Alternative: If you want to use a different bucket name, replace 'avatars' with your bucket name
-- Example: 'images', 'public', 'storage', etc.

-- To create the bucket manually:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to Storage
-- 3. Click "Create a new bucket"
-- 4. Name it "avatars" (or your preferred name)
-- 5. Make it public (check the "Public bucket" option)
-- 6. Click "Create bucket"

-- After creating the bucket, the policies above will work 