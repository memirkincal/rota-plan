-- Bu script, önce Auth içinde rota-demo@example.com kullanıcısı oluşturulduktan sonra çalıştırılır.
-- Mevcut kişisel kayıtları silmez; yalnızca eksik demo kayıtlarını ekler.
do $$
declare
  demo_user uuid;
  demo_team uuid;
  demo_week date := date_trunc('week', current_date)::date;
begin
  select id into demo_user from auth.users where email = 'rota-demo@example.com';
  if demo_user is null then
    raise exception 'Önce Auth kullanıcısı rota-demo@example.com oluşturulmalı';
  end if;

  insert into public.profiles (id, display_name)
  values (demo_user, 'Rota Demo')
  on conflict (id) do update set display_name = excluded.display_name;

  select id into demo_team from public.teams where name = 'Medya Ofisi Demo' and created_by = demo_user;
  if demo_team is null then
    insert into public.teams (name, created_by) values ('Medya Ofisi Demo', demo_user) returning id into demo_team;
  end if;
  insert into public.team_members (team_id, user_id, role) values (demo_team, demo_user, 'lead')
  on conflict (team_id, user_id) do update set role = 'lead';

  insert into public.weekly_blocks (user_id, team_id, title, block_type, weekday, start_time, end_time)
  select demo_user, demo_team, item.title, item.block_type, item.weekday, item.start_time, item.end_time
  from (values
    ('Yazılım Mühendisliği', 'lesson', 0, time '09:00', time '11:00'),
    ('Otobüs · gidiş', 'bus', 0, time '08:15', time '09:00'),
    ('Otobüs · dönüş', 'bus', 0, time '11:00', time '11:45'),
    ('Veri Tabanı', 'lesson', 2, time '10:00', time '12:00'),
    ('Otobüs · gidiş', 'bus', 2, time '09:15', time '10:00'),
    ('Otobüs · dönüş', 'bus', 2, time '12:00', time '12:45')
  ) as item(title, block_type, weekday, start_time, end_time)
  where not exists (
    select 1 from public.weekly_blocks b
    where b.user_id = demo_user and b.title = item.title and b.weekday = item.weekday and b.start_time = item.start_time
  );

  insert into public.tasks (created_by, assigned_to, team_id, title, duration_minutes, due_date, recurrence_weekday, status)
  select demo_user, demo_user, item.team_id, item.title, item.duration_minutes, item.due_date, item.recurrence_weekday, 'open'
  from (values
    (null::uuid, 'API testlerini tamamla', 120, demo_week + 2, null::smallint),
    (demo_team, 'Haftalık medya raporu', 60, demo_week + 4, 4::smallint),
    (null::uuid, 'Veri tabanı dersi tekrarı', 90, demo_week + 3, null::smallint)
  ) as item(team_id, title, duration_minutes, due_date, recurrence_weekday)
  where not exists (select 1 from public.tasks t where t.created_by = demo_user and t.title = item.title and t.due_date = item.due_date);
end;
$$;
