import 'package:flame/components.dart';

class SnakeAssetsClearCode {
  late final Sprite headUp, headDown, headLeft, headRight;
  late final Sprite tailUp, tailDown, tailLeft, tailRight;
  late final Sprite bodyHorizontal, bodyVertical;
  late final Sprite bodyTopLeft, bodyTopRight, bodyBottomLeft, bodyBottomRight;

  Future<void> load(Images images) async {
    headUp    = Sprite(await images.load('sprites/clearcode/head_up.png'));
    headDown  = Sprite(await images.load('sprites/clearcode/head_down.png'));
    headLeft  = Sprite(await images.load('sprites/clearcode/head_left.png'));
    headRight = Sprite(await images.load('sprites/clearcode/head_right.png'));

    tailUp    = Sprite(await images.load('sprites/clearcode/tail_up.png'));
    tailDown  = Sprite(await images.load('sprites/clearcode/tail_down.png'));
    tailLeft  = Sprite(await images.load('sprites/clearcode/tail_left.png'));
    tailRight = Sprite(await images.load('sprites/clearcode/tail_right.png'));

    bodyHorizontal  = Sprite(await images.load('sprites/clearcode/body_horizontal.png'));
    bodyVertical    = Sprite(await images.load('sprites/clearcode/body_vertical.png'));
    bodyTopLeft     = Sprite(await images.load('sprites/clearcode/body_topleft.png'));
    bodyTopRight    = Sprite(await images.load('sprites/clearcode/body_topright.png'));
    bodyBottomLeft  = Sprite(await images.load('sprites/clearcode/body_bottomleft.png'));
    bodyBottomRight = Sprite(await images.load('sprites/clearcode/body_bottomright.png'));
  }
}
