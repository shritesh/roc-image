# roc-image

An image library that supports exporting to PNG.

## Example

```roc
Image.new 3 1 
|> Result.try \image -> Image.set image 0 0 (255, 0, 0, 255)
|> Result.try \image -> Image.set image 1 0 (0, 255, 0, 255)
|> Result.try \image -> Image.set image 2 0 (0, 0, 255, 255)
|> Result.map Image.toPNG
```