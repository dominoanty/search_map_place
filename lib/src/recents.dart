part of search_map_place;

class RecentItem with ListedSearchItem{
  String address;
  LatLng latLng;

  RecentItem({
  this.address,
  this.latLng,
  });
}