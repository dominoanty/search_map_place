part of search_map_place;

class SearchMapPlaceWidget extends StatefulWidget {
  SearchMapPlaceWidget({
    @required this.apiKey,
    this.placeholder = 'Dominoanty\'s Search',
    this.icon = Icons.search,
    this.hasClearButton = true,
    this.clearIcon = Icons.clear,
    this.iconColor = Colors.blue,
    this.searchTextController,
    this.onSelected,
    this.onFavoriteSelected,
    this.onSearch,
    this.onFavorited,
    this.language = 'en',
    this.location,
    this.radius,
    this.strictBounds = false,
    this.placeType,
    this.darkMode = false,
    this.favorites,
    this.recents,
    this.focusNode,
    this.key,
  })  : assert((location == null && radius == null) || (location != null && radius != null)),
        super(key: key) {
    if(this.focusNode == null) {
      this.focusNode = new FocusNode();
    }
  }

  final Key key;

  /// API Key of the Google Maps API.
  final String apiKey;

  /// Placeholder text to show when the user has not entered any input.
  final String placeholder;

  /// The callback that is called when one Place is selected by the user.
  final void Function(Place place) onSelected;

  /// The callback that is called when the user taps on the search icon.
  final void Function(Place place) onSearch;

  /// Language used for the autocompletion.
  ///
  /// Check the full list of [supported languages](https://developers.google.com/maps/faq#languagesupport) for the Google Maps API
  final String language;

  /// The point around which you wish to retrieve place information.
  ///
  /// If this value is provided, `radius` must be provided aswell.
  final LatLng location;

  /// The distance (in meters) within which to return place results. Note that setting a radius biases results to the indicated area, but may not fully restrict results to the specified area.
  ///
  /// If this value is provided, `location` must be provided aswell.
  ///
  /// See [Location Biasing and Location Restrict](https://developers.google.com/places/web-service/autocomplete#location_biasing) in the documentation.
  final int radius;

  /// Returns only those places that are strictly within the region defined by location and radius. This is a restriction, rather than a bias, meaning that results outside this region will not be returned even if they match the user input.
  final bool strictBounds;

  /// Place type to filter the search. This is a tool that can be used if you only want to search for a specific type of location. If this no place type is provided, all types of places are searched. For more info on location types, check https://developers.google.com/places/web-service/autocomplete?#place_types
  final PlaceType placeType;

  /// The initial icon to show in the search box
  final IconData icon;

  /// Makes available "clear textfield" button when the user is writing.
  final bool hasClearButton;

  /// The icon to show indicating the "clear textfield" button
  final IconData clearIcon;

  /// The color of the icon to show in the search box
  final Color iconColor;

  /// Enables Dark Mode when set to `true`. Default value is `false`.
  final bool darkMode;

  /// Lets the user override the text shown in the Text box. This can be useful while integrating with the
  /// Google Maps Flutter widget.
  final SearchTextController searchTextController;

  final List<FavoriteItem> favorites;

  final List<RecentItem> recents;

  FocusNode focusNode;

  final Function(SimplePlace simplePlace) onFavorited;

  /// Callback for when user selects favorite item or recent item
  final Function(ListedSearchItem searchItem) onFavoriteSelected;

  @override
  _SearchMapPlaceWidgetState createState() => _SearchMapPlaceWidgetState();
}

class _SearchMapPlaceWidgetState extends State<SearchMapPlaceWidget> with TickerProviderStateMixin {
  TextEditingController _textEditingController = TextEditingController();
  AnimationController _animationController;
  // SearchContainer height.
  Animation _containerHeight;
  // Place options opacity.
  Animation _listOpacity;

  // This will be set true if text comes from other source than the user
  bool _dirtiedByOtherController = false;

  // To handle valid states (when edited from other source or when clicked on
  // some address)
  bool _isTouched = false;
  bool _isValid = false;


  // To store the place that is currently being displayed
  SimplePlace _currentPlace;

  List<dynamic> _placePredictions = [];
  bool _isEditing = false;
  Geocoding geocode;

  String _tempInput = "";
  String _currentInput = "";

  IsFavorited _isFavorited;

  CrossFadeState _crossFadeState;

  @override
  void initState() {
    _isFavorited = IsFavorited();
    geocode = Geocoding(apiKey: widget.apiKey, language: widget.language);
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _containerHeight = Tween<double>(begin: 55, end: 364).animate(
      CurvedAnimation(
        curve: Interval(0.0, 0.5, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );
    _listOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );

    _textEditingController.addListener(_autocompletePlace);
    customListener();

    if (widget.hasClearButton) {
      widget.focusNode.addListener(() async {
        if (widget.focusNode.hasFocus) {
          setState(() => _crossFadeState = CrossFadeState.showSecond);
          _animationController.forward();
          log('got focus on search');
        }
        else {
          setState(() => _crossFadeState = CrossFadeState.showFirst);
          _animationController.reverse();
          log('lost focus on search');
        }
      });
      _crossFadeState = CrossFadeState.showFirst;
    }

    widget.searchTextController?._addState(this);

    super.initState();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: MediaQuery.of(context).size.width * 0.9,
    child: _searchContainer(
      child: _searchInput(context),
    ),
  );

  /*
  WIDGETS
  */
  Widget _searchContainer({Widget child}) {
    return AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 0),
            height: _containerHeight.value,
            decoration: _containerDecoration(),
            child: Container(
              padding: EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0, top: 4),
                    child: child,
                  ),
                  if (_placePredictions.length > 0)
                    Opacity(
                      opacity: _listOpacity.value,
                      child: Column(
                        children: <Widget>[
                          for (var prediction in _placePredictions)
                            _placeOption(Place.fromJSON(prediction, geocode)),
                        ],
                      ),
                    ),
                  if (_placePredictions.length == 0 && widget.favorites.length > 0)
                    ...[
                      Text(
                          'Favorites',
                        textAlign: TextAlign.start,
                        style: TextStyle(color: Colors.grey),
                      ),
                      Opacity(
                        opacity: _listOpacity.value,
                        child: Column(
                          children: <Widget>[
                            ...?widget.favorites?.map(_favoriteOption),
                          ],
                        ),
                      ),
                      Divider(),
                    ],
                  if (_placePredictions.length == 0 && (widget.recents?.length ?? 0) > 0)
                    ...[
                      Text('Recents',
                        textAlign: TextAlign.start,
                        style: TextStyle(color: Colors.grey),
                      ),
                      Opacity(
                        opacity: _listOpacity.value,
                        child: Column(
                          children: <Widget>[
                            ...?widget.recents?.map(_favoriteOption),
                          ],
                        ),
                      ),
                      Divider(),
                    ]
                ],

              ),
            ),
          );
        });
  }

  Widget _searchInput(BuildContext context) {
    return Center(
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              decoration: _inputStyle(),
              controller: _textEditingController,
              onSubmitted: (_) => _selectPlace(),
              onEditingComplete: _selectPlace,
              autofocus: false,
              focusNode: widget.focusNode,
              style: TextStyle(
                fontSize: 16,
                color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
              ),
            ),
          ),
          Container(width: 15),
          if(this._isValid)
            GestureDetector(
              onTap: () {
                widget.onFavorited(_currentPlace);
              },
              child: Container(
                margin: EdgeInsets.only(right: 5),
                child: StreamBuilder(
                    stream: _isFavorited.stream,
                    initialData: false,
                    builder: (context, snapshot) {
                      return
                      Icon(
                          snapshot.data ?
                            Icons.favorite :
                            Icons.favorite_border,
                          color: Colors.red
                      );
                })),
            ),
          if (widget.hasClearButton)
            GestureDetector(
              onTap: () {
                if (_crossFadeState == CrossFadeState.showSecond) {
                  if(_textEditingController.text.length == 0) {
                    _closeSearch2();
                  }
                  _textEditingController.clear();
                  _dirtiedByOtherController = false;
                  setState(() {
                    _placePredictions = [];
                  });
                }
              },
              // child: Icon(_inputIcon, color: this.widget.iconColor),
              child: AnimatedCrossFade(
                crossFadeState: _crossFadeState,
                duration: Duration(milliseconds: 300),
                firstChild: Icon(widget.icon, color: widget.iconColor),
                secondChild: Icon(Icons.clear, color: widget.iconColor),
              ),
            ),
          if (!widget.hasClearButton) Icon(widget.icon, color: widget.iconColor)
        ],
      ),
    );
  }


  Widget _favoriteOption(ListedSearchItem favoriteItem) {
    String place = favoriteItem.address;

    return MaterialButton(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      onPressed: () => { _selectListedSearchItem(searchItem: favoriteItem) } ,
      child: ListTile(
        title: Text(
          place.length < 45 ? "$place" : "${place.replaceRange(45, place.length, "")} ...",
          style: TextStyle(
            fontSize: 14,
            color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
          ),
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 0,
        ),
      ),
    );
  }
  Widget _placeOption(Place prediction) {
    String place = prediction.description;

    return MaterialButton(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      onPressed: () => _selectPlace(prediction: prediction),
      child: ListTile(
        title: Text(
          place.length < 45 ? "$place" : "${place.replaceRange(45, place.length, "")} ...",
          style: TextStyle(
            fontSize: 14,
            color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
          ),
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 0,
        ),
      ),
    );
  }

  /*
  STYLING
  */
  InputDecoration _inputStyle() {
    return InputDecoration(
      hintText: this.widget.placeholder,
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
      hintStyle: TextStyle(
        color: widget.darkMode ? Colors.grey[100] : Colors.grey[450],
      ),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: widget.darkMode ? Colors.grey[800] : Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(6.0)),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 10)],
    );
  }

  /*
  METHODS
  */

  /// Will be called everytime the input changes. Making callbacks to the Places
  /// Api and giving the user Place options
  void _autocompletePlace() async {
    if (widget.focusNode.hasFocus) {
      setState(() {
        _currentInput = _textEditingController.text;
        _isEditing = true;
      });

      _textEditingController.removeListener(_autocompletePlace);

      if (_currentInput.length == 0) {
        touchedAndDirty(false, false);
        if (!_containerHeight.isDismissed) _closeSearch();
        _textEditingController.addListener(_autocompletePlace);
        return;
      }

      if (_currentInput == _tempInput && !_dirtiedByOtherController) {
        touchedAndDirty(true, false);
        final predictions = await _makeRequest(_currentInput);
        await _animationController.animateTo(0.5);
        setState(() => _placePredictions = predictions);
        await _animationController.forward();

        _textEditingController.addListener(_autocompletePlace);
        return;
      }

      Future.delayed(Duration(milliseconds: 500), () {
        _textEditingController.addListener(_autocompletePlace);
        if (_isEditing == true) _autocompletePlace();
      });
    }
  }

  /// API request function. Returns the Predictions
  Future<dynamic> _makeRequest(input) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=${widget.language}";
    if (widget.location != null && widget.radius != null) {
      url += "&location=${widget.location.latitude},${widget.location.longitude}&radius=${widget.radius}";
      if (widget.strictBounds) {
        url += "&strictbounds";
      }
      if (widget.placeType != null) {
        url += "&types=${widget.placeType.apiString}";
      }
    }

    final response = await http.get(url);
    final json = JSON.jsonDecode(response.body);

    if (json["error_message"] != null) {
      var error = json["error_message"];
      if (error == "This API project is not authorized to use this API.")
        error += " Make sure the Places API is activated on your Google Cloud Platform";
      throw Exception(error);
    } else {
      final predictions = json["predictions"];
      return predictions;
    }
  }

  _updateFaveIndicator(dynamic place) async {
    var address;
    if(place is ListedSearchItem) {
      address = place.address;
    }
    else if(place is Place) {
      address = place.description;
    }
    else if(place is SimplePlace) {
      address = place.address;
    }
    _isFavorited.state = widget
                          .favorites
                          .map((e) => e.address)
                          .contains(address);
  }

  _selectListedSearchItem({ListedSearchItem searchItem}) {
    touchedAndDirty(false, true);
    _textEditingController.value = TextEditingValue(
        text: searchItem.address,
        selection: TextSelection.collapsed(
        offset: searchItem.address.length,
      ),
    );

    // Makes animation
    _finishSearch();
    _updateFaveIndicator(searchItem);
    widget.onFavoriteSelected(searchItem);
  }

  /// Will be called when a user selects one of the Place options
  void _selectPlace({Place prediction}) async {
    if (prediction != null) {
      touchedAndDirty(false, true);
      _currentPlace = await SimplePlace.fromPlace(prediction);
      _textEditingController.value = TextEditingValue(
        text: prediction.description,
        selection: TextSelection.collapsed(
          offset: prediction.description.length,
        ),
      );
    } else {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Makes animation
    _finishSearch();

    // Calls the `onSelected` callback
    if (prediction is Place) widget.onSelected(prediction);

    _updateFaveIndicator(prediction);
  }

  void _finishSearch() async {
    if (!_animationController.isDismissed) await _animationController.animateTo(0.5);
    widget.focusNode.unfocus();
    setState(() {
      _placePredictions = [];
      _isEditing = false;
    });
    _animationController.reverse();
    _textEditingController.addListener(_autocompletePlace);

  }
  /// Closes the expanded search box with predictions
  void _closeSearch() async {
    touchedAndDirty(false, false);
    setState(() {
      _placePredictions = [];
      _isEditing = false;
    });
    _textEditingController.addListener(_autocompletePlace);
  }

  void _closeSearch2() async {
    touchedAndDirty(false, false);
    widget.focusNode.unfocus();
    _animationController.reverse();
  }
  /// Will listen for input changes every 0.5 seconds, allowing us to make API requests only when the user stops typing.
  void customListener() {
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() => _tempInput = _textEditingController.text);
      customListener();
    });
  }

  void touchedAndDirty(bool isTouched, bool isValid) {
    setState(() {
      this._isTouched = isTouched;
      this._isValid = isValid;
    });
  }
  @override
  void dispose() {
    _animationController.dispose();
    _textEditingController.dispose();
    _isFavorited.dispose();
    widget.focusNode.dispose();
    super.dispose();
  }


}

class SearchTextController {

  _SearchMapPlaceWidgetState _searchWidgetState;

  _addState(_SearchMapPlaceWidgetState searchWidgetState) {
    this._searchWidgetState = searchWidgetState;
  }

  bool get isAttached => _searchWidgetState != null;

  setSimplePlace(SimplePlace simplePlace) {
    _searchWidgetState._currentPlace = simplePlace;
    _searchWidgetState._updateFaveIndicator(simplePlace);
    setText(simplePlace.address);
  }

  setText(String text) {
    assert(isAttached, "SearchTextController must be attached to a SearchMapPlaceWidget");
    _searchWidgetState._dirtiedByOtherController = true;
    _searchWidgetState.touchedAndDirty(false, true);
    _searchWidgetState._isEditing = false;
    _searchWidgetState._textEditingController.value = TextEditingValue(
        text: text
    );
  }

}