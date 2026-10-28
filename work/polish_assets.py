"""Measured crops from the approved concept art; never infer a uniform source grid.
Run from any directory. Runtime atlases have exact 64px cells and a fixed foot anchor.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import json, random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/art'
env = Image.open(ROOT/'work/generated/environment_master.png').convert('RGBA')
chars = Image.open(ROOT/'work/generated/explorers_master.png').convert('RGBA')
NEAR = Image.Resampling.NEAREST

def save_sheet(path, frames, columns):
    w,h = frames[0].size
    out = Image.new('RGBA',(w*columns,h*((len(frames)+columns-1)//columns)))
    for i,f in enumerate(frames): out.alpha_composite(f,((i%columns)*w,(i//columns)*h))
    path.parent.mkdir(parents=True,exist_ok=True)
    out.save(path)
    return out

def opaque_crop(box,size):
    im=env.crop(box).resize(size,NEAR)
    im.putalpha(255)
    return im

# Interior boundaries exclude the isolated concept tile's outline/drop shadow.
floor=opaque_crop((31,59,153,182),(64,64))
floors=[]
for i in range(4):
    f=floor.copy()
    d=ImageDraw.Draw(f)
    d.line((0,0,63,0),fill='#151f21',width=2)
    d.line((0,0,0,63),fill='#151f21',width=2)
    if i==1: d.line([(35,22),(30,28),(34,34),(29,41)],fill='#101a1c',width=1)
    if i==2:
        for x,y in [(6,10),(8,12),(9,9),(12,13),(6,15)]: d.rectangle((x,y,x+1,y+1), fill='#3a4930')
    if i==3: d.line([(46,45),(50,47),(53,46)],fill='#53605b')
    floors.append(f)
floors += [opaque_crop((647,840,766,964),(64,64)),opaque_crop((794,840,914,964),(64,64))]
save_sheet(OUT/'environment/tiles/polished_floor.png',floors,6)

# N/E/S/W connection bits. Every tile is a complete cell, with a top cap;
# exposed south edges receive a stone face and Greek-key frieze.
top=Image.new('RGBA',(64,64),'#898779')
noise=random.Random(712)
td=ImageDraw.Draw(top)
for y in range(0,64,2):
    for x in range(0,64,2):
        tone=noise.choice(['#898779','#898779','#8d8b7d','#838174','#939080'])
        td.rectangle((x,y,x+1,y+1),fill=tone)
for x,y in [(9,12),(44,8),(23,41),(53,54),(6,55)]:
    td.line([(x,y),(x+3,y+2),(x+2,y+5)],fill='#6a6d60')
    td.point((x+4,y+1),fill='#aaa591')
face=opaque_crop((494,98,615,175),(64,23))
wall_tiles=[]
for mask in range(16):
    im=top.copy(); d=ImageDraw.Draw(im)
    d.line((0,31,63,31),fill='#827d6b',width=1)
    d.line((31,0,31,30),fill='#7c7765',width=1)
    d.line((15,32,15,63),fill='#827d6b',width=1)
    if not mask&1:
        d.rectangle((0,0,63,3),fill='#302e29')
        d.line((3,4,60,4),fill='#c5b992',width=2)
    if not mask&8:
        d.rectangle((0,0,3,63),fill='#34332d')
        d.line((4,4,4,60),fill='#b9ad8c',width=2)
    if not mask&2:
        d.rectangle((60,0,63,63),fill='#292c29')
        d.line((59,4,59,60),fill='#706a57',width=2)
    if not mask&4:
        im.paste(face,(0,41))
        d=ImageDraw.Draw(im)
        d.line((0,40,63,40),fill='#d0c09a',width=2)
        d.line((0,63,63,63),fill='#131b1b',width=2)
    wall_tiles.append(im)
save_sheet(OUT/'environment/tiles/connected_walls.png',wall_tiles,16)

# Preserve hand-drawn props, without neighboring tiles or nonuniform bands.
prop_boxes=[(18,538,166,670),(184,553,302,670),(336,540,467,670),
 (491,539,622,670),(498,369,603,520),(1110,365,1242,521),
 (334,680,470,820),(793,684,907,820),(648,682,777,821),
 (28,1070,166,1226),(489,1070,625,1226),(969,1070,1104,1226)]
props=[]
for box in prop_boxes:
    obj=env.crop(box); obj=obj.crop(obj.getbbox())
    scale=min(60/obj.width,60/obj.height)
    obj=obj.resize((round(obj.width*scale),round(obj.height*scale)),NEAR)
    canvas=Image.new('RGBA',(64,64));canvas.alpha_composite(obj,((64-obj.width)//2,62-obj.height));props.append(canvas)
save_sheet(OUT/'environment/props/polished_props.png',props,12)

y_bands=[(27,160),(163,291),(298,430),(434,570),(626,777),(780,918),(925,1063),(1065,1208)]
x_bands=[(30,136),(137,235),(236,330),(331,433),(434,535)]
records=[]
def pose(row,col,scale):
    xa,xb=x_bands[col];ya,yb=y_bands[row]
    obj=chars.crop((xa,ya,xb,yb))
    # Strip faint alpha residue; preserve the entire character and equipment.
    obj.putalpha(obj.getchannel('A').point(lambda a: a if a>=70 else 0))
    bbox=obj.getbbox(); assert bbox
    # Anchor on the hood, not the asymmetrical cape/weapon silhouette.
    head=obj.getchannel('A').crop((0,bbox[1],obj.width,bbox[1]+34)).getbbox()
    anchor=(head[0]+head[2])/2
    resized=obj.resize((round(obj.width*scale),round(obj.height*scale)),NEAR)
    frame=Image.new('RGBA',(64,64))
    # Use the actual resampled alpha boundary, avoiding a one-pixel rounding wobble.
    frame.alpha_composite(resized,(round(32-anchor*scale),60-resized.getbbox()[3]))
    records.append({'row':row,'pose':col,'source':[xa,ya,xb,yb],'scale':scale,'foot':[32,60]})
    return frame

for who in range(2):
    scale=0.405 if who==0 else 0.375
    rows=[[pose(who*4+r,c,scale) for c in range(5)] for r in range(4)]
    base=OUT/'characters'/('explorer_a' if who==0 else 'explorer_b')
    name=base.name
    for anim,indices in [('idle',[0]*4),('walk',[1,2,3,4,3,2]),('attack',[0]*6),('hurt',[0]*2)]:
        save_sheet(base/f'{name}_{anim}.png',[rows[r][i] for r in range(4) for i in indices],len(indices))
    save_sheet(ROOT/'work'/f'{name}_alignment.png',[rows[r][i] for r in range(4) for i in range(5)],5).resize((640,512),NEAR).save(ROOT/'work'/f'{name}_alignment_large.png')
(OUT/'sprite_crop_manifest.json').write_text(json.dumps(records,indent=2))

# Other concept-sheet bands also have unequal spacing. Keep effects out of idle loops.
creatures=Image.open(ROOT/'work/generated/creatures_master.png').convert('RGBA')
def creature(box,size,scale,foot):
    im=creatures.crop(box)
    im.putalpha(im.getchannel('A').point(lambda a:a if a>=65 else 0))
    bbox=im.getbbox()
    im=im.crop(bbox)
    im=im.resize((round(im.width*scale),round(im.height*scale)),NEAR)
    f=Image.new('RGBA',(size,size));f.alpha_composite(im,((size-im.width)//2,foot-im.height))
    return f
owl=[creature(b,64,0.39,54) for b in [(426,769,546,892),(550,775,677,895),(683,777,795,892)]]
save_sheet(OUT/'characters/companion/owl_animation.png',[owl[i] for i in [0,1,2,1,0,1,2,1,0,1]],10)
spirits=[creature(b,64,0.24,61) for b in [(13,9,134,237),(135,10,254,238),(255,10,374,241),(376,10,476,242)]]
save_sheet(OUT/'enemies/spirits/spirit_animation.png',[spirits[i] for i in [0,1,2,3,2,1,0,1,2,1]],10)
mino=[creature(b,128,0.43,122) for b in [(12,240,224,511),(231,240,434,511),(436,240,630,511),(635,241,813,510)]]
save_sheet(OUT/'enemies/minotaur/minotaur_animation.png',[mino[i] for i in [0,1,0,1,0,1]+[2,3]*6],18)
athena=[creature(b,128,0.34,123) for b in [(9,898,210,1227),(210,901,357,1222),(359,900,491,1225),(494,906,643,1226),(644,901,812,1227),(999,892,1253,1234)]]
save_sheet(OUT/'characters/companion/athena_reveal.png',[athena[i] for i in [0,0,1,1,2,2,3,3,4,4,5,5]],12)

# Small, unambiguous item silhouettes; no environmental atlas fragments in pickups.
icons=[]
for i in range(8):
    icon=Image.new('RGBA',(32,32));d=ImageDraw.Draw(icon)
    if i<3:
        color=['#aaa38a','#9aaeb5','#b99a58'][i]
        d.polygon([(9,5),(13,7),(19,7),(23,5),(28,12),(23,16),(23,27),(9,27),(9,16),(4,12)],fill=color,outline='#293c43',width=2)
        d.line((16,10,16,24),fill='#e3d7b1',width=2)
    elif i==5:
        d.arc((4,3,27,29),-80,80,fill='#c2a367',width=3);d.line((18,4,18,28),fill='#e7dfbc');d.line((5,16,29,16),fill='#e7dfbc',width=2)
    elif i==7:
        d.rectangle((3,12,29,28),fill='#171e21')
        d.rounded_rectangle((4,7,27,25),radius=3,fill='#745332',outline='#c0a16a',width=2)
        d.rectangle((5,15,26,16),fill='#272b27')
        d.line((9,8,9,24),fill='#d1b479',width=2)
        d.line((23,8,23,24),fill='#b49a61',width=2)
        d.rectangle((14,14,18,19),fill='#ddc68f',outline='#262e2b')
        d.point((16,16),fill='#192321')
    else:
        d.polygon([(16,3),(25,13),(16,28),(7,13)],fill='#72cdd0',outline='#c7f1e3',width=2)
        d.line((16,5,12,14,16,24),fill='#d9ffff',width=2)
    icons.append(icon)
save_sheet(OUT/'ui/item_icons.png',icons,8)
print('Built connected wall atlas, seamless floors, measured props, and anchored explorer sheets.')
