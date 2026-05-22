from PIL import Image, ImageChops

def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im

try:
    img = Image.open('assets/icon/app_icon.png').convert('RGB')
    # Let's just crop out the white border by finding the black area
    # Or explicitly crop it if it's a known white border. 
    # Alternatively, find the bounding box of the non-white area.
    
    # Create a white background to compare against
    bg = Image.new(img.mode, img.size, (255, 255, 255))
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()
    if bbox:
        cropped = img.crop(bbox)
        # Resize back to 1024x1024 to keep it high res
        cropped = cropped.resize((1024, 1024), Image.Resampling.LANCZOS)
        cropped.save('assets/icon/app_icon.png')
        print("Successfully cropped white borders!")
    else:
        print("No white border found.")
except Exception as e:
    print(f"Error: {e}")
