Read this full line by line before implementing it.

**Implementing the unofficial YouTube Music API option** (using ytmusicapi) for full-song streaming in your private 5-user app is possible, but it's in a **legal gray area**. This method scrapes YouTube Music's internal web endpoints to fetch metadata (search, playlists, recommendations) and stream URLs. It **violates YouTube's Terms of Service** (no reverse-engineering or unauthorized clients), so Google can block accounts/IPs at any time. For private use only (your 5 users), the risk is low, but it's not 100% legal or safe long-term.

### Step-by-Step Implementation (Using Python Backend + Your Custom UI)
This assumes a simple backend (e.g., Flask/FastAPI) that your frontend talks to. It handles authentication once per user and streams audio directly from YouTube (no re-encoding, low server load).

1. **Install the Library** (Python 3.8+ recommended)
   ```
   pip install ytmusicapi
   ```

2. **Authenticate (One-Time Setup per User)**
   - Run this script to get an `oauth.json` or `headers.json` file:
     ```python
     from ytmusicapi import setup_oauth

     setup_oauth()  # Follow instructions: Open browser, log in to YouTube Music, copy headers
     ```
     - For multiple users: Each of your 5 users needs their own auth file (or share one if it's just family/friends — but Google may flag multi-device use).
     - Save files securely (e.g., `user1_oauth.json`).

3. **Backend Server (Example with FastAPI)**
   Create a simple API that your app calls for search, playlists, and streaming.

   ```python
   # app.py (FastAPI backend)
   from fastapi import FastAPI, HTTPException, Request
   from fastapi.responses import StreamingResponse
   from ytmusicapi import YTMusic
   import uvicorn

   app = FastAPI()

   # Load auth for a user (in production, use per-user sessions or API keys)
   yt = YTMusic("user1_oauth.json")  # or headers_auth.json

   @app.get("/search")
   async def search(q: str):
       results = yt.search(q, filter="songs")
       return results

   @app.get("/stream/{video_id}")
   async def stream(video_id: str):
       # Get stream URL (highest quality audio)
       stream_url = yt.get_stream_url(video_id)  # This is the magic part!
       if not stream_url:
           raise HTTPException(status_code=404, detail="Stream not found")

       # Proxy the stream (to avoid CORS issues in browser)
       def iter_stream():
           import requests
           r = requests.get(stream_url, stream=True)
           for chunk in r.iter_content(chunk_size=1024):
               yield chunk

       return StreamingResponse(iter_stream(), media_type="audio/mpeg")

   if __name__ == "__main__":
       uvicorn.run(app, host="0.0.0.0", port=8000)
   ```

   - **Important**: `get_stream_url` is not directly in ytmusicapi — you need to extract it from `yt.get_song(video_id)['streamingData']['adaptiveFormats']` (pick the best audio format like itag 140 or 251).
     - Example helper:
       ```python
       def get_audio_stream_url(video_id):
           song = yt.get_song(video_id)
           formats = song['streamingData']['adaptiveFormats']
           audio_formats = [f for f in formats if 'audioQuality' in f]
           best = sorted(audio_formats, key=lambda x: x['bitrate'], reverse=True)[0]
           return best['url']
       ```

4. **Frontend Integration (Your Custom UI)**
   - In your app (React/Vue/Flutter), call backend:
     - Search: `fetch('/search?q=artist song')` → display results like in your screenshot.
     - Play: `<audio src="/stream/video_id_here" controls />`
   - Handle playlists: Use `yt.get_library_playlists()`, `yt.create_playlist()`, etc.
   - Recommendations: `yt.get_home()` or `yt.get_recommendations()`.

5. **Limitations & Fixes**
   - **Auth expires**: Refresh OAuth periodically.
   - **Rate limits**: Google blocks if too many requests — use caching (Redis).
   - **No official recommendations**: Use `yt.get_home()` for "Discover" and "Recommended".
   - **CORS**: Your backend proxies streams.
   - **Multi-user**: Use per-user auth + JWT sessions in backend.

This gives you a Spotify-like experience with YouTube's full catalog (millions of songs) for free, but only for private use.

### Detailed One-Shot Prompt for an AI App Creator (e.g., Cursor, Claude, GPT-4o, Replit Agent)
Use this prompt to generate the full app code in one go (works best with tools that handle large outputs). Copy-paste it directly.

```
You are an expert full-stack developer building a private, self-hosted music streaming web app similar to YouTube Music / Spotify for 5 personal users only.

The app must have this exact UI layout given in the image(mobile-first, responsive):
- Dark theme with yellow accents (#FFD700)
- Three main screens:
  1. Discover tab: Large yellow card with "Discover" title, "Your Playlist" section with play button, trap genre card example.
  2. Now Playing screen: Back arrow, artist image (e.g., person in beanie), song title "Where This Flower Blooms", album art, progress bar (yellow waveform), play/pause/skip buttons at bottom, mini player bar.
  3. Recommended tab: Search bar at top, "Recommended For You Today" section with cards, "New Collection" with album grids.

Features:
- Use unofficial YouTube Music API via ytmusicapi (Python backend) to search songs, get recommendations, playlists, and stream full audio.
- Backend: FastAPI server with endpoints: /search, /recommendations, /stream/{videoId}, /playlists
- Authentication: Simple shared OAuth (or per-user login later)
- Frontend: React (Vite + Tailwind CSS), use HTML5 <audio> with proxy for streams
- No login required (private use)
- Handle search, play/pause, progress bar, queue
- Use adaptive bitrate audio from YouTube

Generate the COMPLETE project structure with all files:
- backend/app.py (FastAPI with ytmusicapi)
- frontend/src/App.jsx
- frontend/src/components/Discover.jsx, NowPlaying.jsx, Recommended.jsx
- package.json, vite.config.js, tailwind.config.js
- Instructions to run (pip install, npm install, auth setup)

Use modern code, error handling, and make it look exactly like the provided UI description (dark background, yellow highlights, cards with shadows).

Start coding now!
```

This prompt will generate a functional prototype. Test locally, then deploy on a cheap VPS or Raspberry Pi.

Let me know if you need tweaks or help running it! 🎵