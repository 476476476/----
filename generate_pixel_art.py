#!/usr/bin/env python3
"""Pixel Art Generator for Cowboy Game — 19 assets, all in pixel art style."""

from PIL import Image, ImageDraw
import os, math

OUT = r"F:\AICoding\cowboy_is_CRAZY\新建游戏项目\Art_Resource"

# ── helpers ──────────────────────────────────────────────────

def blank(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def draw_pixel(draw, x, y, c):
    draw.rectangle([x, y, x, y], fill=c)

def hline(draw, x1, y, x2, c):
    draw.line([(x1, y), (x2, y)], fill=c)

def vline(draw, x, y1, y2, c):
    draw.line([(x, y1), (x, y2)], fill=c)

def rect(draw, x, y, w, h, c):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

def outline_rect(draw, x, y, w, h, c):
    hline(draw, x, y, x + w - 1, c)
    hline(draw, x, y + h - 1, x + w - 1, c)
    vline(draw, x, y, x + h - 1, c)
    vline(draw, x + w - 1, y, y + h - 1, c)

def sprite_sheet(frames, fw, fh):
    """frames: list of PIL Images, fw/fh: single frame size"""
    n = len(frames)
    sheet = blank(fw * n, fh)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * fw, 0), f)
    return sheet

# ── color palettes ───────────────────────────────────────────

C_SKIN     = (255, 200, 150, 255)
C_SHIRT    = (180, 50,  50,  255)  # red
C_PANTS    = (50,  50,  120, 255)  # dark blue
C_HAT      = (80,  50,  30,  255)  # brown
C_BOOTS    = (60,  40,  20,  255)  # dark brown
C_BELT     = (180, 150, 80,  255)  # tan

HORSE_COLORS = {
    "mongolian":    (139, 69,  19,  255),  # saddle brown
    "yili":         (180, 160, 140, 255),  # tan
    "thoroughbred": (40,  40,  40,  255),  # dark
    "ferghana":     (200, 170, 60,  255),  # gold
}

HORSE_MANE = {
    "mongolian":    (100, 50,  10,  255),
    "yili":         (140, 120, 100, 255),
    "thoroughbred": (20,  20,  20,  255),
    "ferghana":     (160, 130, 30,  255),
}

C_GRASS   = [(50,140,50,255), (40,120,40,255), (60,150,40,255), (45,130,35,255)]
C_SKY     = [(100,180,255,255), (120,190,255,255), (140,200,255,255)]
C_DIRT    = (120,80,40,255)
C_ROCK    = (120,120,120,255)
C_ROCK2   = (100,100,100,255)
C_FENCE   = (160,130,90,255)
C_POST    = (120,90,50,255)

# ── rider animations ─────────────────────────────────────────

def draw_rider_ride(fw=60, fh=100):
    """4-frame rider riding animation — slight bounce"""
    frames = []
    for bounce in [0, -2, 0, -2]:
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        oy = 10 + bounce
        # body
        rect(d, 22, oy + 10, 12, 18, C_SHIRT)
        # head
        rect(d, 24, oy, 10, 10, C_SKIN)
        # hat
        rect(d, 20, oy - 4, 16, 5, C_HAT)
        rect(d, 18, oy - 6, 20, 3, C_HAT)
        # arms
        rect(d, 16, oy + 12, 6, 4, C_SHIRT)
        rect(d, 34, oy + 12, 6, 4, C_SHIRT)
        # legs
        rect(d, 22, oy + 28, 5, 12, C_PANTS)
        rect(d, 28, oy + 28, 5, 12, C_PANTS)
        # boots
        rect(d, 21, oy + 39, 7, 3, C_BOOTS)
        rect(d, 27, oy + 39, 7, 3, C_BOOTS)
        # belt
        rect(d, 22, oy + 26, 12, 2, C_BELT)
        # face pixels
        draw_pixel(d, 27, oy + 4, (0, 0, 0, 255))
        draw_pixel(d, 31, oy + 4, (0, 0, 0, 255))
        frames.append(im)
    return frames

def draw_rider_jump(fw=60, fh=100):
    """4-frame jump animation — arms up, legs spread"""
    poses = [
        ("crouch", 0), ("leap", 20), ("apex", 40), ("descent", 20)
    ]
    frames = []
    for name, lift in poses:
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        oy = 60 - lift
        if oy < 0:
            oy = 0
        # body
        rect(d, 22, oy + 5, 14, 16, C_SHIRT)
        # head
        rect(d, 24, oy - 5, 10, 10, C_SKIN)
        # hat
        rect(d, 20, oy - 9, 16, 5, C_HAT)
        rect(d, 18, oy - 11, 20, 3, C_HAT)
        if name == "apex":
            # arms up
            rect(d, 22, oy - 2, 4, 10, C_SHIRT)
            rect(d, 32, oy - 2, 4, 10, C_SHIRT)
        else:
            rect(d, 16, oy + 8, 6, 4, C_SHIRT)
            rect(d, 36, oy + 8, 6, 4, C_SHIRT)
        # spread legs
        rect(d, 20, oy + 21, 5, 10, C_PANTS)
        rect(d, 33, oy + 21, 5, 10, C_PANTS)
        rect(d, 19, oy + 30, 7, 3, C_BOOTS)
        rect(d, 32, oy + 30, 7, 3, C_BOOTS)
        rect(d, 22, oy + 19, 14, 2, C_BELT)
        draw_pixel(d, 27, oy - 1, (0, 0, 0, 255))
        draw_pixel(d, 31, oy - 1, (0, 0, 0, 255))
        frames.append(im)
    return frames

def draw_rider_fall(fw=60, fh=100):
    """3-frame fall animation"""
    frames = []
    for angle in [-15, 0, 30]:
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        # simple horizontal spread
        rect(d, 18, 20, 10, 10, C_SKIN)
        rect(d, 16, 22, 16, 4, C_HAT)
        rect(d, 14, 30, 20, 12, C_SHIRT)
        rect(d, 18, 42, 6, 8, C_PANTS)
        rect(d, 28, 42, 6, 8, C_PANTS)
        draw_pixel(d, 22, 24, (0, 0, 0, 255))
        draw_pixel(d, 26, 24, (0, 0, 0, 255))
        frames.append(im)
    return frames

# ── horse animations per breed ───────────────────────────────

def draw_horse_run(breed_name, fw=120, fh=80):
    """4-frame running animation — legs cycle, mane bounce"""
    c_body = HORSE_COLORS[breed_name]
    c_mane = HORSE_MANE[breed_name]
    frames = []
    # leg positions for gallop cycle (4 poses)
    leg_poses = [
        # (front_angle, back_angle) — simplified as y-offsets
        [("up", "back"), ("flat", "forward"), ("down", "back"), ("flat", "forward")],
    ][0]
    for fi in range(4):
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        oy = fh // 2 - 30  # vertical center of horse
        ox = 10
        # body (ellipse-ish with rectangles)
        rect(d, ox + 10, oy + 4, 80, 30, c_body)  # main torso
        rect(d, ox + 80, oy + 10, 15, 22, c_body)  # rear
        # neck
        neck_bounce = [-2, 0, -2, 0][fi]
        rect(d, ox - 8, oy + neck_bounce, 20, 16, c_body)  # neck
        # head
        rect(d, ox - 18, oy + neck_bounce - 4, 14, 12, c_body)
        # mane
        rect(d, ox - 10, oy + neck_bounce - 6, 8, 8, c_mane)
        rect(d, ox - 2, oy + neck_bounce - 8, 10, 6, c_mane)
        # eye
        draw_pixel(d, ox - 22, oy + neck_bounce, (0, 0, 0, 255))
        # nostril
        draw_pixel(d, ox - 24, oy + neck_bounce + 4, (60, 30, 30, 255))
        # ears
        vline(d, ox - 14, oy + neck_bounce - 4, oy + neck_bounce - 8, c_mane)
        vline(d, ox - 10, oy + neck_bounce - 4, oy + neck_bounce - 8, c_mane)
        # legs - front pair
        fx = [ox + 5, ox + 17, ox + 40, ox + 52][fi % 4]
        leg_y = oy + 30
        if fi % 2 == 0:
            rect(d, ox + 5, leg_y, 8, 16, c_body)   # front leg 1
            rect(d, ox + 18, leg_y + 4, 8, 12, c_mane)  # front leg 2 bent
        else:
            rect(d, ox + 5, leg_y + 4, 8, 12, c_body)
            rect(d, ox + 18, leg_y, 8, 16, c_mane)
        # back legs
        if fi % 2 == 0:
            rect(d, ox + 60, leg_y, 8, 16, c_body)
            rect(d, ox + 73, leg_y + 4, 8, 12, c_mane)
        else:
            rect(d, ox + 60, leg_y + 4, 8, 12, c_body)
            rect(d, ox + 73, leg_y, 8, 16, c_mane)
        # hooves
        hline(d, ox + 4, leg_y + 15, ox + 13, (40, 30, 20, 255))
        hline(d, ox + 17, leg_y + 15, ox + 26, (40, 30, 20, 255))
        hline(d, ox + 59, leg_y + 15, ox + 68, (40, 30, 20, 255))
        hline(d, ox + 72, leg_y + 15, ox + 81, (40, 30, 20, 255))
        # tail
        tail_x = ox + 90 + [0, 2, 0, 2][fi]
        rect(d, tail_x, oy + [4, 2, 6, 2][fi], 6, 10, c_mane)
        rect(d, tail_x + 2, oy + 10, 4, 6, (0, 0, 0, 0) if fi % 2 else c_mane)

        frames.append(im)
    return frames

def draw_horse_exhausted(breed_name, fw=120, fh=80):
    """4-frame exhausted — slow, head down, tongue out"""
    c_body = HORSE_COLORS[breed_name]
    c_mane = HORSE_MANE[breed_name]
    frames = []
    for fi in range(4):
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        oy = fh // 2 - 20
        ox = 10
        # body sloping down
        yoff = [0, 1, 0, 1][fi]
        rect(d, ox + 10, oy + yoff + 8, 80, 28, c_body)
        rect(d, ox + 80, oy + yoff + 12, 15, 20, c_body)
        # neck drooping
        rect(d, ox - 6, oy + yoff + 6, 18, 14, c_body)
        # head low
        head_y = oy + yoff + 16
        rect(d, ox - 16, head_y, 14, 10, c_body)
        draw_pixel(d, ox - 20, head_y + 2, (0, 0, 0, 255))
        # tongue
        draw_pixel(d, ox - 20, head_y + 8, (200, 80, 80, 255))
        draw_pixel(d, ox - 22, head_y + 8, (200, 80, 80, 255))
        # mane
        rect(d, ox - 8, oy + yoff, 6, 8, c_mane)
        # slow legs
        rect(d, ox + 10, oy + yoff + 34, 6, 8, c_body)
        rect(d, ox + 25, oy + yoff + 36, 6, 6, c_mane)
        rect(d, ox + 60, oy + yoff + 34, 6, 8, c_body)
        rect(d, ox + 75, oy + yoff + 36, 6, 6, c_mane)
        # droopy tail
        rect(d, ox + 88, oy + yoff + 14, 5, 14, c_mane)
        # sweat drops
        if fi % 2:
            draw_pixel(d, ox + 85, oy + yoff + 2, (100, 200, 255, 200))
            draw_pixel(d, ox + 90, oy + yoff + 6, (100, 200, 255, 200))
        frames.append(im)
    return frames

def draw_horse_crazy(breed_name, fw=120, fh=80):
    """4-frame crazy — rearing, wild eyes, mane flying"""
    c_body = HORSE_COLORS[breed_name]
    c_mane = HORSE_MANE[breed_name]
    frames = []
    for fi in range(4):
        im = blank(fw, fh)
        d = ImageDraw.Draw(im)
        oy = fh // 2 - [25, 30, 20, 30][fi]
        ox = 10
        # body tilted up
        tilt = [15, 20, 10, 20][fi]
        rect(d, ox + 5, oy + 10, 70, 28, c_body)
        rect(d, ox + 65, oy + 14, 15, 20, c_body)
        # neck reared
        neck_h = [20, 25, 18, 22][fi]
        rect(d, ox - 4, oy - 5, 16, neck_h, c_body)
        # head
        rect(d, ox - 10, oy - 15, 14, 12, c_body)
        # wild eyes — white with red pupil
        rect(d, ox - 12, oy - 12, 4, 4, (255, 255, 255, 255))
        draw_pixel(d, ox - 10, oy - 11, (255, 0, 0, 255))
        rect(d, ox - 4, oy - 12, 4, 4, (255, 255, 255, 255))
        draw_pixel(d, ox - 2, oy - 11, (255, 0, 0, 255))
        # wild mane
        for mx in [ox - 6, ox - 2, ox + 2, ox + 6]:
            my = oy - (neck_h - [2, 0, 1, 0][fi])
            rect(d, mx, my - 2, 4, 6, c_mane)
        # flailing legs
        leg_offsets = [
            [(ox + 8, oy + 36, 6, 10), (ox + 22, oy + 32, 6, 14)],
            [(ox + 6, oy + 34, 6, 12), (ox + 20, oy + 38, 6, 8)],
            [(ox + 10, oy + 38, 6, 8), (ox + 24, oy + 34, 6, 12)],
            [(ox + 8, oy + 36, 6, 10), (ox + 22, oy + 32, 6, 14)],
        ][fi]
        for lx, ly, lw, lh in leg_offsets:
            rect(d, lx, ly, lw, lh, c_body)
        # tail wild
        tail_spread = [(ox + 80, oy + 12), (ox + 82, oy + 10), (ox + 78, oy + 14), (ox + 80, oy + 12)][fi]
        rect(d, tail_spread[0], tail_spread[1], 6, 16, c_mane)
        # speed lines
        for sx in [2, 6]:
            if fi % 2:
                hline(d, sx, oy + 10, sx + 4, (200, 200, 200, 80))
                hline(d, sx, oy + 20, sx + 3, (200, 200, 200, 80))
        frames.append(im)
    return frames

# ── backgrounds ──────────────────────────────────────────────

def draw_grass(w=2000, h=600):
    """Grass field with dirt ground and grass tufts"""
    im = Image.new("RGBA", (w, h), (135, 180, 235, 255))  # sky blue
    d = ImageDraw.Draw(im)
    # green ground
    rect(d, 0, 80, w, h - 80, C_GRASS[0])
    # grass pattern
    for x in range(0, w, 4):
        for y in range(80, h, 8):
            shade = C_GRASS[(x // 4 + y // 8) % len(C_GRASS)]
            draw_pixel(d, x, y, shade)
            if (x + y) % 16 == 0:
                draw_pixel(d, x, y - 1, (80, 180, 40, 255))  # lighter tuft
                draw_pixel(d, x + 1, y, (80, 180, 40, 255))
    # dirt path (horizontal strip in middle)
    for y in range(280, 340):
        if y < 300 or y > 320:
            shade = C_DIRT if ((y // 4) % 3) != 0 else C_GRASS[0]
        else:
            shade = C_DIRT
        for x in range(0, w, 3):
            draw_pixel(d, x, y, shade)
    # clouds
    for cx in [200, 700, 1200, 1700]:
        for cy_off in range(-5, 5):
            for cw in range(-15, 15):
                if cx + cw > 0 and cx + cw < w:
                    dist = abs(cw) + abs(cy_off)
                    if dist < 10:
                        draw_pixel(d, cx + cw, 30 + (cx % 40) + cy_off * 2, (255, 255, 255, 180))
    return im

def draw_sky(w=800, h=400):
    """Sky with clouds and mountains"""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # gradient sky
    for y in range(h):
        t = y / h
        r = int(100 + 80 * t)
        g = int(160 + 80 * t)
        b = int(240 + 15 * t)
        hline(d, 0, y, w - 1, (r, g, b, 255))
    # distant mountains
    for y in range(200, h):
        mountain_h = int(100 * math.sin(y * 0.05) * math.sin((y - 100) * 0.02))
        for x in range(w):
            height = 250 + int(60 * math.sin(x * 0.008) * math.sin(x * 0.015 + 3))
            shade = (80, 120, 80, 255) if (x + y) % 3 == 0 else (90, 130, 90, 255)
            if y >= height and y < height + 200:
                draw_pixel(d, x, y, shade)
    # snow caps
    for x in range(0, w, 20):
        peak = 250 + int(60 * math.sin(x * 0.008) * math.sin(x * 0.015 + 3))
        for px in range(max(0, x - 10), min(w, x + 10)):
            for py in range(max(0, peak), peak + 15):
                if (px - x) ** 2 + (py - peak) ** 2 < 64:
                    draw_pixel(d, px, py, (255, 255, 255, 220))
    # clouds
    for cx in [120, 400, 650]:
        base_y = 50 + (cx % 70)
        for dx in range(-40, 40):
            for dy in range(-15, 15):
                if dx * dx + 4 * dy * dy < 400:
                    px, py = cx + dx, base_y + dy
                    if 0 <= px < w and 20 <= py < 200:
                        draw_pixel(d, px, py, (255, 255, 255, 200))
    return im

# ── obstacles ────────────────────────────────────────────────

def draw_rock(w=60, h=60):
    im = blank(w, h)
    d = ImageDraw.Draw(im)
    points = []
    cx, cy = w // 2, h // 2
    for x in range(w):
        for y in range(h):
            dx, dy = x - cx, y - cy
            # irregular rock shape
            r2 = dx * dx + dy * dy
            shape_r = 25 + 5 * math.sin(dx * 0.5) + 4 * math.sin(dy * 0.7)
            if r2 < shape_r * shape_r:
                shade = C_ROCK if (x + y) % 3 == 0 else C_ROCK2
                draw_pixel(d, x, y, shade)
    # highlight
    for x in range(cx - 8, cx + 8):
        for y in range(cy - 15, cy - 5):
            if x >= 0 and x < w and y >= 0 and y < h:
                r2 = (x - cx) ** 2 + (y - cy) ** 2
                if r2 < 100:
                    draw_pixel(d, x, y, (160, 160, 160, 255))
    return im

def draw_fence(w=60, h=60):
    im = blank(w, h)
    d = ImageDraw.Draw(im)
    # posts
    rect(d, 4, 5, 6, 50, C_POST)
    rect(d, 30, 5, 6, 50, C_POST)
    rect(d, 52, 5, 6, 50, C_POST)
    # horizontal rails
    rect(d, 0, 16, 60, 4, C_FENCE)
    rect(d, 0, 32, 60, 4, C_FENCE)
    rect(d, 0, 48, 60, 4, C_FENCE)
    # wood grain on rails
    for x in range(0, 60, 6):
        draw_pixel(d, x + 2, 17, (140, 110, 70, 255))
        draw_pixel(d, x + 2, 33, (140, 110, 70, 255))
        draw_pixel(d, x + 2, 49, (140, 110, 70, 255))
    return im

# ── main ─────────────────────────────────────────────────────

def main():
    dirs = ["Horses", "Rider", "Background", "Obstacles"]
    for d in dirs:
        os.makedirs(os.path.join(OUT, d), exist_ok=True)

    breeds = ["mongolian", "yili", "thoroughbred", "ferghana"]
    anims = [("run", draw_horse_run), ("exhausted", draw_horse_exhausted),
             ("crazy", draw_horse_crazy)]

    print("Generating horse sprite sheets...")
    for breed in breeds:
        for aname, afunc in anims:
            frames = afunc(breed)
            sheet = sprite_sheet(frames, 120, 80)
            path = os.path.join(OUT, "Horses", f"{breed}_{aname}.png")
            sheet.save(path)
            print(f"  {breed}_{aname}.png  ({sheet.width}x{sheet.height})")

    print("Generating rider sprite sheets...")
    rider_anims = [
        ("ride", draw_rider_ride, 60, 100),
        ("jump", draw_rider_jump, 60, 100),
        ("fall", draw_rider_fall, 60, 100),
    ]
    for aname, afunc, fw, fh in rider_anims:
        frames = afunc()
        sheet = sprite_sheet(frames, fw, fh)
        path = os.path.join(OUT, "Rider", f"rider_{aname}.png")
        sheet.save(path)
        print(f"  rider_{aname}.png  ({sheet.width}x{sheet.height})")

    print("Generating backgrounds...")
    grass = draw_grass()
    grass.save(os.path.join(OUT, "Background", "grass.png"))
    print(f"  grass.png  ({grass.width}x{grass.height})")

    sky = draw_sky()
    sky.save(os.path.join(OUT, "Background", "sky.png"))
    print(f"  sky.png  ({sky.width}x{sky.height})")

    print("Generating obstacles...")
    rock = draw_rock()
    rock.save(os.path.join(OUT, "Obstacles", "rock.png"))
    print(f"  rock.png  ({rock.width}x{rock.height})")

    fence = draw_fence()
    fence.save(os.path.join(OUT, "Obstacles", "fence.png"))
    print(f"  fence.png  ({fence.width}x{fence.height})")

    print("\nDone! 19 files generated in Art_Resource/")

if __name__ == "__main__":
    main()
