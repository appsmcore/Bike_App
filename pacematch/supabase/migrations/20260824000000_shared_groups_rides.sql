-- Shared groups & rides for multi-device testing.
-- Run in Supabase SQL Editor after the init + auth migrations.

-- App-friendly columns on rides (denormalized for the Flutter client)
alter table public.rides
  add column if not exists distance_km numeric,
  add column if not exists elevation_gain_m integer,
  add column if not exists difficulty difficulty default 'moderate',
  add column if not exists elevation_profile jsonb default '[]'::jsonb,
  add column if not exists route_latlngs jsonb default '[]'::jsonb,
  add column if not exists start_lat double precision,
  add column if not exists start_lng double precision;

-- ---------- Groups ----------
drop policy if exists "Groups readable" on public.groups;
create policy "Groups readable"
  on public.groups for select to authenticated
  using (
    visibility = 'public'
    or created_by = auth.uid()
    or exists (
      select 1 from public.group_members m
      where m.group_id = groups.id
        and m.user_id = auth.uid()
        and m.status = 'active'
    )
  );

drop policy if exists "Users create groups" on public.groups;
create policy "Users create groups"
  on public.groups for insert to authenticated
  with check (auth.uid() IS NOT NULL AND auth.uid() = created_by);

drop policy if exists "Creators update groups" on public.groups;
create policy "Creators update groups"
  on public.groups for update to authenticated
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

grant select, insert, update on public.groups to authenticated;
grant select, insert, update, delete on public.group_members to authenticated;

-- ---------- Group members ----------
drop policy if exists "Members readable" on public.group_members;
create policy "Members readable"
  on public.group_members for select to authenticated
  using (true);

drop policy if exists "Users manage own membership" on public.group_members;
create policy "Users manage own membership"
  on public.group_members for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users leave groups" on public.group_members;
create policy "Users leave groups"
  on public.group_members for delete to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users update own membership" on public.group_members;
create policy "Users update own membership"
  on public.group_members for update to authenticated
  using (auth.uid() = user_id);

-- ---------- Rides ----------
drop policy if exists "Public rides readable" on public.rides;
create policy "Public rides readable"
  on public.rides for select to authenticated
  using (
    status = 'published'
    or organizer_id = auth.uid()
  );

drop policy if exists "Organizers insert rides" on public.rides;
create policy "Organizers insert rides"
  on public.rides for insert to authenticated
  with check (auth.uid() = organizer_id);

drop policy if exists "Organizers update rides" on public.rides;
create policy "Organizers update rides"
  on public.rides for update to authenticated
  using (auth.uid() = organizer_id);

-- ---------- RSVPs (ensure select so participant counts work) ----------
drop policy if exists "Rsvps readable" on public.ride_rsvps;
create policy "Rsvps readable"
  on public.ride_rsvps for select to authenticated
  using (true);

drop policy if exists "Users manage own rsvps" on public.ride_rsvps;
create policy "Users manage own rsvps"
  on public.ride_rsvps for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
