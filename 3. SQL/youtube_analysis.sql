create database youtubeAnalysis;

use youtubeAnalysis;

CREATE TABLE youtube_videos (
    video_id VARCHAR(50),
    views BIGINT,
    likes BIGINT,
    comments BIGINT,
    channel_id VARCHAR(50),
    channel_name VARCHAR(255),
    published_date DATE,
    duration INT,
    category_id INT,
    genre VARCHAR(100),
    subscribers BIGINT,
    engagement_rate DOUBLE,
    saturation_index DOUBLE,
    competition_density DOUBLE,
    roi_potential DOUBLE,
    subscriber_barrier DOUBLE,
    month_of_year VARCHAR(10),
    growth_rate DOUBLE
);

select * from youtube_videos;

CREATE TABLE genre_summary (
    genre VARCHAR(100),
    avg_engagement FLOAT,
    saturation FLOAT,
    competition FLOAT,
    avg_roi_potential FLOAT,
    avg_views BIGINT,
    avg_subscribers BIGINT,
    video_count INT,
    creator_barrier FLOAT,
    business_score FLOAT,
    creator_score FLOAT
);
select * from genre_summary;

-- DATA VALIDATION --
SELECT COUNT(*) FROM youtube_videos;
SELECT COUNT(*) FROM genre_summary;

-- NULL CHECKS

-- Check nulls
SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN genre IS NULL THEN 1 ELSE 0 END) AS null_genre,
  SUM(CASE WHEN roi_potential IS NULL THEN 1 ELSE 0 END) AS null_roi
FROM youtube_videos;

-- negative or zero values
SELECT * FROM youtube_videos
WHERE views < 0 OR likes < 0 OR comments < 0;

-- Top business opportunity genres
SELECT genre, business_score
FROM genre_summary
ORDER BY business_score DESC;

-- Top creator opportunity genres
SELECT genre, creator_score
FROM genre_summary
ORDER BY creator_score DESC;

-- High ROI but low competition
SELECT genre, avg_roi_potential, competition
FROM genre_summary
WHERE avg_roi_potential > (SELECT AVG(avg_roi_potential) FROM genre_summary)
  AND competition < (SELECT AVG(competition) FROM genre_summary);
-

-- Simple aggregation to understand audience approval by genre
SELECT 
    genre,
    COUNT(*) as total_videos,
    ROUND(AVG(likes), 0) as avg_likes,
    ROUND(MIN(likes), 0) as min_likes,
    ROUND(MAX(likes), 0) as max_likes,
    ROUND(STDDEV(likes), 0) as stddev_likes
FROM youtube_videos
GROUP BY genre
ORDER BY avg_likes DESC;

-- Core metric showing market size and audience demand
SELECT 
    genre,
    COUNT(*) as total_videos,
    ROUND(AVG(views), 0) as avg_views,
    ROUND(MIN(views), 0) as min_views,
    ROUND(MAX(views), 0) as max_views,
    ROUND(STDDEV(views), 0) as stddev_views
FROM youtube_videos
GROUP BY genre
ORDER BY avg_views DESC;

-- Verify equal sampling and check competition level
SELECT 
    genre,
    COUNT(*) as total_video_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM youtube_videos), 2) as percentage_of_dataset,
    COUNT(DISTINCT channel_id) as unique_channels,
    ROUND(COUNT(*) / COUNT(DISTINCT channel_id), 2) as avg_videos_per_channel
FROM youtube_videos
GROUP BY genre
ORDER BY total_video_count DESC;


			
-- Comprehensive opportunity score combining multiple factors
WITH genre_aggregates AS (
    SELECT 
        genre,
        AVG(views) as avg_views,
        AVG(engagement_rate) as avg_engagement,
        AVG(roi_potential) as avg_roi,
        AVG(competition_density) as avg_competition,
        AVG(saturation_index) as avg_saturation,
        COUNT(*) as video_count
    FROM youtube_videos
    GROUP BY genre
)
SELECT 
    genre,
    ROUND(avg_views, 0) as avg_views,
    ROUND(avg_engagement, 2) as avg_engagement,
    ROUND(avg_roi, 2) as avg_roi,
    ROUND(avg_competition, 2) as avg_competition,
    ROUND(avg_saturation, 2) as avg_saturation,
    -- Opportunity Index Formula: (avg_views / competition_density) / saturation_index
    ROUND(
        (avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0),
        2
    ) as opportunity_index,
    -- Rank genres by opportunity
    RANK() OVER (ORDER BY (avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0) DESC) as opportunity_rank,
    -- Interpretation
    CASE 
        WHEN (avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0) > 
             (SELECT AVG((avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0)) FROM genre_aggregates) * 1.5
        THEN 'Excellent Opportunity'
        WHEN (avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0) > 
             (SELECT AVG((avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0)) FROM genre_aggregates)
        THEN 'Good Opportunity'
        WHEN (avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0) > 
             (SELECT AVG((avg_views / NULLIF(avg_competition, 0)) / NULLIF(avg_saturation, 0)) FROM genre_aggregates) * 0.5
        THEN 'Moderate Opportunity'
        ELSE 'Limited Opportunity'
    END as opportunity_category
FROM genre_aggregates
ORDER BY opportunity_index DESC;


-- Comprehensive genre summary with all key metrics
CREATE TABLE genre_master_summary AS
SELECT 
    genre,
    
    -- Basic Stats
    COUNT(*) as total_videos,
    COUNT(DISTINCT channel_id) as unique_channels,
    
    -- View Metrics
    ROUND(AVG(views), 0) as avg_views,
    ROUND(MAX(views), 0) as max_views,
    
    -- Engagement Metrics
    ROUND(AVG(likes), 0) as avg_likes,
    ROUND(AVG(comments), 0) as avg_comments,
    ROUND(AVG(engagement_rate), 3) as avg_engagement_rate,
    
    -- Competition Metrics
    ROUND(AVG(subscribers), 0) as avg_subscriber_barrier,
    ROUND(AVG(saturation_index), 2) as saturation_index,
    ROUND(AVG(competition_density), 2) as competition_density,
    
    -- Opportunity Metrics
    ROUND(AVG(roi_potential), 2) as avg_roi_potential,
    ROUND(
        (AVG(views) / NULLIF(AVG(competition_density), 0)) / NULLIF(AVG(saturation_index), 0),
        2
    ) as opportunity_index
    
FROM youtube_videos
GROUP BY genre;

-- Query the table
SELECT * FROM genre_master_summary ORDER BY avg_roi_potential DESC;

-- Monthly performance trends
CREATE TABLE monthly_genre_performance AS
SELECT 
    genre,
    DATE_FORMAT(published_date, '%Y-%m-01') as month,
    COUNT(*) as videos_uploaded,
    ROUND(AVG(views), 0) as avg_views,
    ROUND(AVG(engagement_rate), 3) as avg_engagement,
    ROUND(AVG(roi_potential), 2) as avg_roi,
    COUNT(DISTINCT channel_id) as active_channels
FROM youtube_videos
WHERE published_date IS NOT NULL
GROUP BY genre, DATE_FORMAT(published_date, '%Y-%m-01')
ORDER BY genre, month;

-- Query
SELECT * FROM monthly_genre_performance ORDER BY genre, month DESC;

-- Performance by channel size tier
CREATE TABLE channel_tier_performance AS
SELECT 
    genre,
    CASE 
        WHEN subscribers < 10000 THEN 'Micro (<10K)'
        WHEN subscribers < 100000 THEN 'Small (10K-100K)'
        WHEN subscribers < 1000000 THEN 'Medium (100K-1M)'
        ELSE 'Large (>1M)'
    END as channel_tier,
    COUNT(*) as video_count,
    ROUND(AVG(views), 0) as avg_views,
    ROUND(AVG(engagement_rate), 3) as avg_engagement,
    ROUND(AVG(roi_potential), 2) as avg_roi
FROM youtube_videos
GROUP BY genre, channel_tier
ORDER BY genre, 
    CASE channel_tier
        WHEN 'Micro (<10K)' THEN 1
        WHEN 'Small (10K-100K)' THEN 2
        WHEN 'Medium (100K-1M)' THEN 3
        ELSE 4
    END;

-- Query
SELECT * FROM channel_tier_performance;

-- Final recommendation table with both scores
CREATE TABLE genre_recommendation_scores AS
WITH max_values AS (
    SELECT 
        MAX(avg_roi) as max_roi,
        MAX(avg_views) as max_views,
        MAX(avg_engagement) as max_engagement
    FROM (
        SELECT 
            genre,
            AVG(roi_potential) as avg_roi,
            AVG(views) as avg_views,
            AVG(engagement_rate) as avg_engagement
        FROM youtube_videos
        GROUP BY genre
    ) x
),
genre_stats AS (
    SELECT 
        genre,
        AVG(roi_potential) as avg_roi,
        AVG(views) as avg_views,
        AVG(engagement_rate) as avg_engagement,
        AVG(subscribers) as creator_barrier
    FROM youtube_videos
    GROUP BY genre
)
SELECT 
    gs.genre,
    ROUND(gs.avg_roi, 2) as avg_roi,
    ROUND(gs.avg_views, 0) as avg_views,
    ROUND(gs.avg_engagement, 2) as avg_engagement,
    ROUND(gs.creator_barrier, 0) as creator_barrier,
    
    -- Business Score
    ROUND(
        (gs.avg_roi / mv.max_roi * 50) +
        (gs.avg_views / mv.max_views * 30) +
        (gs.avg_engagement / mv.max_engagement * 20),
        2
    ) as business_score,
    
    -- Creator Score
    ROUND(
        (gs.avg_roi / mv.max_roi * 40) +
        ((1.0 / NULLIF(gs.creator_barrier, 0)) * 1000000 * 40) +
        (gs.avg_engagement / mv.max_engagement * 20),
        2
    ) as creator_score
    
FROM genre_stats gs
CROSS JOIN max_values mv;

-- Query
SELECT * FROM genre_recommendation_scores 
ORDER BY business_score DESC, creator_score DESC;

-- 1. Main dataset
SELECT * FROM youtube_videos;

-- 2. Master summary
SELECT * FROM genre_master_summary;

-- 3. Monthly trends
SELECT * FROM monthly_genre_performance;

-- 4. Channel tiers
SELECT * FROM channel_tier_performance;

-- 5. Final scores
SELECT * FROM genre_recommendation_scores;

