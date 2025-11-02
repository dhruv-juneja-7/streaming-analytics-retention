-- Create schema and set search_path
CREATE SCHEMA IF NOT EXISTS netflix;
SET search_path TO netflix, public;

-- =============== STAGING TABLES (MovieLens) ===============

-- movies.csv: movieId,title,genres
CREATE TABLE IF NOT EXISTS stg_movielens_movies (
  movieid   INTEGER PRIMARY KEY,
  raw_title TEXT,
  genres    TEXT
);

-- ratings.csv: userId,movieId,rating,timestamp  (timestamp = UNIX epoch seconds)
-- For initial dev you can use the 1M subset; structure is the same.
CREATE TABLE IF NOT EXISTS stg_movielens_ratings (
  userid   INTEGER,
  movieid  INTEGER,
  rating   NUMERIC(3,1),
  ts_epoch BIGINT
);

