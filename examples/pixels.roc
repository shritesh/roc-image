app "example"
    packages { 
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        image: "../package/main.roc",
    }
    imports [image.Image, pf.Task, pf.File, pf.Path]
    provides [main] to pf

main =
    Image.new 2 2 
    |> Result.try \image -> Image.set image 0 0 (255, 0, 0, 255)
    |> Result.try \image -> Image.set image 0 1 (0, 255, 0, 255)
    |> Result.try \image -> Image.set image 1 0 (0, 0, 255, 255)
    |> Result.try \image -> Image.set image 1 1 (255, 255, 255, 255)
    |> Result.map Image.toPNG
    |> Task.fromResult
    |> Task.await \bytes -> File.writeBytes (Path.fromStr "pixels.png") bytes
    |> Task.onErr \_ -> crash "File write error"
