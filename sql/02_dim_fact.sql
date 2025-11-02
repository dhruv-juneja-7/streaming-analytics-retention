show search_path;

set search_path to netflix, public;

CREATE TABLE dim_time(
	date_key DATE PRIMARY KEY,
	yyyy INT,
	mm INT,
	dd INT,
	dow INT,
	week INT,
	quarter INT,
	month_name TEXT
);

INSERT INTO dim_time(date_key, yyyy, mm, dd, dow, week, quarter, month_name)
SELECT d::date,
	EXTRACT (YEAR FROM d)::int,
	EXTRACT (MONTH FROM d)::int,
	EXTRACT (DAY FROM d)::int,
	EXTRACT (DOW FROM d)::int,
	EXTRACT (WEEK FROM d)::int,
	EXTRACT (QUARTER FROM d)::int,
	TO_CHAR(d, 'Mon')
FROM GENERATE_SERIES('1995-01-01'::date, '2035-12-31', interval '1 day') AS g(d)
ON CONFLICT (date_key) DO NOTHING;

CREATE OR REPLACE VIEW v_views_norm as 
SELECT movieid,
COALESCE(NULLIF(REGEXP_REPLACE(raw_title, '\s*\(\d{4}\)$',''),''),raw_title) as title_norm,
case when raw_title ~ '\(\d{4}\)$' 
then REGEXP_REPLACE(raw_title, '.*\((\d{4})\)$','\1')::int
else null end as release_year,
genres
from netflix.stg_movielens_movies;

select * from v_views_norm limit 10;

CREATE TABLE IF NOT EXISTS dim_show(
	show_id integer primary key,
	title_norm text,
	release_year int,
	type text,
	genres text
);

insert into dim_show(show_id, title_norm, release_year, type, genres)
select movieid, title_norm, release_year, 'movie'::text, genres
from v_views_norm
on conflict (showid) do nothing;

CREATE TABLE IF NOT EXISTS dim_user (
  user_id   INTEGER PRIMARY KEY,
  country   TEXT,     -- unknown in ML
  plan      TEXT,     -- n/a
  joined_on DATE      -- n/a
);

INSERT INTO dim_user(user_id, country, plan, joined_on)
SELECT DISTINCT userid, 'unknown', NULL, NULL::date
FROM stg_movielens_ratings
ON CONFLICT (user_id) DO NOTHING;


CREATE TABLE IF NOT EXISTS fact_viewing (
  view_id         BIGSERIAL PRIMARY KEY,
  user_id         INTEGER REFERENCES dim_user(user_id),
  show_id         INTEGER REFERENCES dim_show(show_id),
  viewed_at_ts    TIMESTAMPTZ,
  view_date_key   DATE REFERENCES dim_time(date_key),
  watch_events    INT,              -- count of viewing events
  watch_hours_est NUMERIC(6,2)      -- rough estimate
);

with prepared_data as(
	select r.movieid, r.userid, to_timestamp(r.ts_epoch) at time zone 'utc' as viewed_ts, r.rating
	from stg_movielens_ratings r
	join dim_show s on r.movieid = s.show_id
)
INSERT INTO fact_viewing(user_id, show_id, viewed_at_ts, view_date_key, watch_events, watch_hours_est)
select p.userid,
p.movieid,
p.viewed_ts,
date(p.viewed_ts),
1,
case when p.rating is null then 1.5
when p.rating >= 3.5 then 2.0
when p.rating >= 2.5 then 1.5
else 0.75 end
from prepared_data p;

