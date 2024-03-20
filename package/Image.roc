## # Image
##
## A simple image package that supports exporting to uncompressed PNG.
##
## ## Example
## To create a simple 3-pixel image with red, green and blue colors:
## ```
## Image.new 3 1
## |> Result.try \image -> Image.set image 0 0 (255, 0, 0, 255)
## |> Result.try \image -> Image.set image 0 1 (0, 255, 0, 255)
## |> Result.try \image -> Image.set image 0 2 (0, 0, 255, 255)
## |> Result.map Image.toPNG
## ```
interface Image
    exposes [Image, Pixel, new, get, set, toPNG]
    imports []

## A pixel is a `(U8, U8, U8, U8)` tuple of red, green, blue and alpha color values.
Pixel : (U8, U8, U8, U8)

## A type that represents an image.
Image := { width : U32, height : U32, pixels : List (List Pixel) }

## Returns an image filled with transparent pixels of the given `width` and `height` dimensions.
##
## Returns `Err InvalidSize` if either of the dimension is `0`.
new : U32, U32 -> Result Image [InvalidSize]
new = \width, height ->
    if width == 0 || height == 0 then
        Err InvalidSize
    else
        pixels =
            (0, 0, 0, 0)
            |> List.repeat (Num.intCast width)
            |> List.repeat (Num.intCast height)
        @Image { width, height, pixels } |> Ok

## Returns the `Pixel` value at the `x` and `y` coordinates.
##
## Returns `Err OutOfBounds` if either of the coordinate is greater than the image dimensions.
get : Image, U32, U32 -> Result Pixel [OutOfBounds]
get = \@Image img, x, y ->
    row <- List.get img.pixels (Num.intCast y) |> Result.try
    List.get row (Num.intCast x)

## Sets the `pixel` value at the `x` and `y` coordinates.
##
## Returns `Err OutOfBounds` if either of the coordinate is greater than the image dimensions.
set = \@Image img, x, y, pixel ->
    if x >= img.width || y >= img.height then
        Err OutOfBounds
    else
        pixels = List.update img.pixels (Num.intCast y) (\row -> List.set row (Num.intCast x) pixel)
        @Image { img & pixels } |> Ok

## Returns the PNG file contents for the `Image`.
toPNG : Image -> List U8
toPNG = \@Image img ->
    pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    chunk = \name, body ->
        contents =
            Str.toUtf8 name
            |> List.concat body

        toU8 (Num.intCast (List.len body))
        |> List.concat contents
        |> List.concat (toU8 (crc32 contents))

    header =
        toU8 img.width
        |> List.concat (toU8 img.height)
        |> List.append 8 # bits per channel
        |> List.append 6 # alpha & rgb
        |> List.concat [0, 0, 0] # compression method, filter, non-interlaced

    imageData =
        List.mapWithIndex img.pixels \row, idx ->
            row
            |> List.joinMap \(r, g, b, a) -> [r, g, b, a] 
            |> List.concat (if Num.intCast (idx + 1) == img.height then [] else [0]) # add a null byte between rows
        |> List.join 
        |> List.prepend 0 # no compression dictionary here

    blocks =
        List.chunksOf imageData (Num.intCast Num.maxU16)

    deflated =
        block, idx <- List.mapWithIndex blocks
        List.len block
        |> Num.intCast
        |> toU8BothEndian 
        |> List.prepend (if idx + 1 == List.len blocks then 1 else 0) # whether there are more blocks remaining
        |> List.concat block

    data =
        [0x78, 0x01] # uncompressed blocks
        |> List.concat (List.join deflated)
        |> List.concat (toU8 (adler32 imageData))

    pngSignature
    |> List.concat (chunk "IHDR" header)
    |> List.concat (chunk "IDAT" data)
    |> List.concat (chunk "IEND" [])

toU8 : U32 -> List U8
toU8 = \u32 -> [
    u32
    |> Num.shiftRightZfBy 24
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u32
    |> Num.shiftRightZfBy 16
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u32
    |> Num.shiftRightZfBy 8
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u32
    |> Num.bitwiseAnd 255
    |> Num.intCast,
]

# weird AF
toU8BothEndian : U16 -> List U8
toU8BothEndian = \u16 -> [
    u16
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u16
    |> Num.shiftRightZfBy 8
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u16
    |> Num.bitwiseNot
    |> Num.bitwiseAnd 255
    |> Num.intCast,
    u16
    |> Num.bitwiseNot
    |> Num.shiftRightZfBy 8
    |> Num.bitwiseAnd 255
    |> Num.intCast,
]

crc32 : List U8 -> U32
crc32 = \input ->
    polynomial = 0xedb88320

    # This should be a static table
    crc = \byte ->
        v, _ <- List.range { start: At 0, end: Before 8 } |> List.walk (Num.intCast byte)
        c = Num.shiftRightZfBy v 1
        if Num.bitwiseAnd v 1 == 1 then
            Num.bitwiseXor c polynomial
        else
            c

    final =
        acc, byte <- List.walk input 0xFFFFFFFF

        Num.bitwiseAnd acc 0xFF
        |> Num.intCast
        |> Num.bitwiseXor byte
        |> crc
        |> Num.bitwiseXor (Num.shiftRightZfBy acc 8)

    Num.bitwiseXor final 0xFFFFFFFF

adler32 : List U8 -> U32
adler32 = \bytes ->
    adler : U32
    adler = 65521

    init : (U32, U32)
    init = (1, 0)

    (x, y) =
        (a, b), byte <- List.walk bytes init
        aNext = (a + Num.intCast byte) % adler
        bNext = (b + aNext) % adler
        (aNext, bNext)

    Num.shiftLeftBy y 16
    |> Num.bitwiseOr x
