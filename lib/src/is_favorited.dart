import 'dart:async';

class IsFavorited {

  StreamController<bool> _controller;


  IsFavorited() {
    _controller = StreamController<bool>.broadcast();
  }

  dispose() {
    _controller.close();
  }

  set state(x) => _controller.add(x);

  get stream => _controller.stream;
}