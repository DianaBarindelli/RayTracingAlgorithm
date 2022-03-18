import unittest
import std/streams
import "../src/hdrimage.nim"
import "../src/color.nim"

var hdr = newHdrImage(1000,100)
assert hdr.valid_coordinates(1,1)
#assert hdr.valid_coordinates(-1,1) # correctly failed
#assert hdr.valid_coordinates(21,1) # correctly failed
#assert hdr.valid_coordinates(1,11) # correctly failed