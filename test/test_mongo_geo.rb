require 'helper'

class TestMongoGeo < Test::Unit::TestCase
  context "Initializing a model" do
    setup do
      @asset1 = TestAsset.create(:coords => [50, 50])
      @asset2 = TestAsset.create(:coords => [60, 60])
      @asset3 = TestAsset.create(:coords => [70, 70])
    end

    should "create the 2d index" do
      assert_equal(TestAsset.geo_key_name, :coords)
      assert(TestAsset.collection.index_information['coords_2d'], "geo_key did not define the 2d index")
    end

    should "validate #geo_key type" do
      assert_raise(ArgumentError) { TestAsset.geo_key(:blah, Float) }
      assert_raise(RuntimeError) { TestAsset.geo_key(:no_more, Array) }
    end

    should "allow plucky queries using #near" do
      nearby = TestAsset.where(:coords.near => [45, 45]).to_a
      assert_equal(nearby.first, @asset1)
      assert_equal(nearby.last, @asset3)
    end

    should "allow plucky queries using #within" do
      nearby = TestAsset.where(:coords.within => { "$center" => [[45, 45], 10] }).to_a
      assert_equal(nearby, [@asset1])
    end

    should "allow geoNear style queries with #near" do
      nearby = TestAsset.near([45, 45], :num => 2)
      assert_equal(2, nearby.count)
      assert_equal(@asset1, nearby.first)

      assert(nearby.methods.collect{ |m| m.to_sym }.include?(:average_distance), "#near did not define average_distance")
      assert_equal(nearby.average_distance.class, Float)

      assert(nearby.first.methods.collect{ |m| m.to_sym }.include?(:distance), "#near did not define distance on each record")
      assert_equal(nearby.first.distance.class, Float)
    end

    should "perform a #distance_from calculation using GeoKit" do
      assert(@asset1.methods.collect{ |m| m.to_sym }.include?(:distance_from), "GeoSpatial::InstanceMethods were not included")
      assert_raise(ArgumentError) { @asset1.distance_from(51) }
      assert_equal(GeoKit::LatLng.distance_between([51, 51], @asset1.coords.to_a), @asset1.distance_from([51, 51]))

      TestAsset.collection.remove
    end

    should "allow passing options to GeoKit with #distance_from" do
      geokit_result = GeoKit::LatLng.distance_between([51, 51], @asset1.coords.to_a, :sphere => true)
      geo_result    = @asset1.distance_from([51, 51], :sphere => true)
      assert_equal(geokit_result, geo_result)

      TestAsset.collection.remove
    end

    should "find close objects with #neighbors" do
      neighbors = @asset1.neighbors
      assert_equal([@asset2, @asset3], neighbors)
    end

    should "find closest object with #neighbors" do
      neighbors = @asset1.neighbors(:limit => 1)
      assert_equal([@asset2], neighbors)
    end
  end
end
