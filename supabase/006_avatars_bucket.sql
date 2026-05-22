-- 1. Create a public storage bucket for Avatars
INSERT INTO storage.buckets (id, name, public)
VALUES ('Avatars', 'Avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Setup RLS for the Avatars bucket

-- Allow public read access to all avatars
CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'Avatars');

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'Avatars' AND auth.uid() = owner);

-- Allow authenticated users to update their own avatar
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'Avatars' AND auth.uid() = owner);

-- Allow authenticated users to delete their own avatar
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'Avatars' AND auth.uid() = owner);
