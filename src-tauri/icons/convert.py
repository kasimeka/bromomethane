from PIL import Image
from os import remove, rename

input_path = "128x128@2x.png"
output_path = input_path.split(".")[0] + "o.png"

def convert_to_rgba(input_path, output_path):
    img = Image.open(input_path)
    # Convert to RGBA mode
    rgba_img = img.convert('RGBA')
    rgba_img.save(output_path, 'PNG')

def verify_rgba(image_path):
    img = Image.open(image_path)
    print(f"Image mode: {img.mode}")  # Should print "RGBA"
    print(f"Number of channels: {len(img.getbands())}")  # Should print 4
    if img.mode == "RGBA" and len(img.getbands()) == 4:
        remove(input_path)
        print("old", input_path, "removed")
        rename(output_path, input_path)



convert_to_rgba(input_path, output_path)
verify_rgba(output_path)
print("done.")
