create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Yeni kullanıcı',
  day_start time not null default '08:00',
  day_end time not null default '22:00',
  created_at timestamptz not null default now()
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('member', 'lead')) default 'member',
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create or replace function public.add_team_creator_as_lead()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.team_members (team_id, user_id, role) values (new.id, new.created_by, 'lead');
  return new;
end;
$$;

create trigger add_team_creator_as_lead
after insert on public.teams
for each row execute function public.add_team_creator_as_lead();

create table public.weekly_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  title text not null,
  block_type text not null check (block_type in ('lesson', 'bus', 'study', 'work', 'meeting', 'personal')),
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null check (end_time > start_time),
  repeats_weekly boolean not null default true,
  week_start date,
  created_at timestamptz not null default now()
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  assigned_to uuid references public.profiles(id) on delete set null,
  team_id uuid references public.teams(id) on delete cascade,
  title text not null,
  duration_minutes integer not null check (duration_minutes > 0),
  due_date date,
  recurrence_weekday smallint check (recurrence_weekday between 0 and 6),
  status text not null check (status in ('open', 'planned', 'done')) default 'open',
  created_at timestamptz not null default now()
);

create table public.plan_blocks (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid references public.teams(id) on delete cascade,
  title text not null,
  block_type text not null check (block_type in ('study', 'work', 'meeting')),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  status text not null check (status in ('suggested', 'confirmed', 'done')) default 'suggested',
  created_at timestamptz not null default now()
);

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  created_at timestamptz not null default now()
);

create table public.research_notes (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  query text not null,
  summary text not null,
  citations jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_team_member(target_team uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members where team_id = target_team and user_id = auth.uid());
$$;

create or replace function public.is_team_lead(target_team uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members where team_id = target_team and user_id = auth.uid() and role = 'lead');
$$;

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.weekly_blocks enable row level security;
alter table public.tasks enable row level security;
alter table public.plan_blocks enable row level security;
alter table public.meetings enable row level security;
alter table public.research_notes enable row level security;

create policy "profiles visible to owner or teammates" on public.profiles for select to authenticated using (id = auth.uid() or exists (select 1 from public.team_members mine join public.team_members theirs on mine.team_id = theirs.team_id where mine.user_id = auth.uid() and theirs.user_id = profiles.id));
create policy "profiles own changes" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "teams visible to members" on public.teams for select to authenticated using (public.is_team_member(id));
create policy "teams created by user" on public.teams for insert to authenticated with check (created_by = auth.uid());
create policy "teams managed by leads" on public.teams for update to authenticated using (public.is_team_lead(id));
create policy "members visible to team" on public.team_members for select to authenticated using (public.is_team_member(team_id));
create policy "leads manage members" on public.team_members for all to authenticated using (public.is_team_lead(team_id)) with check (public.is_team_lead(team_id));
create policy "blocks visible to owner or team" on public.weekly_blocks for select to authenticated using (user_id = auth.uid() or (team_id is not null and public.is_team_member(team_id)));
create policy "users create own blocks" on public.weekly_blocks for insert to authenticated with check (user_id = auth.uid() and (team_id is null or public.is_team_member(team_id)));
create policy "owner edits blocks" on public.weekly_blocks for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owner deletes blocks" on public.weekly_blocks for delete to authenticated using (user_id = auth.uid());
create policy "tasks visible to owner assignee or team" on public.tasks for select to authenticated using (created_by = auth.uid() or assigned_to = auth.uid() or (team_id is not null and public.is_team_member(team_id)));
create policy "users create personal tasks and leads create team tasks" on public.tasks for insert to authenticated with check (created_by = auth.uid() and (team_id is null or public.is_team_lead(team_id)));
create policy "task owner or team lead edits" on public.tasks for update to authenticated using (created_by = auth.uid() or (team_id is not null and public.is_team_lead(team_id)));
create policy "plan blocks visible to owner or team" on public.plan_blocks for select to authenticated using (user_id = auth.uid() or (team_id is not null and public.is_team_member(team_id)));
create policy "owner or lead creates plan block" on public.plan_blocks for insert to authenticated with check (user_id = auth.uid() or (team_id is not null and public.is_team_lead(team_id)));
create policy "owner or lead updates plan block" on public.plan_blocks for update to authenticated using (user_id = auth.uid() or (team_id is not null and public.is_team_lead(team_id)));
create policy "meetings visible to members" on public.meetings for select to authenticated using (public.is_team_member(team_id));
create policy "leads manage meetings" on public.meetings for all to authenticated using (public.is_team_lead(team_id)) with check (public.is_team_lead(team_id));
create policy "notes visible with task" on public.research_notes for select to authenticated using (exists (select 1 from public.tasks where tasks.id = task_id and (tasks.created_by = auth.uid() or tasks.assigned_to = auth.uid() or (tasks.team_id is not null and public.is_team_member(tasks.team_id)))));
create policy "author saves note for visible task" on public.research_notes for insert to authenticated with check (author_id = auth.uid());

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.teams, public.team_members, public.weekly_blocks, public.tasks, public.plan_blocks, public.meetings, public.research_notes to authenticated;

revoke all on function public.add_team_creator_as_lead() from public;
revoke all on function public.is_team_member(uuid) from public;
revoke all on function public.is_team_lead(uuid) from public;
grant execute on function public.is_team_member(uuid), public.is_team_lead(uuid) to authenticated;

create index team_members_user_team_idx on public.team_members (user_id, team_id);
create index weekly_blocks_user_weekday_idx on public.weekly_blocks (user_id, weekday);
create index weekly_blocks_team_weekday_idx on public.weekly_blocks (team_id, weekday) where team_id is not null;
create index tasks_assignee_status_due_idx on public.tasks (assigned_to, status, due_date);
create index tasks_team_status_due_idx on public.tasks (team_id, status, due_date) where team_id is not null;
create index plan_blocks_user_starts_at_idx on public.plan_blocks (user_id, starts_at);
create index plan_blocks_team_starts_at_idx on public.plan_blocks (team_id, starts_at) where team_id is not null;
create index meetings_team_starts_at_idx on public.meetings (team_id, starts_at);
create index research_notes_task_created_at_idx on public.research_notes (task_id, created_at desc);
