#!/usr/bin/env python3
"""
Simple app icon generator for AProfileo
Uses basic drawing to create professional looking icons
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    import math

    def create_simple_icon(size, output_path):
        """Create a simple but professional icon"""
        # Create image with transparent background
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Purple background circle
        center = size // 2
        radius = int(size * 0.45)
        
        # Draw main purple circle
        draw.ellipse(
            [center - radius, center - radius, center + radius, center + radius],
            fill=(190, 0, 255, 255)  # #be00ff
        )
        
        # Draw inner white circle for contrast
        inner_radius = int(radius * 0.7)
        draw.ellipse(
            [center - inner_radius, center - inner_radius, center + inner_radius, center + inner_radius],
            fill=(255, 255, 255, 255)
        )
        
        # Draw "A" for AProfileo
        font_size = int(size * 0.3)
        
        # Simple A shape using lines
        a_width = int(size * 0.25)
        a_height = int(size * 0.35)
        a_left = center - a_width // 2
        a_top = center - a_height // 2
        a_right = center + a_width // 2
        a_bottom = center + a_height // 2
        
        line_width = max(2, size // 25)
        
        # Draw A shape
        # Left line
        draw.line([(a_left, a_bottom), (center, a_top)], fill=(190, 0, 255, 255), width=line_width)
        # Right line  
        draw.line([(center, a_top), (a_right, a_bottom)], fill=(190, 0, 255, 255), width=line_width)
        # Cross bar
        mid_y = center + int(a_height * 0.1)
        mid_left = center - int(a_width * 0.25)
        mid_right = center + int(a_width * 0.25)
        draw.line([(mid_left, mid_y), (mid_right, mid_y)], fill=(190, 0, 255, 255), width=line_width)
        
        # Save the image
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        img.save(output_path, 'PNG')
        print(f"Created icon: {output_path} ({size}x{size})")

    def main():
        """Generate all required icons"""
        print("Generating AProfileo app icons...")
        
        # Android icons
        android_sizes = {
            'android/app/src/main/res/mipmap-mdpi': 48,
            'android/app/src/main/res/mipmap-hdpi': 72,
            'android/app/src/main/res/mipmap-xhdpi': 96,
            'android/app/src/main/res/mipmap-xxhdpi': 144,
            'android/app/src/main/res/mipmap-xxxhdpi': 192,
        }
        
        for folder, size in android_sizes.items():
            icon_path = f"{folder}/ic_launcher.png"
            create_simple_icon(size, icon_path)
        
        # Web icons
        web_icons = {
            'web/favicon.png': 32,
            'web/icons/Icon-192.png': 192,
            'web/icons/Icon-512.png': 512,
            'web/icons/Icon-maskable-192.png': 192,
            'web/icons/Icon-maskable-512.png': 512,
        }
        
        for path, size in web_icons.items():
            create_simple_icon(size, path)
        
        print("All icons generated successfully!")
        print("Generated icons:")
        print("- Android: 48px to 192px")
        print("- Web: 32px favicon and 192px/512px icons")

    if __name__ == "__main__":
        main()

except ImportError:
    print("PIL (Pillow) not available. Creating placeholder files...")
    
    # Create placeholder files if PIL is not available
    import os
    
    def create_placeholder(path, size):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(f"# Placeholder for {size}x{size} icon\n")
        print(f"Created placeholder: {path}")
    
    # Android placeholders
    android_sizes = {
        'android/app/src/main/res/mipmap-mdpi': 48,
        'android/app/src/main/res/mipmap-hdpi': 72,
        'android/app/src/main/res/mipmap-xhdpi': 96,
        'android/app/src/main/res/mipmap-xxhdpi': 144,
        'android/app/src/main/res/mipmap-xxxhdpi': 192,
    }
    
    for folder, size in android_sizes.items():
        create_placeholder(f"{folder}/ic_launcher.png", size)
    
    # Web placeholders
    web_icons = {
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
    }
    
    for path, size in web_icons.items():
        create_placeholder(path, size)
    
    print("Created placeholder files. Install Pillow with 'pip install pillow' to generate actual icons.")
