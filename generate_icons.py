"""Generate SaveX Space icons - purple globe/leaf on black background."""
import math
from PIL import Image, ImageDraw, ImageFilter

def create_logo(size=1024):
    """Create a stylized purple globe/leaf icon on black background."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    r = int(size * 0.38)

    # Main globe circle - purple gradient effect
    for i in range(r, 0, -1):
        t = i / r
        # Purple to violet gradient
        red = int(120 + (160 - 120) * (1 - t))
        green = int(50 + (80 - 50) * (1 - t))
        blue = int(200 + (255 - 200) * (1 - t))
        alpha = 255
        draw.ellipse(
            [cx - i, cy - i, cx + i, cy + i],
            fill=(red, green, blue, alpha)
        )

    # Add leaf/petal curves on top of globe for the leaf motif
    # Upper-right leaf curve
    leaf_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    leaf_draw = ImageDraw.Draw(leaf_img)

    # Leaf shape 1 - upper right swoosh
    leaf_points = []
    for t_i in range(100):
        t = t_i / 99.0
        # Bezier-like curve for leaf
        x = cx + r * 0.1 + t * r * 0.9
        y = cy - r * 0.3 - math.sin(t * math.pi) * r * 0.7
        leaf_points.append((x, y))
    # Return path
    for t_i in range(99, -1, -1):
        t = t_i / 99.0
        x = cx + r * 0.15 + t * r * 0.8
        y = cy - r * 0.1 - math.sin(t * math.pi) * r * 0.35
        leaf_points.append((x, y))

    if len(leaf_points) >= 3:
        leaf_draw.polygon(leaf_points, fill=(180, 100, 255, 180))

    # Leaf shape 2 - upper left swoosh
    leaf_points2 = []
    for t_i in range(100):
        t = t_i / 99.0
        x = cx - r * 0.1 - t * r * 0.9
        y = cy - r * 0.2 - math.sin(t * math.pi) * r * 0.6
        leaf_points2.append((x, y))
    for t_i in range(99, -1, -1):
        t = t_i / 99.0
        x = cx - r * 0.15 - t * r * 0.8
        y = cy - r * 0.05 - math.sin(t * math.pi) * r * 0.3
        leaf_points2.append((x, y))

    if len(leaf_points2) >= 3:
        leaf_draw.polygon(leaf_points2, fill=(140, 70, 220, 150))

    # Composite leaf onto main image
    img = Image.alpha_composite(img, leaf_img)

    # Add globe grid lines for the "globe" look
    grid_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid_img)

    # Horizontal latitude lines
    for lat in [-0.5, -0.2, 0.1, 0.4]:
        y_pos = cy + int(lat * r)
        # Calculate width at this latitude
        lat_r = math.sqrt(max(0, r*r - (lat*r)**2))
        if lat_r > 10:
            grid_draw.arc(
                [cx - int(lat_r), y_pos - int(lat_r * 0.3), cx + int(lat_r), y_pos + int(lat_r * 0.3)],
                0, 360,
                fill=(255, 255, 255, 40),
                width=max(2, size // 200)
            )

    # Vertical longitude lines
    for lon_offset in [-0.4, 0, 0.4]:
        x_off = int(lon_offset * r)
        ellipse_w = int(r * 0.3 * (1 - abs(lon_offset)))
        if ellipse_w > 5:
            grid_draw.arc(
                [cx + x_off - ellipse_w, cy - r, cx + x_off + ellipse_w, cy + r],
                0, 360,
                fill=(255, 255, 255, 35),
                width=max(2, size // 200)
            )

    img = Image.alpha_composite(img, grid_img)

    # Add a subtle glow around the globe
    glow_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    for i in range(30, 0, -1):
        glow_r = r + i * (size // 80)
        alpha = max(0, 30 - i)
        glow_draw.ellipse(
            [cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r],
            fill=(140, 80, 220, alpha)
        )

    # Put glow behind the main image
    final = Image.alpha_composite(glow_img, img)

    # Add small bright accent - a small bright purple dot at bottom
    accent_r = int(r * 0.08)
    accent_x = cx + int(r * 0.3)
    accent_y = cy + int(r * 0.85)
    draw2 = ImageDraw.Draw(final)
    draw2.ellipse(
        [accent_x - accent_r, accent_y - accent_r, accent_x + accent_r, accent_y + accent_r],
        fill=(200, 150, 255, 200)
    )

    return final


def save_all_icons(logo):
    """Save icons in all required sizes and formats."""
    base = "C:/Users/erock/Documents/FORK/FlClash"

    # 1. Main Flutter asset
    icon_512 = logo.resize((512, 512), Image.LANCZOS)
    icon_512.save(f"{base}/assets/images/icon.png")
    print("Saved assets/images/icon.png")

    # 2. Windows app_icon.ico (multi-size)
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_images = []
    for s in ico_sizes:
        ico_images.append(logo.resize((s, s), Image.LANCZOS))
    ico_images[0].save(
        f"{base}/windows/runner/resources/app_icon.ico",
        format='ICO',
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[1:]
    )
    print("Saved windows/runner/resources/app_icon.ico")

    # 3. Flutter asset icon.ico (for tray etc)
    ico_images[0].save(
        f"{base}/assets/images/icon.ico",
        format='ICO',
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[1:]
    )
    print("Saved assets/images/icon.ico")

    # 4. Tray status icons - create colored variants
    for status_num, color_tint in [(1, (100, 200, 100)), (2, (200, 200, 100)), (3, (200, 100, 100))]:
        status_ico = logo.resize((64, 64), Image.LANCZOS)
        # Save as-is for now (status icons can be differentiated later)
        status_ico_16 = logo.resize((16, 16), Image.LANCZOS)
        status_ico_16.save(
            f"{base}/assets/images/icon/status_{status_num}.ico",
            format='ICO',
            sizes=[(16, 16), (32, 32), (64, 64)],
            append_images=[logo.resize((32, 32), Image.LANCZOS), status_ico]
        )
    print("Saved tray status icons")

    # 5. macOS icons
    mac_sizes = {
        'app_icon_16.png': 16,
        'app_icon_32.png': 32,
        'app_icon_64.png': 64,
        'app_icon_128.png': 128,
        'app_icon_256.png': 256,
        'app_icon_512.png': 512,
        'app_icon_1024.png': 1024,
    }
    for fname, s in mac_sizes.items():
        resized = logo.resize((s, s), Image.LANCZOS)
        resized.save(f"{base}/macos/Runner/Assets.xcassets/AppIcon.appiconset/{fname}")
    print("Saved macOS icons")

    # 6. Android icons
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    # Convert to RGB with black background for webp
    rgb_logo = Image.new('RGB', logo.size, (0, 0, 0))
    rgb_logo.paste(logo, mask=logo.split()[3])

    for mipmap, s in android_sizes.items():
        resized = rgb_logo.resize((s, s), Image.LANCZOS)
        path = f"{base}/android/app/src/main/res/{mipmap}/ic_launcher.webp"
        resized.save(path, 'WEBP', quality=95)
        # Round version
        round_path = f"{base}/android/app/src/main/res/{mipmap}/ic_launcher_round.webp"
        # Create circular mask
        mask = Image.new('L', (s, s), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, s, s], fill=255)
        round_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        rgba_resized = logo.resize((s, s), Image.LANCZOS)
        round_img.paste(rgba_resized, mask=mask)
        # Convert to RGB
        round_rgb = Image.new('RGB', (s, s), (0, 0, 0))
        round_rgb.paste(round_img, mask=round_img.split()[3])
        round_rgb.save(round_path, 'WEBP', quality=95)

    print("Saved Android icons")

    # 7. Android Play Store icon
    playstore = rgb_logo.resize((512, 512), Image.LANCZOS)
    playstore.save(f"{base}/android/app/src/main/ic_launcher-playstore.png")
    print("Saved Android Play Store icon")


if __name__ == '__main__':
    print("Generating SaveX Space logo...")
    logo = create_logo(1024)
    logo.save("C:/Users/erock/Documents/FORK/FlClash/logo_preview.png")
    print("Preview saved to logo_preview.png")
    save_all_icons(logo)
    print("Done!")
