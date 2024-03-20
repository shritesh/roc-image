# roc-image

A simple image library that supports exporing to (uncompressed) PNG.

## Example

```roc
Image.new 3 1 
|> Result.try \image -> Image.set image 0 0 (255, 0, 0, 255)
|> Result.try \image -> Image.set image 0 1 (0, 255, 0, 255)
|> Result.try \image -> Image.set image 0 2 (0, 0, 255, 255)
|> Result.map Image.toPNG
```