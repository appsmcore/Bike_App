-- Fix groups RLS so authenticated users can create groups and read them back.
-- Run in Supabase SQL Editor (safe to re-run).

-- Creators must be able to SELECT their new row (insert().select()),
-- including private groups before membership is written.
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

-- Ensure table grants for the API roles (no-op if already granted)
grant select, insert, update on public.groups to authenticated;
grant select, insert, update, delete on public.group_members to authenticated;
