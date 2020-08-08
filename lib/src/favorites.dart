part of search_map_place;

class FavoriteItem  with ListedSearchItem{
  String address;
  String tag;
  LatLng latLng;

  FavoriteItem({
    this.address,
    this.tag,
    this.latLng
  });

}