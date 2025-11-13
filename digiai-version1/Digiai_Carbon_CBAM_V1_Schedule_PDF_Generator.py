"""
generate_landing_page_with_nav.py
Creates a proportional A4 landing page mock with a floating glass header
and subtle navigation placeholders using the Damno gradient accent.
"""

import os

from PIL import Image
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

PAGE_WIDTH, PAGE_HEIGHT = A4

# Damno gradient colors
DAMNO_PURPLE = colors.Color(80 / 255, 45 / 255, 255 / 255)
DAMNO_ORANGE = colors.Color(255 / 255, 122 / 255, 0 / 255)
TEXT_GRAY = colors.Color(85 / 255, 85 / 255, 85 / 255, alpha=0.6)


def draw_gradient_line(c, x, y, width, height):
    """Draw horizontal Damno gradient line."""
    steps = 100
    for i in range(steps):
        ratio = i / steps
        r = DAMNO_PURPLE.red + ratio * (DAMNO_ORANGE.red - DAMNO_PURPLE.red)
        g = DAMNO_PURPLE.green + ratio * (DAMNO_ORANGE.green - DAMNO_PURPLE.green)
        b = DAMNO_PURPLE.blue + ratio * (DAMNO_ORANGE.blue - DAMNO_PURPLE.blue)
        c.setFillColor(colors.Color(r, g, b))
        c.rect(x + (width / steps) * i, y, width / steps, height, stroke=0, fill=1)


def draw_background_image(c, path):
    """Draws the background image proportionally centered."""
    img = Image.open(path)
    img_width, img_height = img.size
    page_ratio = PAGE_WIDTH / PAGE_HEIGHT
    img_ratio = img_width / img_height

    if img_ratio > page_ratio:
        # Image is wider than page
        scaled_height = PAGE_HEIGHT
        scaled_width = img_ratio * scaled_height
    else:
        # Image is taller than page
        scaled_width = PAGE_WIDTH
        scaled_height = scaled_width / img_ratio

    x = (PAGE_WIDTH - scaled_width) / 2
    y = (PAGE_HEIGHT - scaled_height) / 2
    c.drawImage(ImageReader(path), x, y, width=scaled_width, height=scaled_height, mask='auto')


def create_landing_page():
    c = canvas.Canvas("Digiai_Carbon_Landing_v3.pdf", pagesize=A4)

    # === Background ===
    bg_path = "background.png"
    if os.path.exists(bg_path):
        draw_background_image(c, bg_path)
    else:
        c.setFillColor(colors.Color(245 / 255, 246 / 255, 248 / 255))
        c.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, fill=1, stroke=0)

    # === Floating Header ===
    header_y = PAGE_HEIGHT - 180
    header_h = 50
    header_w = PAGE_WIDTH - 160
    header_x = 80

    # Shadow for depth
    c.setFillColor(colors.Color(0, 0, 0, alpha=0.10))
    c.roundRect(header_x + 2, header_y - 2, header_w, header_h, 25, fill=1, stroke=0)

    # Glass background
    c.setFillColor(colors.Color(1, 1, 1, alpha=0.20))
    c.roundRect(header_x, header_y, header_w, header_h, 25, fill=1, stroke=0)

    # Gradient accent line
    draw_gradient_line(c, header_x, header_y - 5, header_w, 2)

    # === Navigation Placeholders ===
    nav_items = ["Home", "Platform", "Resources", "Book a Demo", "Login"]
    c.setFont("Helvetica", 11)
    nav_spacing = 80
    start_x = header_x + header_w - (len(nav_items) * nav_spacing) - 25
    for i, item in enumerate(nav_items):
        c.setFillColor(TEXT_GRAY)
        c.drawString(start_x + i * nav_spacing, header_y + 17, item)

    # === Footer label ===
    c.setFont("Helvetica", 9)
    c.setFillColor(colors.gray)
    c.drawCentredString(PAGE_WIDTH / 2, 25, "Digiai Carbon CBAM Platform – Landing Page Mock (v3)")

    c.showPage()
    c.save()
    print("✅ Landing page PDF with subtle nav placeholders created: Digiai_Carbon_Landing_v3.pdf")


if __name__ == "__main__":
    create_landing_page()