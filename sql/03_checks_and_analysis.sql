set search_path to netflix, public;

select count(*) from stg_movielens_movies;

select count(*) from stg_movielens_ratings;

select min(viewed_at_ts) as min_date, max(viewed_at_ts) as max_date from fact_viewing;



-- =========================================Analysis=======================================


-- ============== Analytics #1: Top titles by hours ==============

with total_hours_per_title as (
select s.title_norm, s.release_year, sum(f.watch_hours_est) as total_watch_hours
from fact_viewing f
join dim_show s
on f.show_id = s.show_id
group by s.title_norm, s.release_year
),
rankings as (
select *, dense_rank() over(order by total_watch_hours desc) as ranking
from total_hours_per_title)
select *
from rankings
where ranking <= 10
order by ranking;


-- ============== Analytics #2: Peak viewing hour per day ==============

with peak_hours as (
select f.view_date_key as date, EXTRACT(HOUR from f.viewed_at_ts) as hours, sum(f.watch_events) as total_viewers
from fact_viewing f
group by view_date_key, EXTRACT(HOUR from f.viewed_at_ts)
), 
rankings as(
select date, hours, total_viewers,
row_number() over(partition by date order by total_viewers desc) as rn
from peak_hours
)
select *
from rankings
where rn = 1
order by date;

-- ============== Analytics #3: Cohort retention (first-watch month) ==============
with first_month as (
select user_id, min(DATE_TRUNC('MONTH', view_date_key))::date as cohort_month
from fact_viewing 
group by 1
), 
active_users as (
select f.cohort_month, DATE_TRUNC('MONTH', view_date_key)::date as activity_month, count(distinct f.user_id) as active_users
from first_month f
join fact_viewing fv on f.user_id = fv.user_id
group by 1,2
),
cohort_size as (
select cohort_month, count(distinct user_id) as users_in_cohort
from first_month
group by cohort_month
)
select a.cohort_month, a.activity_month, active_users, users_in_cohort, EXTRACT(MONTH FROM age(a.activity_month, a.cohort_month))::int AS month_number,ROUND(((active_users*1.0)/users_in_cohort)*100,2) as retention_pct
from active_users as a
join cohort_size c using(cohort_month)
order by 1,2;
