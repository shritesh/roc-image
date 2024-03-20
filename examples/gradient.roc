app "example"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        image: "../package/main.roc",
    }
    imports [image.Image, pf.Task, pf.File, pf.Path]
    provides [main] to pf

width = 1024
height = 1024

div = \n, max ->
    (Num.toFrac n / Num.toFrac max)
    |> Num.mul 255
    |> Num.floor

mapping =
    List.range { start: At 0, end: Before height }
    |> List.joinMap \y ->
        List.range { start: At 0, end: Before width }
        |> List.map \x -> (x, y, (div x width, div y height, 0, 255))

main =
    Image.new width height
    |> Result.try \image -> List.walkTry mapping image \img, (x, y, pixel) -> Image.set img x y pixel
    |> Result.map Image.toPNG
    |> Task.fromResult
    |> Task.await \bytes -> File.writeBytes (Path.fromStr "gradient.png") bytes
    |> Task.onErr \_ -> crash "File write error"
