# Tabi Bingo 旅ビンゴ

A phone-friendly bingo game for a three-person trip to Japan. Each player gets a
fresh 5×5 card every day at midnight Japan time. You stamp a square by logging
proof: a note, a photo, or both. Stamps sync between everyone's phones, and a
running trip standings table tracks squares, bingos and blackouts.

- **App:** static `index.html`, served by GitHub Pages
- **Data:** Supabase (a Postgres database plus photo storage), called with plain `fetch`

## Setup

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor**, paste `supabase/setup.sql`, change the trip code on its
   last line to your own secret, and run it.
3. In **Project Settings → API**, copy the Project URL and the publishable
   (anon) key into `config.js`. Both are safe to publish, because the key can
   only call the trip-code-protected functions.
4. Share `https://<user>.github.io/tabi-bingo/?trip=<your-code>` with the group.
   Each phone remembers the code after the first visit.

On iPhone, open the link in Safari, then choose **Share → Add to Home Screen**
so it opens full-screen like an app.

If `config.js` is left empty, the app runs in offline mode and keeps stamps on
one phone only.

## Changing the tasks

Edit the `TASKS` array in `index.html`. Cards are dealt from the list with a
seed made from the date and the player, so changing the list also reshuffles
the cards for days already played. Stamps already made keep their task text.
