# iosMathText
Show text with beautifully rendered math equations in your iOS app!

This package leverages the power of <a href="https://github.com/kostub/iosMath">iosMath</a> to create `iosMathTextView` and `iosMathLabel`. These views process text with LaTeX math code and turns it into something like this: 

<img width="264" height="585" alt="equationsolve" src="https://github.com/user-attachments/assets/774a8ed5-b717-47db-8d20-4f065394b773" />

### Compatible with Markdown parsers

This package is designed and tested to work together with other text parsers, like HTML or Markdown parsers, to create rich text. Below is an example of Markdown code parsed with <a href="https://github.com/chrisdhaan/CDMarkdownKit">CMarkdownKit</a>. As you can see it is also dark mode compatible:

<img width="403" height="874" alt="Simulator Screenshot - iPhone 17 - 2026-06-13 at 20 45 56" src="https://github.com/user-attachments/assets/0b2a7a11-bdc8-4607-9324-331420a97f23" />
<img width="403" height="874" alt="Simulator Screenshot - iPhone 17 - 2026-06-13 at 22 12 01" src="https://github.com/user-attachments/assets/66d80dd3-c500-4de7-afd1-64b17137d25a" />

## Installation

First install this package through SPM using the Github url `https://github.com/Janneman84/iosMathText`. Make sure the library is linked to the target.

Then all you have to do is add `import iosMathText` and `import iosMath` and you should be able to access `iosMathText` and `iosMathLabel`.

## Usage example

```swift
import iosMathText
import iosMath // To access font name consts
```
```swift
/*
  Instance an iosMathTextView and/or iosMathLabel and add it to your UI.
  These are subviews of UITextView and UILabel and add one extra method: setMathFont()
  Make sure call this before setting the text.
*/

let mathText = "To solve the equation \\(5x^2 = 100\\),\n\n\\[5x^2 = 100\\]\n\n\\[\\frac{5x^2}{5} = \\frac{100}{5}\\]\n\n\\[x^2 = 20\\]\n\nNow, to solve for \\(x\\), you take the square root of both sides. Remember, when you take the square root of both sides of an equation, you must consider both the positive and negative root solutions:\n\n\\[x = \\pm\\sqrt{20}\\]\n\nSimplifying the square root of 20, knowing that \\(20 = 4 \\times 5\\) and \\(\\sqrt{4}\\) is 2, we get:\n\n\\[x = \\pm 2\\sqrt{5}\\]"

iosMathTextView.setMathFont(name: MTFontNameLatinModern, inlineScale: 1.1, displayScale: 1.2)
iosMathTextView.text = mathText
        
iosMathLabel.setMathFont(name: MTFontNameNewComputerModern, inlineScale: 15, displayScale: 20)
iosMathLabel.text = mathText
```
The scale params let you choose the font size of the equation relative to the font size of the text. However a value over 5 will treated as an absolute size.

### Preparsing for e.g. Markdown parsers
Other parsers may break LaTeX codes inside your string. To prevent this you may call `preparseMath()` on the (attributed) string. This will base64 encode the LaTeX codes in the string to keep them save. The iosMathText parser will decode this automatically.

This is an example to combine iosMathText with <a href="https://github.com/chrisdhaan/CDMarkdownKit">CMarkdownKit</a>
```swift
let latexMarkdownString = ...

let mdParser = CDMarkdownParser(fontColor: .label) // set .label for dark mode compatibility
mdParser.squashNewlines = false
let preparsedString = latexMarkdownString.preparseMath()
let parsedAttributedString = mdParser.parse(preparsedString)
iosMathTextView.attributedText = parsedAttributedString
```

So first preparse, then parse, then set to `iosMathTextView`/`iosMathTextLabel`.
