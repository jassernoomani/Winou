# Showing Winou

The real app on your phone, the real backend on the laptop: photos go through YOLO, DINOv2 and
Qdrant live. About five minutes.

## Once

1. Your account exists in the app (sign up on the phone).
2. Fill the map and report your cat lost from your account (3 photos from
   `research/data/own/cat_*/`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\demo.ps1
   python scripts\seed_demo.py seed --me you@example.com --password <your password>
   ```

3. Optional, to show the admin screen: put your email in `ADMIN_EMAILS` in `.env`, then
   `docker compose up -d api`.

## Before each demo (2 minutes)

1. Laptop: `powershell -ExecutionPolicy Bypass -File scripts\demo.ps1`. Wait for "up".
2. Connect the phone, either:
   - **USB cable** (most reliable): the script prints `127.0.0.1`.
   - **Hotspot**: turn on the phone's hotspot, join it from the laptop, run the script again
     and use the address it prints. Interview Wi-Fi often keeps devices apart, a hotspot doesn't.
3. Phone: **Server address** (gear on the sign-in screen, or My activity → ⋮) → type the
   address → **Test** → **Save**.
4. Open the app once: the list should show missing pets.

## The flow

| Show | Say |
|---|---|
| **Home**: missing pets near you | "Owners report a lost pet with a few photos. Positions are moved up to 300 m: the exact address never leaves the server." |
| **Map**: coloured markers, red pulsing ones | "Lost pets, sightings and street animals. Injured animals pulse, and nearby associations get a push." |
| A **stray** (amber): "What became of it?" | "Anyone can say it's still around, helped or gone. Strays fade after 30 days without news." |
| **I saw an animal** | "Camera first: time and GPS come from the phone. From the gallery, they come from the photo's EXIF." |
| Laptop: `python scripts\seed_demo.py sighting` | "A neighbour just posted a photo of a cat 500 m from where mine was lost." |
| Phone: **"Possible match"** push → match screen | "YOLO crops the animal, DINOv2 turns it into a vector, Qdrant finds the closest lost pets within 10 km. 84%: a resemblance, never presented as certain." |
| **That's my pet** → **Message the finder** → write | "Owner and finder talk in the app: no phone numbers or emails." |
| Laptop: `python scripts\seed_demo.py reply` | The answer arrives as a push and in the chat. |
| **I got my pet back** | "Closes the case, takes it off the map, thanks the finder." |
| ⋮ → **Admin** (if you're admin) | "Association requests and reported content: three reports hide it until reviewed." |

Ready for questions: architecture in [the README](../README.md), matching results in
[research/RESULTS.md](../research/RESULTS.md).

## If something goes wrong

| Problem | Fix |
|---|---|
| "Cannot reach the server" | Server address → Test. With USB, rerun `demo.ps1` (it redoes the port forward). |
| Hotspot: Test fails | Allow port 8080 once, in an admin PowerShell: `New-NetFirewallRule -DisplayName 'Winou API' -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Any` |
| No push for the match | Notifications allowed for Winou? The match is in My activity anyway. |
| `sighting` says no lost report | Run `seed` first; or `--pet-name <name>` if your cat isn't called Luna. |

Afterwards: `powershell -ExecutionPolicy Bypass -File scripts\demo.ps1 -Stop`.
