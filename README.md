tisTree Markup Language
=======================

A markup language for making tisTree comics: http://sbboard.com/tistree/

### __Reference__
##### __gif__ attributes
* _name_ of the gif. Translates to _src_ attribute of img, plus the ".gif" extension (so you don't need to add this yourself)
* _x_ and _y_ coordinates on page
* _style_ of the area surrounding the gif in css
* Transformation attributes generate new gifs, which are linked to in the generated html. Since it uses ImageMagick, the arguments mostly resemble ImageMagick arguments:
  * _prescale_ scales the image by a percentage. This occurs before any other transformation (to avoid blockiness when it's not desired)
  * _flip_ flips the image on the x or y axes. Valid inputs are "x", "y", and "xy"
  * _delay_ changes the delay between animation frames. Valid inputs are in the form of a single number (the delay in "ticks"), or the form axb (where _a_ is the number of ticks delay and _b_ is the number of ticks in a second)
  * _rotate_ rotates the image
  * _brightness_ sets the brightness of the image as a percentage
  * _saturation_ sets the saturation
  * _hue_ sets the hue
  * _scale_ scales the image by a percentage. This occurs after all other transformations.
* _crop_ sets cropping in the format "width height x-offset y-offset"

##### __dlg__ attributes
* _x_ and _y_ coordinates on page
* _style_ in css
* _font_ in the format "font, size"

##### __rect__ attributes
* _x_ and _y_ coordinates on page
* _style_ in css
* _w_ and _h_ for the width and the height
* _color_ of the rectangle

##### __itri__ (isoceles triangle) attributes
* _type_ of isoceles triangle. Valid inputs are "up", "down", "left", "right"
* _x_, _y_, _color_
* _size_ of the triangle

##### __rtri__ (right triangle) attributes
* _type_ of the right triangle. Valid inputs are "up left", "up right", "down left", "down right"
* _x_, _y_, _size_, _color_

##### __trap__ (trapezoid) attributes
* valid _type_ inputs: "up", "down", "left", "right"
* _x_, _y_, _color_
* _w_ and _h_ for the width and the height. These can behave oddly

##### Other simple shapes
The following work identically to _ltri_ and _rtri_: _bowtie_, _pac_, _pgm_ (parallelogram), _rhom_ (rhombus)
