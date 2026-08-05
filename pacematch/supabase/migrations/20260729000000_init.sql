-- PaceMatch schema (prepared for later Supabase wiring)
-- Apply with: supabase db push / SQL editor

create extension if not exists postgis;

create type bike_type as enum ('road','mtb','gravel','touring','ebike');
create type fitness_level as enum ('beginner','intermediate','advanced','expert');
create type difficulty as enum ('easy','moderate','challenging','expert');
create type rsvp_status as enum ('joined','maybe','declined','waitlist');
create type group_visibility as enum ('public','private');
create type ride_status as enum ('draft','published','cancelled','completed');

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null,
  avatar_url text,
  location_name text,
  location geography(point, 4326),
  bio text,
  fitness_level fitness_level default 'intermediate',
  preferred_distance_min_km numeric,
  preferred_distance_max_km numeric,
  preferred_elevation_max_m numeric,
  avg_speed_kmh numeric,
  preferred_days int[] default '{}',
  preferred_times text[] default '{}',
  reliability_score numeric default 100,
  community_score numeric default 0,
  rides_joined_count int default 0,
  rides_organized_count int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.profile_bike_types (
  profile_id uuid references public.profiles on delete cascade,
  bike_type bike_type not null,
  primary key (profile_id, bike_type)
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  cover_url text,
  visibility group_visibility default 'public',
  location_name text,
  location geography(point, 4326),
  created_by uuid references public.profiles,
  created_at timestamptz default now()
);

create table public.group_members (
  group_id uuid references public.groups on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  role text check (role in ('member','admin','owner')) default 'member',
  status text check (status in ('pending','active','banned')) default 'active',
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

create table public.routes (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.profiles,
  name text,
  gpx_url text,
  geojson jsonb,
  distance_km numeric,
  elevation_gain_m numeric,
  avg_gradient numeric,
  max_gradient numeric,
  estimated_duration_min int,
  surface_type text,
  difficulty difficulty,
  elevation_profile jsonb,
  start_point geography(point, 4326),
  end_point geography(point, 4326),
  created_at timestamptz default now()
);

create table public.rides (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups,
  organizer_id uuid references public.profiles not null,
  title text not null,
  description text,
  starts_at timestamptz not null,
  meeting_point_name text,
  meeting_point geography(point, 4326),
  bike_category bike_type not null,
  route_id uuid references public.routes,
  rider_limit int,
  skill_level fitness_level,
  estimated_pace_kmh numeric,
  cover_url text,
  status ride_status default 'published',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.ride_rsvps (
  ride_id uuid references public.rides on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  status rsvp_status not null,
  updated_at timestamptz default now(),
  primary key (ride_id, user_id)
);

create index rides_starts_at_idx on public.rides (starts_at);
create index rides_bike_idx on public.rides (bike_category);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.rides enable row level security;
alter table public.ride_rsvps enable row level security;
alter table public.routes enable row level security;

-- Minimal starter policies (expand later)
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select to authenticated using (true);

create policy "Users update own profile"
  on public.profiles for update to authenticated using (auth.uid() = id);

create policy "Public rides readable"
  on public.rides for select to authenticated using (status = 'published');

create policy "Users manage own rsvps"
  on public.ride_rsvps for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
