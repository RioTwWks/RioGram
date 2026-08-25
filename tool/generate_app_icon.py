#!/usr/bin/env python3
"""Generate RioGram launcher PNGs (§9.9). Run: python3 tool/generate_app_icon.py"""
import struct, zlib
from pathlib import Path

def png(w,h,pixels):
    def chunk(tag,data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    raw=b''.join(b'\x00'+bytes(pixels[y]) for y in range(h))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')

def make(size,path):
    accent=(0x33,0x90,0xEC); white=(255,255,255); r=size*0.22; pixels=[]
    for y in range(size):
        row=bytearray()
        for x in range(size):
            inside=(x>=r and x<size-r) or (y>=r and y<size-r)
            if not inside:
                for cx,cy in [(r,r),(size-r,r),(r,size-r),(size-r,size-r)]:
                    if (x-cx)**2+(y-cy)**2<=r*r: inside=True
            if not inside: row.extend((0,0,0)); continue
            sx,sy=x/size*512,y/size*512; on=False
            if 145<=sx<=155 and 125<=sy<=280: on=True
            if 145<=sx<=250 and 125<=sy<=135: on=True
            if 240<=sx<=270 and 125<=sy<=185: on=True
            if 240<=sx<=270 and 175<=sy<=240: on=True
            if 190<=sx<=250 and 230<=sy<=240: on=True
            if 165<=sx<=290 and 235<=sy<=350 and (sy-235)>(sx-165)*0.55: on=True
            row.extend(white if on else accent)
        pixels.append(row)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(png(size,size,pixels)); print('wrote',path)

if __name__=='__main__':
    make(1024,'assets/icons/app_icon_1024.png'); make(432,'assets/icons/app_icon_foreground.png')
