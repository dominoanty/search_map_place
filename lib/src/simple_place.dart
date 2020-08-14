part of search_map_place;

class SimplePlace {
  final String address;
  final LatLng latLng;

  SimplePlace({
    this.address,
    this.latLng
  });

  static Future<SimplePlace> fromPlace(Place place) async {
    var geolocation;
    var coordinates;

      geolocation = await place.geolocation;
      coordinates = geolocation.coordinates;


    return SimplePlace(
      address: place.description,
      latLng: LatLng(coordinates.latitude, coordinates.longitude)
    );
  }

}