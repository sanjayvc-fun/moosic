from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from ytmusicapi import YTMusic
import requests
import uvicorn
import os
import yt_dlp

app = FastAPI()

# Enable CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize YTMusic
# Note: For full features (library), 'headers.json' or 'oauth.json' is needed.
# For public search/stream, unauthenticated instance works for some features but is limited.
# We try to load auth if available, else standard.
try:
    if os.path.exists("oauth.json"):
        yt = YTMusic("oauth.json")
    else:
        yt = YTMusic()
except Exception as e:
    print(f"Warning: Could not initialize YTMusic with auth: {e}. Using unauthenticated.")
    yt = YTMusic()

@app.get("/")
def home():
    return {"message": "Moosic Backend is Running"}

@app.get("/search")
def search(q: str):
    """
    Search for songs.
    """
    try:
        results = yt.search(q, filter="songs")
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/suggestions")
def suggestions(q: str):
    """
    Get search suggestions.
    """
    try:
        return yt.get_search_suggestions(q)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/recommendations")
def recommendations():
    """
    Get recommendations (Home/Discover).
    """
    try:
        return yt.get_home()
    except Exception as e:
        print(f"Error fetching home: {e}")
        # Fallback for unauthenticated users
        return yt.search("Trending Music", filter="songs")

@app.get("/playlists")
def get_playlists():
    """
    Get user playlists (requires auth).
    """
    try:
        return yt.get_library_playlists()
    except Exception as e:
        print(f"Error fetching playlists: {e}")
        return []

@app.get("/moods")
def get_moods():
    """
    Get mood/genre categories.
    """
    try:
        return yt.get_mood_categories()
    except Exception as e:
        print(f"Error fetching moods: {e}")
        return {}

@app.get("/mood_playlists")
def get_mood_playlists(params: str):
    """
    Get playlists for a specific mood category.
    """
    try:
        return yt.get_mood_playlists(params)
    except Exception as e:
        print(f"Error fetching mood playlists: {e}")
        return []

@app.get("/charts")
def get_charts(country: str = None):
    """
    Get latest charts (global or per country).
    """
    try:
        return yt.get_charts(country=country)
    except Exception as e:
        print(f"Error fetching charts: {e}")
        return {}

@app.get("/podcasts")
def get_podcasts(q: str = "Podcasts"):
    """
    Search for podcasts or get trending ones.
    """
    try:
        # Search is robust for discovery
        return yt.search(q, filter="podcasts")
    except Exception as e:
        print(f"Error fetching podcasts: {e}")
        return []

@app.get("/stream/{video_id}")
async def stream_audio(video_id: str):
    """
    Get the direct streaming URL for a video and proxy it.
    Uses yt-dlp as a fallback for robust extraction.
    """
    try:
        # Try ytmusicapi first
        song = yt.get_song(video_id)
        streaming_data = song.get('streamingData', {})
        formats = streaming_data.get('adaptiveFormats', [])
        
        if not formats:
             formats = streaming_data.get('formats', [])

        # Filter for audio only formats that have a direct URL
        # We prefer those with 'audioQuality' but take any audio/ mimeType
        audio_formats = [f for f in formats if ('audioQuality' in f or f.get('mimeType', '').startswith('audio/')) and 'url' in f]
        
        stream_url = None
        best_audio = None

        if audio_formats:
            def get_priority(f):
                itag = str(f.get('itag', ''))
                if itag == '141': return 100
                if itag == '251': return 90
                if itag == '140': return 80
                return 10 + (f.get('bitrate', 0) // 1000)

            best_audio = sorted(audio_formats, key=get_priority, reverse=True)[0]
            stream_url = best_audio.get('url')
        
        # Fallback to yt-dlp if ytmusicapi fails or provides no URL
        if not stream_url:
            print(f"ytmusicapi failed for {video_id}. Falling back to yt-dlp...")
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                try:
                    info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
                    if 'url' in info:
                        stream_url = info['url']
                    elif 'formats' in info:
                        # Find best audio format
                        audio_only = [f for f in info['formats'] if f.get('acodec') != 'none' and f.get('vcodec') == 'none']
                        if not audio_only:
                            audio_only = info['formats']
                        
                        best = sorted(audio_only, key=lambda x: x.get('abr', 0) or x.get('tbr', 0), reverse=True)[0]
                        stream_url = best['url']
                        print(f"yt-dlp extracted best format: {best.get('format_id')} at {best.get('abr')} kbps")
                    
                    if stream_url:
                        print(f"yt-dlp successfully extracted URL for {video_id}")
                except Exception as ydl_err:
                    print(f"yt-dlp failed too: {ydl_err}")

        if not stream_url:
            raise HTTPException(status_code=404, detail="No audio streams found")

        # Proxy the stream
        def iterfile():
            try:
                # Mimic a browser to avoid throttling
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    'Connection': 'keep-alive'
                }
                with requests.get(stream_url, stream=True, timeout=15, allow_redirects=True, headers=headers) as r:
                    r.raise_for_status()
                    for chunk in r.iter_content(chunk_size=131072): # 128KB - better balance
                        yield chunk
            except Exception as e:
                print(f"Proxy error for {video_id}: {e}")

        media_type = "audio/mpeg"
        if best_audio:
            media_type = best_audio.get('mimeType', 'audio/mpeg').split(';')[0]
        
        return StreamingResponse(iterfile(), media_type=media_type)

    except Exception as e:
        print(f"Error streaming {video_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
