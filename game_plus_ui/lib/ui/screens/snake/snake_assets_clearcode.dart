import 'package:flame/components.dart';
import 'package:flame/flame.dart';  // Đảm bảo import Flame

class SnakeAssetsClearCode {
  late final Sprite headUp, headDown, headLeft, headRight;
  late final Sprite tailUp, tailDown, tailLeft, tailRight;
  late final Sprite bodyHorizontal, bodyVertical;
  late final Sprite bodyTopLeft, bodyTopRight, bodyBottomLeft, bodyBottomRight;

  Future<void> load() async {
    headUp    = Sprite(await Flame.images.load('sprites/clearcode/head_up.png'));
    headDown  = Sprite(await Flame.images.load('sprites/clearcode/head_down.png'));
    headLeft  = Sprite(await Flame.images.load('sprites/clearcode/head_left.png'));
    headRight = Sprite(await Flame.images.load('sprites/clearcode/head_right.png'));

    tailUp    = Sprite(await Flame.images.load('sprites/clearcode/tail_up.png'));
    tailDown  = Sprite(await Flame.images.load('sprites/clearcode/tail_down.png'));
    tailLeft  = Sprite(await Flame.images.load('sprites/clearcode/tail_left.png'));
    tailRight = Sprite(await Flame.images.load('sprites/clearcode/tail_right.png'));

    bodyHorizontal  = Sprite(await Flame.images.load('sprites/clearcode/body_horizontal.png'));
    bodyVertical    = Sprite(await Flame.images.load('sprites/clearcode/body_vertical.png'));
    bodyTopLeft     = Sprite(await Flame.images.load('sprites/clearcode/body_topleft.png'));
    bodyTopRight    = Sprite(await Flame.images.load('sprites/clearcode/body_topright.png'));
    bodyBottomLeft  = Sprite(await Flame.images.load('sprites/clearcode/body_bottomleft.png'));
    bodyBottomRight = Sprite(await Flame.images.load('sprites/clearcode/body_bottomright.png'));
  }
}
