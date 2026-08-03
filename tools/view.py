import sys
from PIL import Image
for t in sys.argv[1:]:
    im = Image.open("s%s.bmp" % t)
    im = im.resize((im.width*5, im.height*5), Image.NEAREST)
    im.save("big%s.png" % t)
    print(t, im.size)
