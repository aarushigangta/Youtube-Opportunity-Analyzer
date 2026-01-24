

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import pandas as pd
import isodate
import time
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()


# CONFIGURATION

API_KEY = os.getenv('YOUTUBE_API_KEY')

TARGET_PER_GENRE = 1000


# Genre definitions with search keywords
GENRES = {
    'Technology': 'technology tech',
    'Gaming': 'gaming game',
    'Education': 'education tutorial',
    'Finance': 'finance investing',
    'Fitness': 'fitness workout',
    'Entertainment': 'entertainment comedy',
    'Beauty': 'beauty makeup',
    'Vlogs': 'vlog lifestyle'
}


START_DATE = '2015-01-01T00:00:00Z'

# FUNCTIONS

def search_videos(youtube, genre_name, search_query, max_results):
    """
    Search for videos in a specific genre.
    
    Args:
        youtube: YouTube API client
        genre_name: Name of the genre
        search_query: Keywords to search for
        max_results: Number of videos to find
    
    Returns:
        List of video IDs
    """
    print(f"Searching {genre_name}...", end=" ")
    
    video_ids = []
    next_page_token = None
    
    while len(video_ids) < max_results:
        try:
            request = youtube.search().list(
                part='id',
                type='video',
                q=search_query,
                maxResults=min(50, max_results - len(video_ids)),
                order='viewCount',
                pageToken=next_page_token,
                publishedAfter=START_DATE,
                relevanceLanguage='en'
            )
            
            response = request.execute()
            
            for item in response['items']:
                if item['id']['kind'] == 'youtube#video':
                    video_ids.append(item['id']['videoId'])
            
            next_page_token = response.get('nextPageToken')
            if not next_page_token:
                break
            
            time.sleep(0.5)
        
        except HttpError as e:
            print(f"Error: {e}")
            break
    
    print(f"Found {len(video_ids)} videos")
    return video_ids


def get_video_details(youtube, video_ids, genre_name):
    """
    Get detailed information for videos.
    
    Args:
        youtube: YouTube API client
        video_ids: List of video IDs
        genre_name: Genre to assign
    
    Returns:
        List of dictionaries with video data
    """
    print(f"Fetching details...", end=" ")
    
    all_video_data = []
    
    for i in range(0, len(video_ids), 50):
        batch_ids = video_ids[i:i+50]
        
        try:
            request = youtube.videos().list(
                part='snippet,statistics,contentDetails',
                id=','.join(batch_ids)
            )
            
            response = request.execute()
            
            for video in response['items']:
                snippet = video['snippet']
                stats = video.get('statistics', {})
                content = video['contentDetails']
                
                duration_seconds = int(
                    isodate.parse_duration(content['duration']).total_seconds()
                )
                
                video_data = {
                    'video_id': video['id'],
                    'genre': genre_name,
                    'channel_id': snippet['channelId'],
                    'channel_name': snippet['channelTitle'],
                    'title': snippet['title'],
                    'date': snippet['publishedAt'],
                    'views': int(stats.get('viewCount', 0)),
                    'likes': int(stats.get('likeCount', 0)),
                    'comments': int(stats.get('commentCount', 0)),
                    'duration': duration_seconds
                }
                
                all_video_data.append(video_data)
            
            time.sleep(0.3)
        
        except HttpError as e:
            print(f"Error: {e}")
            continue
    
    print(f"Done ({len(all_video_data)} videos)")
    return all_video_data


def get_channel_subscribers(youtube, channel_ids):
    """
    Get subscriber counts for channels.
    
    Args:
        youtube: YouTube API client
        channel_ids: List of channel IDs
    
    Returns:
        Dictionary mapping channel_id to subscriber_count
    """
    print(f"Fetching subscriber data for {len(channel_ids)} channels...", end=" ")
    
    subscriber_data = {}
    
    for i in range(0, len(channel_ids), 50):
        batch_ids = channel_ids[i:i+50]
        
        try:
            request = youtube.channels().list(
                part='statistics',
                id=','.join(batch_ids)
            )
            
            response = request.execute()
            
            for channel in response['items']:
                channel_id = channel['id']
                subscriber_count = int(
                    channel.get('statistics', {}).get('subscriberCount', 0)
                )
                subscriber_data[channel_id] = subscriber_count
            
            time.sleep(0.2)
        
        except HttpError:
            continue
    
    print("Done")
    return subscriber_data


def collect_youtube_data():
    """
    Main data collection function.
    
    Returns:
        pandas DataFrame with collected data
    """
    print(f"\nYouTube Data Collection Started")
    print(f"Target: {TARGET_PER_GENRE} videos × {len(GENRES)} genres = {TARGET_PER_GENRE * len(GENRES)} total\n")
    
    youtube = build('youtube', 'v3', developerKey=API_KEY)
    
    all_videos = []
    
    for idx, (genre_name, search_query) in enumerate(GENRES.items(), 1):
        print(f"[{idx}/{len(GENRES)}] {genre_name}: ", end="")
        
        video_ids = search_videos(youtube, genre_name, search_query, TARGET_PER_GENRE)
        
        if not video_ids:
            print("No videos found, skipping")
            continue
        
        video_data = get_video_details(youtube, video_ids, genre_name)
        all_videos.extend(video_data)
        
        time.sleep(1)
    
    print(f"\nProcessing data...")
    
    df = pd.DataFrame(all_videos)
    unique_channels = df['channel_id'].unique().tolist()
    
    subscriber_data = get_channel_subscribers(youtube, unique_channels)
    
    df['subscribers'] = df['channel_id'].map(subscriber_data)
    df['date'] = pd.to_datetime(df['date'])
    
    return df


def save_data(df):
    """
    Save DataFrame to CSV.
    
    Args:
        df: DataFrame to save
    
    Returns:
        Filename
    """
    if not os.path.exists('data'):
        os.makedirs('data')
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f'data/youtube_data_{timestamp}.csv'
    
    df.to_csv(filename, index=False)
    
    return filename



# MAIN EXECUTION


def main():
    """Main execution."""
    
    # Check API key
    if not API_KEY:
        print("\n❌ ERROR: API Key not found!")
        print("Please create a .env file with: YOUTUBE_API_KEY=your_key_here")
        return
    
    try:
        start_time = time.time()
        
        # Collect data
        df = collect_youtube_data()
        
        
        filename = save_data(df)
        duration = time.time() - start_time
        
        print(f"\n{'='*60}")
        print(f"✅ Collection Complete!")
        print(f"{'='*60}")
        print(f"Total videos: {len(df)}")
        print(f"Time taken: {duration/60:.1f} minutes")
        print(f"Saved to: {filename}")
        
        print(f"\nVideos per genre:")
        for genre in GENRES.keys():
            count = len(df[df['genre'] == genre])
            print(f"  {genre:<15}: {count:>3} videos")
        
        print(f"\n{'='*60}\n")
    
    except Exception as e:
        print(f"\n❌ Error: {e}")


if __name__ == "__main__":
    main()