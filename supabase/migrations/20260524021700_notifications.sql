-- Migration: Create App Notifications
-- Description: Creates a table to store ephemeral notifications that users can toggle.

CREATE TABLE public.app_notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    notification_type text NOT NULL, -- e.g. 'subscription_reminder', 'card_expiration', 'message_alert'
    title text NOT NULL,
    body text NOT NULL,
    resource_id uuid,
    resource_type text,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);

-- Turn on RLS
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can read their own notifications
CREATE POLICY "Allow users to read their own notifications" ON public.app_notifications
FOR SELECT USING (user_id = auth.uid());

-- Policy 2: Users can delete their own notifications
CREATE POLICY "Allow users to delete their own notifications" ON public.app_notifications
FOR DELETE USING (user_id = auth.uid());

-- Policy 3: Authenticated users can insert notifications
CREATE POLICY "Allow authenticated users to insert notifications" ON public.app_notifications
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policy 4: Users can update their own notifications
CREATE POLICY "Allow users to update their own notifications" ON public.app_notifications
FOR UPDATE USING (user_id = auth.uid());

-- User Preferences for Notifications
CREATE TABLE public.user_preferences (
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    reminders_enabled boolean DEFAULT true,
    security_enabled boolean DEFAULT true,
    messages_enabled boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to manage their own preferences" ON public.user_preferences
FOR ALL USING (user_id = auth.uid());

-- Function to safely get/create preferences
CREATE OR REPLACE FUNCTION get_or_create_user_preferences(uid uuid)
RETURNS SETOF public.user_preferences AS $$
BEGIN
    -- Try to insert if it doesn't exist
    INSERT INTO public.user_preferences (user_id) 
    VALUES (uid)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN QUERY SELECT * FROM public.user_preferences WHERE user_id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
