# A simple scanline renderer for Roc's logo.
app "example"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        image: "../package/main.roc",
    }
    imports [image.Image, pf.Task, pf.File, pf.Path]
    provides [main] to pf

# Adapted from the SVG in Roc's homepage
rocLogo =
    logoDark = (108, 59, 220) # 6c3bdc
    logoLight = (138, 102, 222) # 8a66de

    Graphics 51.0 53.0 [
        Polygon logoDark [
            Point 23.6751 22.7086,
            Point 17.655 53.0,
            Point 27.4527 45.2132,
            Point 26.4673 39.3424,
        ],
        Polygon logoLight [
            Point 37.2438 19.0101,
            Point 44.0315 26.3689,
            Point 45.0 22.0,
            Point 45.9665 16.6324,
        ],
        Polygon logoLight [
            Point 23.8834 3.21052,
            Point 0.0 0.0,
            Point 23.6751 22.7086,
        ],
        Polygon logoLight [
            Point 44.0315 26.3689,
            Point 23.6751 22.7086,
            Point 26.4673 39.3424,
        ],
        Polygon logoDark [
            Point 50.5 22.0,
            Point 45.9665 16.6324,
            Point 45.0 22.0,
        ],
        Polygon logoDark [
            Point 23.6751 22.7086,
            Point 44.0315 26.3689,
            Point 37.2438 19.0101,
            Point 23.8834 3.21052,
        ],
    ]

scale = 10.0

# List of (x0, x1), (x1, x2), ... , (xn-1, xn), (xn, x0) elements
pairs = \items ->
    when items is
        [] | [_] -> [] # need two elements
        [first, .. as rest] ->
            (final, acc) = List.walk rest (first, []) \(last, list), elem -> (elem, List.append list (last, elem))
            List.append acc (final, first)

# Only keep the biggest and smallest x for each y
insert = \scanlines, (x, y) ->
    newVal =
        when Dict.get scanlines y is
            Err KeyNotFound -> One x
            Ok (One one) if x < one -> Two x one
            Ok (One one) if x > one -> Two one x
            Ok (Two one two) if x == one || x == two -> Two one two
            Ok (Two one two) if x < one -> Two x two
            Ok (Two one two) if x > two -> Two one x
            Ok val -> val

    Dict.insert scanlines y newVal

interpolateY = \scanlines, Point x1 y1, Point x2 y2 ->
    if x1 == x2 then
        insert scanlines (Num.floor (x1 * scale), Num.floor (y1 * scale))
    else
        d = (y2 - y1) / (x2 - x1) / scale
        (_, final) =
            (y, acc), x <- List.range { start: At (Num.floor (x1 * scale)), end: At (Num.floor (x2 * scale)) } |> List.walk (y1, scanlines)
            (y + d, insert acc (x, Num.floor (y * scale)))
        final

interpolateX = \scanlines, Point x1 y1, Point x2 y2 ->
    if y1 == y2 then
        insert scanlines (Num.floor (x1 * scale), Num.floor (y1 * scale))
    else
        d = (x2 - x1) / (y2 - y1) / scale
        (_, final) =
            (x, acc), y <- List.range { start: At (Num.floor (y1 * scale)), end: At (Num.floor (y2 * scale)) } |> List.walk (x1, scanlines)
            (x + d, insert acc (Num.floor (x * scale), y))
        final

scanline = \scanlines, (p1, p2) ->
    (Point x1 y1) = p1
    (Point x2 y2) = p2

    if Num.absDiff x2 x1 > Num.absDiff y2 y1 then
        if x1 > x2 then
            interpolateY scanlines p2 p1
        else
            interpolateY scanlines p1 p2
    else 
        if y1 > y2 then
            interpolateX scanlines p2 p1
        else
            interpolateX scanlines p1 p2

toImage = \Graphics width height polygons ->
    imgWidth = (Num.floor (scale * width) + 1)
    imgHeight = (Num.floor (scale * height) + 1)

    init <- Image.new imgWidth imgHeight |> Result.try

    image, (Polygon (r, g, b) points) <- List.walkTry polygons init
    scanlines = pairs points |> List.walk (Dict.empty {}) scanline
    img, (y, x) <- scanlines |> Dict.toList |> List.walkTry image

    when x is
        One one -> Image.set img one y (r, g, b, 255)
        Two one two ->
            im, x0 <- List.range { start: At one, end: At two } |> List.walkTry img
            Image.set im x0 y (r, g, b, 255)

main =
    rocLogo
    |> toImage
    |> Result.map Image.toPNG
    |> Task.fromResult
    |> Task.await \png -> File.writeBytes (Path.fromStr "logo.png") png
    |> Task.onErr \_ -> crash "File write error"
