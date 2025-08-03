#!/usr/bin/env python3
"""
Generate app icons for AProfileo
Creates icons for Android and Web platforms
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, output_path):
    """Create a single icon of the specified size"""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Purple gradient background circle
    center = size // 2
    radius = int(size * 0.45)
    
    # Draw background circle with purple gradient effect
    for i in range(radius, 0, -1):
        alpha = int(255 * (1 - i / radius) * 0.9 + 25)
        color = (190, 0, 255, alpha)  # #be00ff with varying alpha
        draw.ellipse(
            [center - i, center - i, center + i, center + i],
            fill=color
        )
    
    # Draw main circle
    draw.ellipse(
        [center - radius, center - radius, center + radius, center + radius],
        fill=(190, 0, 255, 255)  # #be00ff
    )
    
    # Draw admin icon in the center
    icon_size = int(size * 0.25)
    
    # Simple admin crown/shield icon
    # Draw a shield shape
    shield_width = icon_size
    shield_height = int(icon_size * 1.2)
    shield_left = center - shield_width // 2
    shield_top = center - shield_height // 2
    
    # Shield outline
    shield_points = [
        (center, shield_top),  # top center
        (shield_left + shield_width, shield_top + shield_height // 3),  # top right
        (shield_left + shield_width, shield_top + shield_height * 2 // 3),  # bottom right
        (center, shield_top + shield_height),  # bottom center
        (shield_left, shield_top + shield_height * 2 // 3),  # bottom left
        (shield_left, shield_top + shield_height // 3),  # top left
    ]
    
    draw.polygon(shield_points, fill=(255, 255, 255, 255))
    
    # Add "A" letter in the center
    try:
        # Try to use a system font
        font_size = int(size * 0.2)
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        # Fallback to default font
        font_size = int(size * 0.15)
        font = ImageFont.load_default()
    
    # Draw "A" for AProfileo
    text = "A"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = center - text_width // 2
    text_y = center - text_height // 2 + int(size * 0.02)  # slight adjustment
    
    draw.text((text_x, text_y), text, fill=(190, 0, 255, 255), font=font)
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created icon: {output_path} ({size}x{size})")

def main():
    """Generate all required icons"""
    print("Generating AProfileo app icons...")
    
    # Android icons
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, size in android_sizes.items():
        icon_path = f"android/app/src/main/res/{folder}/ic_launcher.png"
        os.makedirs(os.path.dirname(icon_path), exist_ok=True)
        create_icon(size, icon_path)
    
    # Web icons
    web_icons = {
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
    }
    
    for path, size in web_icons.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        create_icon(size, path)
    
    print("All icons generated successfully!")
    print("\nGenerated icons:")
    print("- Android: mipmap-mdpi to mipmap-xxxhdpi (48px to 192px)")
    print("- Web: favicon.png (32px), Icon-192.png, Icon-512.png, and maskable variants")

if __name__ == "__main__":
    main()
