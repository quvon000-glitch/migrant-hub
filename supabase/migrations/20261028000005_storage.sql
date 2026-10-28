-- Public buckets with unguessable paths: <user id>/<uuid>.<ext>. Each user writes only to their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 5 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp']),
  ('ad-photos', 'ad-photos', true, 8 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp']),
  ('chat-media', 'chat-media', true, 40 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'audio/mp4', 'audio/aac', 'audio/m4a', 'audio/x-m4a', 'audio/mpeg', 'audio/ogg', 'audio/webm'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "upload to own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'ad-photos', 'chat-media') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "update own files" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'ad-photos', 'chat-media') and owner_id = (select auth.uid())::text);
create policy "remove own files" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'ad-photos', 'chat-media') and owner_id = (select auth.uid())::text);
