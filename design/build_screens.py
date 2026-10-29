"""Builds design/winou-screens.html: every Winou screen, light and dark, from the Figma style guide.

The page is meant for Figma import (html.to.design plugin), so it is plain static HTML and CSS:
fixed 360x800 frames, Nunito, inline SVG icons, photos embedded.

    python design/build_screens.py
"""
import base64
import io
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent


def photo(name: str, size: tuple[int, int]) -> str:
    """The guide's example photos, shrunk and embedded so the page is one file."""
    im = Image.open(HERE / "img" / name).convert("RGB")
    im.thumbnail(size)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=82)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


# Embedded once as CSS variables; screens refer to them with var(--cat) / var(--dog)
PHOTOS = {"cat": photo("cat.png", (720, 420)), "dog": photo("dog.png", (520, 520))}
CAT, DOG = "__cat__", "__dog__"

# --- Icons: Lucide paths (24 grid, 2px round strokes), as in the guide ---
P = lambda d: f'<path d="{d}"/>'
C = lambda cx, cy, r: f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'
R = lambda x, y, w, h, rx: f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"/>'
ICONS = {
    "camera": P("M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z") + C(12, 13, 3),
    "search": C(11, 11, 8) + P("m21 21-4.3-4.3"),
    "plus": P("M5 12h14") + P("M12 5v14"),
    "check": P("M20 6 9 17l-5-5"),
    "house": P("M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8") + P("M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"),
    "map-pin": P("M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0") + C(12, 10, 3),
    "eye": P("M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0") + C(12, 12, 3),
    "paw": C(11, 4, 2) + C(18, 8, 2) + C(20, 16, 2) + P("M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.045Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"),
    "circle-check": C(12, 12, 10) + P("m9 12 2 2 4-4"),
    "arrow-left": P("m12 19-7-7 7-7") + P("M19 12H5"),
    "chevron-right": P("m9 18 6-6-6-6"),
    "map": P("M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z") + P("M15 5.764v15") + P("M9 3.236v15"),
    "message": P("M7.9 20A9 9 0 1 0 4 16.1L2 22Z"),
    "user": P("M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2") + C(12, 7, 4),
    "clock": C(12, 12, 10) + P("M12 6v6l4 2"),
    "heart": P("M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"),
    "send": P("M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z") + P("m21.854 2.147-10.94 10.939"),
    "megaphone": P("m3 11 18-5v12L3 14v-3z") + P("M11.6 16.8a3 3 0 1 1-5.8-1.6"),
    "sliders": P("M21 4h-7") + P("M10 4H3") + P("M21 12h-9") + P("M8 12H3") + P("M21 20h-5") + P("M12 20H3") + P("M14 2v4") + P("M8 10v4") + P("M16 18v4"),
    "locate": P("M2 12h3") + P("M19 12h3") + P("M12 2v3") + P("M12 19v3") + C(12, 12, 7) + C(12, 12, 3),
    "log-out": P("M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4") + P("m16 17 5-5-5-5") + P("M21 12H9"),
    "x": P("M18 6 6 18") + P("m6 6 12 12"),
    "lightbulb": P("M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5") + P("M9 18h6") + P("M10 22h4"),
    "mail": R(2, 4, 20, 16, 2) + P("m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"),
    "lock": R(3, 11, 18, 11, 2) + P("M7 11V7a5 5 0 0 1 10 0v4"),
    "image": R(3, 3, 18, 18, 2) + C(9, 9, 2) + P("m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"),
    "globe": C(12, 12, 10) + P("M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20") + P("M2 12h20"),
    "navigation": P("M3 11 22 2 13 21 11 13 3 11z"),
    "notes": P("M15 12H3") + P("M17 18H3") + P("M21 6H3"),
    "more": C(12, 12, 1) + C(12, 5, 1) + C(12, 19, 1),
    "heart-pulse": P("M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z") + P("M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"),
    "calendar": R(3, 4, 18, 18, 2) + P("M16 2v4") + P("M8 2v4") + P("M3 10h18"),
    "wave": P("M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2") + P("M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2") + P("M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8") + P("M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"),
    "cloud-off": P("m2 2 20 20") + P("M5.782 5.782A7 7 0 0 0 9 19h8.5a4.5 4.5 0 0 0 1.307-.193") + P("M21.532 16.5A4.5 4.5 0 0 0 17.5 10h-1.79A7.008 7.008 0 0 0 10 5.07"),
}


def icon(name: str, size: int = 20, color: str = "currentColor") -> str:
    return (f'<svg class="ic" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</svg>')


# --- Components (one per guide specimen) ---

def status_bar(on_color: bool = False) -> str:
    cls = "status on-color" if on_color else "status"
    return (f'<div class="{cls}"><span>9:41</span><span class="sb-icons">'
            '<i class="sig"></i><i class="sig s2"></i><i class="sig s3"></i><b class="bat"></b></span></div>')


def appbar(title: str, back: bool = True, actions: str = "") -> str:
    b = f'<span class="ib">{icon("arrow-left", 24)}</span>' if back else ""
    return f'<div class="appbar">{b}<span class="ab-title">{title}</span><span class="ab-actions">{actions}</span></div>'


def btn(label: str, ic: str | None = None, kind: str = "filled", extra: str = "") -> str:
    i = icon(ic, 20) if ic else ""
    return f'<div class="btn {kind} {extra}">{i}<span>{label}</span></div>'


def chip(label: str, selected: bool = False, ic: str | None = None, dot: str | None = None) -> str:
    lead = icon("check", 18) if selected and not ic and not dot else (icon(ic, 18) if ic else "")
    if dot:
        lead = f'<i class="dot" style="background:{dot}"></i>'
    return f'<div class="chip {"sel" if selected else ""}">{lead}<span>{label}</span></div>'


def pill(label: str, tone: str, ic: str) -> str:
    return f'<div class="pill {tone}">{icon(ic, 16)}<span>{label}</span></div>'


def fab(label: str, tone: str, ic: str) -> str:
    return f'<div class="fab {tone}"><div class="fab-in">{icon(ic, 20)}<span>{label}</span></div></div>'


def field(label: str, value: str, ic: str | None, state: str = "", placeholder: bool = False, tall: bool = False,
          help: str = "") -> str:
    i = icon(ic, 20) if ic else ""
    v = f'<span class="{"ph" if placeholder else "val"}">{value}</span>'
    caret = '<i class="caret"></i>' if state == "focus" else ""
    h = f'<div class="help">{help}</div>' if help else ""
    return (f'<div class="field"><div class="flabel">{label}</div>'
            f'<div class="fbox {state} {"tall" if tall else ""}">{i}{v}{caret}</div>{h}</div>')


def note(text: str, tone: str, ic: str) -> str:
    return f'<div class="note {tone}">{icon(ic, 20)}<span>{text}</span></div>'


def ring(score: int, size: int = 96) -> str:
    r = size / 2 - size / 24
    circ = 2 * 3.14159 * r
    sw = size / 12
    return (f'<div class="ring" style="width:{size}px;height:{size}px">'
            f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="var(--tonal)" stroke-width="{sw}"/>'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="#3884FF" stroke-width="{sw}" '
            f'stroke-linecap="round" stroke-dasharray="{circ*score/100:.1f} {circ:.1f}" '
            f'transform="rotate(-90 {size/2} {size/2})"/></svg>'
            f'<span style="font-size:{size/4:.0f}px">{score}%</span></div>')


MARKERS = {"lost": ("#F43F5E", "search"), "sighting": ("#3884FF", "eye"), "stray": ("#F59E0B", "paw"), "injured": ("#EF4444", "plus")}


def marker(kind: str, x: int, y: int) -> str:
    color, ic = MARKERS[kind]
    rings = '<i class="pulse p1"></i><i class="pulse p2"></i>' if kind == "injured" else ""
    return (f'<div class="marker" style="left:{x}px;top:{y}px">{rings}'
            f'<div class="mdot" style="background:{color}">{icon(ic, 18, "#111D36")}</div></div>')


def pet_card(name: str, img: str, status: tuple[str, str, str], where: str, when: str, desc: str = "") -> str:
    d = f'<p class="desc">{desc}</p>' if desc else ""
    return (f'<div class="petcard"><div class="pc-photo" style="background-image:url({img})"></div>'
            f'<div class="pc-body"><div class="pc-top"><span class="pc-name">{name}</span>{pill(*status)}</div>'
            f'<div class="meta">{icon("map-pin", 16)}<span>{where}</span></div>'
            f'<div class="meta">{icon("clock", 16)}<span>{when}</span></div>{d}</div></div>')


def compact(img: str, kind_label: str, dot: str, title: str, sub: str, trail: str = "") -> str:
    return (f'<div class="compact"><div class="cp-photo" style="background-image:url({img})"></div>'
            f'<div class="cp-body"><div class="cp-kind"><i class="dot" style="background:{dot}"></i>{kind_label}</div>'
            f'<div class="cp-title">{title}</div><div class="cp-sub">{sub}</div></div>{trail}</div>')


def header(subtitle: str, count: str, unread: int = 2) -> str:
    badge = f'<b class="badge">{unread}</b>' if unread else ""
    return (f'<div class="hero">{status_bar(True)}<div class="hero-top"><img class="logo" src="{LOGO}"/>'
            f'<span class="wordmark">winou</span>'
            f'<span class="ha">{icon("map", 22, "#fff")}</span>'
            f'<span class="ha">{icon("message", 22, "#fff")}{badge}</span>'
            f'<span class="ha">{icon("user", 22, "#fff")}</span></div>'
            f'<div class="hero-title">{subtitle}</div><div class="hero-sub">{count}</div></div>')


def logo_svg(size: int) -> str:
    """The app icon: white pin with a blue paw on the blue to indigo gradient (same art as the launcher icon)."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3884FF"/><stop offset="1" stop-color="#4338CA"/></linearGradient></defs>
<rect width="100" height="100" rx="28" fill="url(#g)"/>
<path d="M50 84 L33.2 59.5 A21 21 0 1 1 66.8 59.5 Z" fill="#fff"/>
<circle cx="50" cy="44" r="21" fill="#fff"/>
<g fill="#2563EB"><ellipse cx="50" cy="50" rx="9" ry="7"/><ellipse cx="41.5" cy="39.5" rx="3.2" ry="4.2" transform="rotate(-20 41.5 39.5)"/>
<ellipse cx="47" cy="34.5" rx="3.2" ry="4.2" transform="rotate(-6 47 34.5)"/><ellipse cx="53" cy="34.5" rx="3.2" ry="4.2" transform="rotate(6 53 34.5)"/>
<ellipse cx="58.5" cy="39.5" rx="3.2" ry="4.2" transform="rotate(20 58.5 39.5)"/></g></svg>"""


LOGO = "data:image/svg+xml;base64," + base64.b64encode(logo_svg(100).encode()).decode()


def row(img: str, title: str, sub: str, trail: str) -> str:
    return (f'<div class="row"><div class="row-photo" style="background-image:url({img})"></div>'
            f'<div class="row-body"><div class="row-title">{title}</div><div class="row-sub">{sub}</div></div>'
            f'<div class="row-trail">{trail}</div></div>')


def bubble(text: str, mine: bool, time: str) -> str:
    return f'<div class="bubble {"mine" if mine else ""}"><span>{text}</span><small>{time}</small></div>'


def map_bg(height: int = 800) -> str:
    """A simple map texture: blocks, streets, a park and the sea, as in the guide's marker sheet."""
    if height < 300:
        return f"""<div class="map" style="height:{height}px"><i class="sea"></i>
<i class="st h" style="top:36px"></i><i class="st h main" style="top:96px"></i>
<i class="st v" style="left:60px"></i><i class="st v main" style="left:170px"></i><i class="st v" style="left:270px"></i></div>"""
    return f"""<div class="map" style="height:{height}px">
<i class="sea"></i><i class="park"></i>
<i class="st h" style="top:150px"></i><i class="st h" style="top:330px"></i><i class="st h" style="top:520px"></i><i class="st h main" style="top:640px"></i>
<i class="st v" style="left:70px"></i><i class="st v main" style="left:190px"></i><i class="st v" style="left:300px"></i>
<i class="st d"></i></div>"""


# --- Screens (each returns the inside of a 360x800 frame) ---

def splash():
    return f"""<div class="splash">{status_bar(True)}<div class="splash-mid">
<img class="logo big" src="{LOGO}"/><div class="wordmark xl">winou</div>
<div class="tagline">Find lost pets, help street animals</div></div>
<div class="splash-foot">Tunis · ensemble</div></div>"""


def auth(register: bool):
    name = field("Display name", "Sami", "user") if register else ""
    pwd_help = "At least 8 characters" if register else ""
    title = "Create account" if register else "Sign in"
    link = "Already have an account? Sign in" if register else "No account yet? Create one"
    return f"""<div class="auth">{status_bar(True)}<div class="auth-top"><img class="logo" style="width:72px;height:72px" src="{LOGO}"/>
<div class="wordmark l">winou</div><div class="tagline">Find lost pets, help street animals</div></div>
<div class="sheet-up"><div class="h-title">{title}</div>{name}
{field("Email", "sami@example.com" if register else "Your email", "mail", "focus" if not register else "", placeholder=not register)}
{field("Password", "••••••••", "lock", help=pwd_help)}
{btn(title, None, "filled")}<div class="link">{link}</div></div></div>"""


def home(state: str = "list", with_fabs: bool = True):
    filters = f"""<div class="filters">{chip("Near me", True, "navigation")}{chip("Everywhere", False, "globe")}<i class="vsep"></i>{chip("All", True)}{chip("Dogs")}{chip("Cats")}</div>"""
    if state == "list":
        body = (pet_card("Luna", CAT, ("Still lost", "lost", "search"), "Cat · 800 m away · La Marsa", "Seen 2 h ago",
                         "Shy grey tabby, green eyes, small notch in the left ear.")
                + pet_card("Rocky", DOG, ("Still lost", "lost", "search"), "Dog · 2.4 km away · Le Bardo", "Seen yesterday"))
        count = "12 pets are missing"
    elif state == "empty":
        body = ('<div class="empty"><div class="empty-ic">' + icon("heart", 44) + '</div>'
                '<p>No missing pets near you right now. That\'s good news.</p></div>')
        count = "No pet missing here"
    elif state == "loading":
        body = '<div class="skel"><i class="sk-photo"></i><i class="sk-line w60"></i><i class="sk-line w40"></i><i class="sk-line w80"></i></div>' * 2
        count = "&nbsp;"
    else:
        body = ('<div class="empty"><div class="empty-ic">' + icon("cloud-off", 44) + '</div>'
                '<p>Cannot reach the server. Check your connection.</p>' + btn("Try again", None, "outlined", "auto") + "</div>")
        count = "&nbsp;"
    fabs = f'<div class="fabs">{fab("Report a lost pet", "coral", "megaphone")}{fab("I saw an animal", "blue", "camera")}</div>'
    return f'{header("Help bring them home", count)}{filters}<div class="list">{body}</div>{fabs if with_fabs else ""}'


def lost_detail():
    return f"""<div class="photo-head" style="background-image:url({CAT})">{status_bar(True)}
<div class="ph-bar"><span class="round">{icon("arrow-left", 22, "#fff")}</span><span class="round">{icon("more", 22, "#fff")}</span></div>
<div class="dots"><i class="on"></i><i></i><i></i></div></div>
<div class="detail-sheet"><div class="pc-top"><span class="d-name">Luna</span>{pill("Still lost", "lost", "search")}</div>
<div class="card info">{info_row("paw", "Cat · female · 3 years")}{info_row("clock", "Last seen Oct 27, 20:18")}{info_row("notes", "Shy grey tabby, green eyes, small notch in the left ear. Answers to her name.")}</div>
{btn("I got Luna back", "house", "green")}
<div class="mini-map">{map_bg(160)}<i class="fuzz"></i></div>
<div class="caption">Approximate area: the exact place stays private.</div></div>"""


def info_row(ic: str, text: str) -> str:
    return f'<div class="info-row">{icon(ic, 20)}<span>{text}</span></div>'


def report_form():
    return f"""{status_bar()}{appbar("Report a lost pet")}<div class="form">
<div class="caption">Add 1–5 clear photos, ideally of the face from different angles.</div>
<div class="attach"><span class="cam">{icon("camera", 24)}</span><div><b>Add a clear photo</b><small>Camera or gallery</small></div></div>
{field("Pet's name", "Luna", "paw", "focus")}
<div class="flabel">Species</div><div class="seg"><span class="on">{icon("check", 18)}Cat</span><span>Dog</span><span>Other</span></div>
{field("Description (optional)", "Collar, markings, temperament…", None, placeholder=True, tall=True)}
<div class="pick">{icon("clock", 22)}<div><b>Last seen</b><small>Oct 29, 2026 · 10:34</small></div><span class="link-s">Change</span></div>
<div class="pick">{icon("map-pin", 22)}<div><b>Where was it last seen?</b><small>Choose it on the map</small></div><span class="link-s">Choose</span></div>
{btn("Publish report", "megaphone", "filled")}</div>"""


def sighting_form():
    return f"""{status_bar()}{appbar("I saw an animal")}<div class="form">
<div class="shot" style="background-image:url({DOG})"><span class="retake">{icon("camera", 18)}Retake</span></div>
<div class="flabel">Species</div><div class="seg"><span>Cat</span><span class="on">{icon("check", 18)}Dog</span><span>Other</span></div>
<div class="flabel">Condition</div><div class="chips">{chip("Healthy", True)}{chip("Injured")}{chip("Needs help")}</div>
<div class="switch-row"><div><b>This is a street animal</b><small>It lives outside and has no owner</small></div><i class="switch on"></i></div>
{field("Note (optional)", "Near the bakery, friendly", "notes")}
<div class="pick">{icon("map-pin", 22)}<div><b>Location from the photo</b><small>Le Bardo · tap to adjust</small></div><span class="link-s">Adjust</span></div>
{btn("Send sighting", "send", "filled")}</div>"""


def thanks():
    return f"""{status_bar()}<div class="thanks"><div class="big-ic">{icon("heart", 56)}</div>
<div class="h-title center">Thank you!</div><p class="center muted">Your sighting is on the map. If it looks like a lost pet, we'll tell the owner right away.</p>
<div class="compact-wrap">{compact(DOG, "Sighting", "#3884FF", "Dog seen in Le Bardo", "Just now · Healthy")}</div>
{btn("Back to missing pets", None, "outlined")}</div>"""


def match(state: str):
    if state == "pending":
        actions = (note("Our model found these photos similar. Look closely at markings before contacting the finder.", "info", "lightbulb")
                   + '<div class="two">' + btn("Not my pet", None, "outlined") + btn("That's my pet", "heart", "filled") + "</div>"
                   + btn("Message the finder", "message", "outlined"))
    elif state == "confirmed":
        actions = (note("You recognised Luna. The person who saw her has been told.", "found", "circle-check")
                   + btn("I got Luna back", "house", "green") + btn("Open the conversation", "message", "outlined"))
    else:
        actions = note("Luna is back home. The case is closed.", "found", "house") + btn("Open the conversation", "message", "outlined")
    return f"""{status_bar()}{appbar("Possible match")}<div class="scroll">
<div class="h-title">Could this be Luna?</div>
<div class="card matchcard">{ring(84)}<div><b>Possible visual match</b><small>A resemblance, not a confirmed identity.</small></div></div>
<div class="pair"><div><div class="plabel">Your photo</div><div class="sq" style="background-image:url({CAT})"></div></div>
<div><div class="plabel">Sighting</div><div class="sq" style="background-image:url({CAT});background-size:260%;background-position:50% 55%"></div></div></div>
{actions}<div class="pills">{pill("Sighting", "info", "eye")}{pill("Healthy", "found", "heart-pulse")}</div></div>"""


def match_undo():
    """After "Not my pet": the match is hidden, with a way back."""
    return f"""{status_bar()}{appbar("My activity", True, '<span class="ib">' + icon("log-out", 22) + "</span>")}
<div class="tabs"><span class="on">Matches</span><span>My lost pets</span><span>My sightings</span></div>
<div class="list">{row(DOG, "Could this be Rocky?", pill("71%", "info", "eye") + "<span>3 days ago</span>", icon("chevron-right", 22))}</div>
<div class="snack" style="bottom:24px"><span>Hidden. This sighting won't be suggested again.</span><b>Undo</b></div>"""


def match_close_dialog():
    """Before "I got Luna back" closes the case."""
    return f"""{match("confirmed")}<div class="scrim"></div>
<div class="dialog"><p>Is Luna back home? This closes the case: no more matches, and the report leaves the map. You can reopen it later.</p>
<div class="dlg-actions"><span class="link-s">Cancel</span>{btn("Close the case", None, "filled", "auto")}</div></div>"""


def map_screen(sheet: str = ""):
    markers = (marker("lost", 120, 250) + marker("sighting", 214, 300) + marker("stray", 60, 430) + marker("injured", 250, 470)
               + marker("sighting", 150, 560) + marker("lost", 280, 190))
    fabs = f'<div class="fabs">{fab("Report a lost pet", "coral", "megaphone")}{fab("I saw an animal", "blue", "camera")}</div>'
    locate = f'<span class="locate">{icon("locate", 22)}</span>'
    over = ""
    if sheet == "filters":
        over = f"""<div class="scrim"></div><div class="bsheet"><i class="handle"></i><div class="h-sub">Filters</div>
<div class="flabel">Show</div><div class="chips">{chip("Lost pets", True, dot="#F43F5E")}{chip("Sighting", True, dot="#3884FF")}{chip("Stray", True, dot="#F59E0B")}</div>
<div class="flabel">Species</div><div class="chips">{chip("Cat")}{chip("Dog")}{chip("Other")}</div>
<div class="flabel">Condition</div><div class="chips">{chip("Healthy")}{chip("Injured")}{chip("Needs help")}</div>
<div class="flabel">Period</div><div class="chips">{chip("7 days")}{chip("30 days", True)}{chip("90 days")}{chip("Any time")}</div>
{btn("Apply", None, "filled")}</div>"""
        fabs = locate = ""
    elif sheet == "preview":
        over = f"""<div class="bsheet short"><i class="handle"></i>{compact(CAT, "Lost pet", "#F43F5E", "Luna is lost", "Seen 2 h ago · La Marsa", '<span class="chev">' + icon("chevron-right", 22) + "</span>")}</div>"""
        fabs = locate = ""
    return f"""{map_bg()}{markers}<div class="map-top">{status_bar()}{appbar("Map", True, '<span class="ib">' + icon("sliders", 22) + '</span><span class="ib">' + icon("user", 22) + "</span>")}</div>
{locate}{fabs}{over}"""


def activity():
    rows = (row(CAT, "Could this be Luna?", pill("84%", "info", "eye") + "<span>2 h ago</span>", icon("chevron-right", 22))
            + row(CAT, "Could this be Luna?", pill("Confirmed", "found", "check") + "<span>yesterday</span>", icon("circle-check", 22, "#22C55E"))
            + row(DOG, "Could this be Rocky?", pill("71%", "info", "eye") + "<span>3 days ago</span>", icon("chevron-right", 22)))
    tabs = '<div class="tabs"><span class="on">Matches</span><span>My lost pets</span><span>My sightings</span></div>'
    return f"""{status_bar()}{appbar("My activity", True, '<span class="ib">' + icon("log-out", 22) + "</span>")}{tabs}<div class="list">{rows}</div>"""


def activity_empty():
    tabs = '<div class="tabs"><span>Matches</span><span class="on">My lost pets</span><span>My sightings</span></div>'
    return f"""{status_bar()}{appbar("My activity", True, '<span class="ib">' + icon("log-out", 22) + "</span>")}{tabs}
<div class="empty"><div class="empty-ic">{icon("megaphone", 44)}</div><p>You haven't reported a lost pet. We hope you never need to.</p></div>"""


def messages(empty: bool = False):
    if empty:
        body = f'<div class="empty"><div class="empty-ic">{icon("message", 44)}</div><p>No messages yet. When you write to someone who saw your pet, the conversation appears here.</p></div>'
    else:
        body = (row(CAT, "<b>Sami · Luna</b>", "<span class='strong'>She's under the blue car near the bakery</span>",
                    '<small class="t hot">2 min</small><b class="badge in">2</b>')
                + row(DOG, "Amira · Rocky", "<span>You: Thank you so much!</span>", '<small class="t">yesterday</small>')
                + row(CAT, "Youssef · Mimi", "<span>Mimi is home, thanks again</span>",
                      '<small class="t">Oct 20</small>' + icon("house", 18, "#22C55E")))
    return f'{status_bar()}{appbar("Messages")}<div class="list">{body}</div>'


def chat(state: str = "open"):
    banner = ('<div class="banner">' + icon("house", 20) + "<span>Luna is back home. This case is closed, but you can still write.</span></div>"
              if state == "closed" else "")
    if state == "empty":
        body = (f'<div class="empty"><div class="empty-ic">{icon("wave", 44)}</div><p>No messages yet. Say hello and explain how you can help.</p>'
                '<p class="small">Only your display name is shown. Never share your address before you\'re sure.</p></div>')
    else:
        body = (bubble("Hi! Is she still there? She has a notch in her left ear.", True, "10:02")
                + bubble("Yes, she's sleeping under the blue car next to the bakery. I can see the notch.", False, "10:04")
                + bubble("That's her! I'm 10 minutes away.", True, "10:05")
                + bubble("I'll stay here and keep an eye on her.", False, "10:05")
                + (bubble("She's home. Thank you so much, Sami!", True, "11:20") if state == "closed" else ""))
    head = f"""<div class="appbar">{'<span class="ib">' + icon("arrow-left", 24) + '</span>'}<div class="ab-two"><b>Sami</b><small>About Luna</small></div><span class="ab-actions"><span class="ib">{icon("paw", 22)}</span></span></div>"""
    return f"""{status_bar()}{head}{banner}<div class="chat">{body}</div>
<div class="composer"><span class="input">Write a message</span><span class="send">{icon("send", 20, "#111D36")}</span></div>"""


def notifications():
    return f"""<div class="lock">{status_bar(True)}<div class="clock">10:41</div><div class="date">Thursday, October 29</div>
{push("Possible match", "Someone may have seen Luna. Tap to compare the photos.", "now")}
{push("Sami · about Luna", "She's under the blue car near the bakery", "2 min")}
{push("You may have found a lost pet", "The owner of Luna recognised the animal you saw.", "1 h")}
{push("Luna is back home!", "Thank you for helping Luna find their way home.", "3 h")}</div>"""


def push(title: str, text: str, when: str) -> str:
    return (f'<div class="push"><img class="push-ic" src="{LOGO}"/><div><div class="push-head"><b>Winou</b><small>· {when}</small></div>'
            f'<b class="push-title">{title}</b><span>{text}</span></div></div>')


def snackbars():
    return f"""{home("list", with_fabs=False)}<div class="snack" style="bottom:88px"><span>Someone may have seen Luna</span><b>View</b></div>
<div class="snack" style="bottom:24px"><span>New message from Sami</span><b>View</b></div>"""


SECTIONS = [
    ("Start", [("Splash", splash), ("Sign in", lambda: auth(False)), ("Register", lambda: auth(True))]),
    ("Home", [("Missing pets", home), ("Empty", lambda: home("empty")), ("Loading", lambda: home("loading")), ("Error", lambda: home("error"))]),
    ("Lost pets and sightings", [("Lost pet details", lost_detail), ("Report a lost pet", report_form),
                                 ("I saw an animal", sighting_form), ("Thank you", thanks)]),
    ("Possible match", [("Pending", lambda: match("pending")), ("Confirmed", lambda: match("confirmed")),
                        ("Case closed", lambda: match("closed")), ("Not my pet, undo", match_undo),
                        ("Close the case", match_close_dialog)]),
    ("Map and activity", [("Map", map_screen), ("Filters", lambda: map_screen("filters")), ("Marker preview", lambda: map_screen("preview")),
                          ("My activity", activity), ("My activity, empty", activity_empty)]),
    ("Messages", [("Messages", messages), ("Messages, empty", lambda: messages(True)), ("Chat", chat),
                  ("Chat, case closed", lambda: chat("closed")), ("Chat, empty", lambda: chat("empty"))]),
    ("Notifications", [("Push notifications", notifications), ("In-app snackbars", snackbars)]),
]

CSS = (HERE / "screens.css").read_text(encoding="utf-8")


def build() -> str:
    parts = []
    for title, screens in SECTIONS:
        for theme in ("light", "dark"):
            frames = "".join(
                f'<figure><figcaption>{name} · {theme.title()}</figcaption><div class="screen {theme}">{fn()}</div></figure>'
                for name, fn in screens)
            parts.append(f'<section><h2>{title} · {theme.title()}</h2><div class="row-frames">{frames}</div></section>')
    photos = ":root{" + "".join(f"--{k}:url({v});" for k, v in PHOTOS.items()) + "}"
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Winou screens</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap" rel="stylesheet">
<style>{photos}{CSS}</style></head><body>
<header class="doc"><span class="wordmark doc-mark">winou</span><h1>Android screens</h1>
<p>Built from the Winou Android design guide. 360 × 800 frames, light and dark. Illustrative pets and names.</p></header>
{''.join(parts)}</body></html>"""
    return page.replace("url(__cat__)", "var(--cat)").replace("url(__dog__)", "var(--dog)")


if __name__ == "__main__":
    out = HERE / "winou-screens.html"
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} KB)")
