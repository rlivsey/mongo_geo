require 'helper'

class TestGeoKitLatLng < Test::Unit::TestCase
  context "GeoKit::LatLng.to_mongo" do
    should "convert to array if latlng" do
      latlng = GeoKit::LatLng.new(1, 2)
      assert_equal [2,1], GeoKit::LatLng.to_mongo(latlng)
    end

    should "leave as array if array" do
      assert_equal([2,1], GeoKit::LatLng.to_mongo([2,1]))
    end

    should "convert to empty array if nil" do
      assert_equal([], GeoKit::LatLng.to_mongo(nil))
    end
  end

  context "GeoKit::LatLng.from_mongo" do
    should "be latlng if array" do
      assert_equal(GeoKit::LatLng.new(1, 2), GeoKit::LatLng.from_mongo([2, 1]))
    end

    should "be latlng if latlng" do
      assert_equal(GeoKit::LatLng.new(1, 2), GeoKit::LatLng.from_mongo(GeoKit::LatLng.new(1, 2)))
    end

    should "be blank latlng if nil" do
      assert_equal(GeoKit::LatLng.new, GeoKit::LatLng.from_mongo(nil))
    end
  end
end