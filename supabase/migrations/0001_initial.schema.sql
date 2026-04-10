-- language: postgresql

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension
if
  not exists "pgcrypto";


  -- ============================================================
  -- 1. profiles
  -- ============================================================
  create table profiles (
    id uuid primary key references auth.users(id)
    on delete cascade
    , email text unique not null
    , full_name text
    , role text not null default 'student' check (role in ('student', 'teacher', 'admin'))
    , is_active boolean not null default true
    , created_at timestamptz not null default now()
    , updated_at timestamptz not null default now()
  );

  -- Automatically create profile when a new user registers
  create or replace function handle_new_user()
  returns trigger as $ $
  begin
    insert into
      profiles (id, email, full_name)
    values
      (
        new.id
        , new.email
        , new.raw_user_meta_data - > > 'full_name'
      );
    return
    new;
  end;
  $ $
  language plpgsql
  security definer;

  create trigger on_auth_user_created
  after insert
  on auth.users
  for each row execute function handle_new_user();

  -- Automatically maintain updated_at
  create or replace function set_updated_at()
  returns trigger as $ $
  begin
    new.updated_at = now();
    return
    new;
  end;
  $ $
  language plpgsql;

  create trigger profiles_updated_at
  before update
  on profiles
  for each row execute function set_updated_at();


  -- ============================================================
  -- 2. teacher_profile
  -- ============================================================
  create table teacher_profile (
    id uuid primary key default gen_random_uuid()
    , profile_id uuid unique not null references profiles(id)
    on delete cascade
    , bio text
    , headline text
    , social_links jsonb not null default '{}': :jsonb
    , updated_at timestamptz not null default now()
  );

  create trigger teacher_profile_updated_at
  before update
  on teacher_profile
  for each row execute function set_updated_at();


  -- ============================================================
  -- 3. course_types
  -- ============================================================
  create table course_types (
    id uuid primary key default gen_random_uuid()
    , title text not null
    , description text
    , duration_min integer not null check (duration_min > 0)
    , price_cents integer not null default 0 check (price_cents >= 0)
    , currency text not null default 'AUD'
    , is_active boolean not null default true
    , created_at timestamptz not null default now()
  );

  -- price_cents stores integer cents (e.g., AUD 75.00 → 7500) to avoid floating point precision issues
  -- Divide by 100 when displaying on the frontend


  -- ============================================================
  -- 4. time_slots
  -- ============================================================
  create table time_slots (
    id uuid primary key default gen_random_uuid()
    , course_type_id uuid references course_types(id)
    on delete set null
    , start_time timestamptz not null
    , end_time timestamptz not null
    , status text not null default 'available' check (
      status in ('available', 'reserved', 'booked', 'cancelled')
    )
    , timezone text not null default 'Australia/Melbourne'
    , is_recurring boolean not null default false
    , recurrence_rule text
    , created_at timestamptz not null default now()
    , constraint valid_duration check (end_time > start_time)
    , constraint no_overlap unique (start_time, end_time)
  );


  -- ============================================================
  -- 5. bookings
  -- ============================================================
  create table bookings (
    id uuid primary key default gen_random_uuid()
    , slot_id uuid not null references time_slots(id)
    on delete restrict
    , student_id uuid not null references profiles(id)
    on delete restrict
    , status text not null default 'pending' check (
      status in ('pending', 'confirmed', 'cancelled', 'completed')
    )
    , notes text
    , created_at timestamptz not null default now()
    , updated_at timestamptz not null default now()
    , constraint one_active_booking_per_slot unique (slot_id)
  );

  -- Automatically maintain updated_at
  create trigger bookings_updated_at
  before update
  on bookings
  for each row execute function set_updated_at();

  -- Automatically release slot when booking is cancelled
  create or replace function release_slot_on_cancel()
  returns trigger as $ $
  begin
    if
      new.status = 'cancelled'
      and
      old.status != 'cancelled'
    then
      update
        time_slots
      set status = 'available'
      where
        id = new.slot_id;
    end if;
    return
    new;
  end;
  $ $
  language plpgsql
  security definer;

  create trigger on_booking_cancelled
  after update
  on bookings
  for each row execute function release_slot_on_cancel();

  -- Lock slot when booking is confirmed
  create or replace function lock_slot_on_confirm()
  returns trigger as $ $
  begin
    if
      new.status = 'confirmed'
      and
      old.status = 'pending'
    then
      update
        time_slots
      set status = 'booked'
      where
        id = new.slot_id;
    end if;
    return
    new;
  end;
  $ $
  language plpgsql
  security definer;

  create trigger on_booking_confirmed
  after update
  on bookings
  for each row execute function lock_slot_on_confirm();


  -- ============================================================
  -- 6. cancellations
  -- ============================================================
  create table cancellations (
    id uuid primary key default gen_random_uuid()
    , booking_id uuid not null references bookings(id)
    on delete cascade
    , cancelled_by uuid not null references profiles(id)
    , cancelled_by_role text not null check (cancelled_by_role in ('student', 'teacher', 'admin'))
    , reason text
    , cancelled_at timestamptz not null default now()
  );

  -- Automatically update booking.status to cancelled when a cancellation record is inserted
  create or replace function sync_booking_on_cancel()
  returns trigger as $ $
  begin
    update
      bookings
    set status = 'cancelled', updated_at = now()
    where
      id = new.booking_id;
    return
    new;
  end;
  $ $
  language plpgsql
  security definer;

  create trigger on_cancellation_created
  after insert
  on cancellations
  for each row execute function sync_booking_on_cancel();


  -- ============================================================
  -- 7. booking_status_history
  -- ============================================================
  create table booking_status_history (
    id uuid primary key default gen_random_uuid()
    , booking_id uuid not null references bookings(id)
    on delete cascade
    , changed_by uuid references profiles(id)
    on delete set null
    , old_status text
    , new_status text not null
    , changed_by_role text check (
      changed_by_role in ('student', 'teacher', 'admin', 'system')
    )
    , note text
    , changed_at timestamptz not null default now()
  );

  -- Automatically log history whenever booking status changes
  create or replace function log_booking_status_change()
  returns trigger as $ $
  begin
    if
      old.status is distinct from
      new.status
    then
      insert into
        booking_status_history (booking_id, old_status, new_status)
      values
        (
          new.id
          , old.status
          , new.status
        );
    end if;
    return
    new;
  end;
  $ $
  language plpgsql
  security definer;

  create trigger booking_status_changed
  after update
  on bookings
  for each row execute function log_booking_status_change();


  -- ============================================================
  -- 8. email_notifications
  -- ============================================================
  create table email_notifications (
    id uuid primary key default gen_random_uuid()
    , booking_id uuid references bookings(id)
    on delete set null
    , recipient_id uuid references profiles(id)
    on delete set null
    , type text not null check (
      type in (
        'booking_pending'
        , 'booking_confirmed'
        , 'booking_cancelled'
        , 'booking_reminder_24h'
        , 'booking_completed'
      )
    )
    , status text not null default 'pending' check (status in ('pending', 'sent', 'failed'))
    , subject text
    , resend_message_id text
    , sent_at timestamptz
    , created_at timestamptz not null default now()
  );


  -- ============================================================
  -- 9. admin_audit_log
  -- ============================================================
  create table admin_audit_log (
    id uuid primary key default gen_random_uuid()
    , admin_id uuid references profiles(id)
    on delete set null
    , action text not null
    , target_table text not null
    , target_id uuid
    , diff jsonb
    , performed_at timestamptz not null default now()
  );


  -- ============================================================
  -- RLS
  -- ============================================================
  alter table profiles
  enable row level
  security;
  alter table teacher_profile
  enable row level
  security;
  alter table course_types
  enable row level
  security;
  alter table time_slots
  enable row level
  security;
  alter table bookings
  enable row level
  security;
  alter table cancellations
  enable row level
  security;
  alter table booking_status_history
  enable row level
  security;
  alter table email_notifications
  enable row level
  security;
  alter table admin_audit_log
  enable row level
  security;

  -- helper
  create or replace function is_admin()
  returns boolean as $ $
  select
    exists (
      select
        1
      from
        profiles
      where
        id = auth.uid()
        and role = 'admin'
    );
  $ $
  language sql
  security definer stable;

  create or replace function is_teacher()
  returns boolean as $ $
  select
    exists (
      select
        1
      from
        profiles
      where
        id = auth.uid()
        and role = 'teacher'
    );
  $ $
  language sql
  security definer stable;

  -- profiles
  create policy "own profile"
  on profiles
  for
  select
  using (auth.uid() = id);
  create policy "own profile update"
  on profiles
  for update
  using (auth.uid() = id);
  create policy "admin read profiles"
  on profiles
  for
  select
  using (is_admin());
  create policy "admin update profiles"
  on profiles
  for update
  using (is_admin());

  -- teacher_profile (publicly readable)
  create policy "public read teacher"
  on teacher_profile
  for
  select
  using (true);
  create policy "teacher update own"
  on teacher_profile
  for update
  using (
    profile_id = auth.uid()
    and is_teacher()
  );
  create policy "admin update teacher"
  on teacher_profile
  for update
  using (is_admin());

  -- course_types (publicly readable, manageable by teacher/admin)
  create policy "public read courses"
  on course_types
  for
  select
  using (true);
  create policy "teacher manage courses"
  on course_types
  for all
  using (is_teacher());
  create policy "admin update courses"
  on course_types
  for update
  using (is_admin());

  -- time_slots (available slots are publicly readable)
  create policy "public read slots"
  on time_slots
  for
  select
  using (status = 'available');
  create policy "auth read all slots"
  on time_slots
  for
  select
  using (auth.role() = 'authenticated');
  create policy "teacher manage slots"
  on time_slots
  for all
  using (is_teacher());
  create policy "admin update slots"
  on time_slots
  for update
  using (is_admin())
  with check (
    start_time = (
      select
        start_time
      from
        time_slots ts
      where
        ts.id = time_slots.id
    )
    and end_time = (
      select
        end_time
      from
        time_slots ts
      where
        ts.id = time_slots.id
    )
  );

  -- bookings
  create policy "student own bookings"
  on bookings
  for
  select
  using (student_id = auth.uid());
  create policy "student insert booking"
  on bookings
  for insert
  with check (student_id = auth.uid());
  create policy "teacher read bookings"
  on bookings
  for
  select
  using (is_teacher());
  create policy "teacher update booking"
  on bookings
  for update
  using (is_teacher());
  create policy "admin read bookings"
  on bookings
  for
  select
  using (is_admin());
  create policy "admin cancel booking"
  on bookings
  for update
  using (is_admin())
  with check (status = 'cancelled');

  -- cancellations
  create policy "student own cancel"
  on cancellations
  for
  select
  using (cancelled_by = auth.uid());
  create policy "student insert cancel"
  on cancellations
  for insert
  with check (cancelled_by = auth.uid());
  create policy "teacher cancel"
  on cancellations
  for all
  using (is_teacher());
  create policy "admin read cancel"
  on cancellations
  for
  select
  using (is_admin());

  -- booking_status_history
  create policy "student read own history"
  on booking_status_history
  for
  select
  using (
    exists (
      select
        1
      from
        bookings
      where
        id = booking_id
        and student_id = auth.uid()
    )
  );
  create policy "teacher read history"
  on booking_status_history
  for
  select
  using (is_teacher());
  create policy "admin read history"
  on booking_status_history
  for
  select
  using (is_admin());

  -- email_notifications
  create policy "own notifications"
  on email_notifications
  for
  select
  using (recipient_id = auth.uid());
  create policy "admin read notifications"
  on email_notifications
  for
  select
  using (is_admin());

  -- admin_audit_log (read-only, insert handled by security definer triggers)
  create policy "admin read audit"
  on admin_audit_log
  for
  select
  using (is_admin());