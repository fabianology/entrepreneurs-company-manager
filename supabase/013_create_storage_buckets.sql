-- Create buckets for Company Documents and Avatars
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('CompanyDocuments', 'CompanyDocuments', true),
  ('Avatars', 'Avatars', true)
ON CONFLICT (id) DO UPDATE SET public = excluded.public;

-- Policies for Avatars bucket
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'Avatars' AND auth.uid() = owner);

CREATE POLICY "Anyone can view avatars"
ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'Avatars');

CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE TO authenticated 
USING (bucket_id = 'Avatars' AND auth.uid() = owner);

CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'Avatars' AND auth.uid() = owner);
