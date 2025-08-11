-- Fix RLS policies for the users table
-- Run this in your Supabase SQL Editor

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;

-- Create new policies that allow all authenticated users to read all user profiles
CREATE POLICY "Users can view all users" ON public.users
    FOR SELECT USING (auth.role() = 'authenticated');

-- Allow users to insert their own profile
CREATE POLICY "Users can insert their own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Create a function to sync user profiles
CREATE OR REPLACE FUNCTION sync_user_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, name, avatar_url, last_active)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        NULL,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        last_active = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically sync user profiles
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION sync_user_profile();

-- Create trigger to update user profiles when auth users are updated
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION sync_user_profile();

-- Function to manually sync all existing auth users
CREATE OR REPLACE FUNCTION sync_all_auth_users()
RETURNS void AS $$
DECLARE
    auth_user RECORD;
BEGIN
    FOR auth_user IN SELECT * FROM auth.users LOOP
        INSERT INTO public.users (id, email, name, avatar_url, last_active)
        VALUES (
            auth_user.id,
            auth_user.email,
            COALESCE(auth_user.raw_user_meta_data->>'name', 'User'),
            NULL,
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            name = EXCLUDED.name,
            last_active = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.users TO authenticated;
GRANT EXECUTE ON FUNCTION sync_all_auth_users() TO authenticated; 

-- Migration script to add status column to existing messages table
-- Run this in your Supabase SQL Editor if you have an existing messages table

-- Add status column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.messages ADD COLUMN status TEXT DEFAULT 'sent';
        ALTER TABLE public.messages ADD CONSTRAINT check_status CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed'));
    END IF;
END $$;

-- Create index for status column if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_messages_status ON public.messages(status);

-- Update existing messages to have 'sent' status
UPDATE public.messages SET status = 'sent' WHERE status IS NULL;

-- Update messages that are read to have 'read' status
UPDATE public.messages SET status = 'read' WHERE is_read = true AND status = 'sent'; 

-- Fix for infinite recursion in group_members policies
-- Run this in your Supabase SQL editor

-- First, drop the problematic policies
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Group creators can add members" ON public.group_members;
DROP POLICY IF EXISTS "Users can view groups they're in" ON public.groups;
DROP POLICY IF EXISTS "Users can view group messages" ON public.group_messages;
DROP POLICY IF EXISTS "Group members can send messages" ON public.group_messages;

-- Create simplified, non-recursive policies for group_members
CREATE POLICY "Users can view their own group memberships" ON public.group_members 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Group creators can add members" ON public.group_members 
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.groups 
    WHERE id = group_id AND creator_id = auth.uid()
  )
);

-- Create simplified policies for groups
CREATE POLICY "Users can view groups they created" ON public.groups 
FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can view groups they're members of" ON public.groups 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members 
    WHERE group_id = id AND user_id = auth.uid()
  )
);

CREATE POLICY "Users can create groups" ON public.groups 
FOR INSERT WITH CHECK (auth.uid() = creator_id);

-- Create simplified policies for group_messages
CREATE POLICY "Group members can view messages" ON public.group_messages 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members 
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
);

CREATE POLICY "Group members can send messages" ON public.group_messages 
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.group_members 
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
);

-- Alternative: If you want to temporarily disable RLS for testing
-- ALTER TABLE public.group_members DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.groups DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.group_messages DISABLE ROW LEVEL SECURITY; 