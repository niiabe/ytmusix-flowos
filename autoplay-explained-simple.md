# How Auto-Play Works in the Music App

## The Simple Version

When a song finishes, the app asks itself one question:

> **"What should I play next?"**

The answer depends on two things — **your repeat setting** and **whether there are more songs in the queue.**

---

## Step 1 — Song Finishes

The moment a track ends, the app detects it and immediately starts the decision process. This happens automatically in the background — you don't press anything.

---

## Step 2 — Check the Repeat Mode

```
Song ends
    │
    ▼
What is my repeat setting?
    │
    ├── 🔂 Repeat This Song  →  Restart the same song from 0:00
    │
    ├── 🔁 Repeat All        →  Play the next song.
    │                            If it was the last song, go back to the first one.
    │
    └── ➡️  No Repeat         →  Check if there's a next song in the queue...
```

---

## Step 3 — No Repeat: Is There a Next Song?

```
No Repeat mode
    │
    ▼
Is there a next song in the queue?
    │
    ├── YES  →  Play it. Done.
    │
    └── NO   →  The queue is empty.
                Go fetch recommendations automatically.
```

---

## Step 4 — Fetching Recommendations (When Queue is Empty)

If there's nothing left to play, the app doesn't just stop. It looks at the **last song you were listening to** and asks YouTube Music:

> *"What should someone listen to after this?"*

YouTube Music sends back a list of suggested songs. The app adds them to your queue and keeps playing without interruption. It feels seamless — like the music just keeps going.

---

## The Full Picture

```
🎵 Song is playing
        │
        ▼
🏁 Song finishes
        │
        ▼
🔂 Repeat One?  ──── YES ──→  🔁 Restart same song
        │
        NO
        │
        ▼
🔁 Repeat All?  ──── YES ──→  ▶️  Play next song
        │                          (or loop back to song #1 if it was the last)
        NO
        │
        ▼
📋 More songs    ── YES ──→  ▶️  Play next song in queue
   in queue?
        │
        NO
        │
        ▼
🤖 Ask YouTube Music for recommendations
        │
        ▼
➕ Add recommendations to queue
        │
        ▼
▶️  Keep playing automatically
```

---

## One Extra Thing — YouTube Links

YouTube music links expire after a few hours. So every time the app is about to play a YouTube song — whether it's the next song in queue or a recommendation — it quietly grabs a **fresh link** right before pressing play. You never notice this happening. It just works.

---

## In Plain English

Think of it like a DJ. When your song ends, the DJ checks:
- *"Did you ask me to loop this one?"* → plays it again
- *"Did you ask me to loop the whole set?"* → goes to the next track, wraps around at the end
- *"Is there anything left on the setlist?"* → plays the next one
- *"The setlist is done — what vibe were we on?"* → pulls similar songs and keeps the night going
