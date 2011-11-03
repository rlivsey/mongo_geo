require 'mongo_mapper'
require 'geokit'

module GeoKit
  class LatLng
    # mongo stores as [x, y] which corresponds to [lon, lat]
    # so we have to make sure we reverse the order unless an array is passed
    # to prevent swapping back and forth
    def self.to_mongo(val)
      case val
      when GeoKit::LatLng
        val.to_a.reverse
      when Array
        val
      when nil
        []
      end
    end

    def self.from_mongo(val)
      case val
      when GeoKit::LatLng
        val
      when Array
        GeoKit::LatLng.new(val[1], val[0])
      when nil
        GeoKit::LatLng.new
      end
    end
  end
end

module Plucky
  module Extensions
    module Symbol
      def near
        SymbolOperator.new(self, 'near')
      end

      def within
        SymbolOperator.new(self, 'within')
      end
    end
  end
end

module GeoSpatial
  extend ActiveSupport::Concern

  module ClassMethods
    def geo_key(name, klass)
      unless [Array, Hash, GeoKit::LatLng].include?(klass)
        raise(ArgumentError, "#{klass} is not a valid type for a geo_key\nUse either an Array(recommended) or a Hash")
      end

      if @geo_key_name.nil?
        key name.to_sym, klass
        ensure_index([[name, Mongo::GEO2D]])
        @geo_key_name = name
      else
        error = "MongoDB is currently limited to only one geospatial index per collection.\n"
        error += "geo_key #{name} was NOT added to #{self.name}"
        raise(RuntimeError, error)
      end
    end

    def geo_key_name
      @geo_key_name
    end

    def near(location, params = {})
      args = BSON::OrderedHash.new
      args[:geoNear] = self.collection.name
      args[:near] = location.to_mongo
      params.each_pair{ |key, value| args[key.to_sym] = value }

      raw = database.command(args)
      objects = raw["results"].collect{ |r| self.load(r["obj"]) }
      objects.instance_variable_set(:@raw, raw)

      objects.each.with_index do |obj, index|
        obj.instance_variable_set(:@distance, raw["results"][index]["dis"])
        def obj.distance
          @distance
        end
      end

      def objects.average_distance
        @raw["stats"]["avgDistance"]
      end

      objects
    end
  end

  module InstanceMethods
    def distance_from(pt, options={})
      name = self.class.geo_key_name
      return nil if name.nil?
      raise(ArgumentError) unless [Array, Hash, GeoKit::LatLng].include?(pt.class)

      loc = self.send(name)
      loc = loc.values if loc.is_a?(Hash)
      pt  = pt.values  if pt.is_a?(Hash)

      GeoKit::LatLng.distance_between(loc, pt, options)
    end

    def neighbors(opts = {})
      opts = {:skip => 0, :limit => 10}.merge(opts)
      location = self.class.geo_key_name.to_sym

      self.class.name.constantize.where(
        location.near => self.send(self.class.geo_key_name).to_mongo
      ).skip(opts[:skip]).limit(opts[:limit] + 1).to_a.reject { |n| n.id == self.id }
    end
  end
end

MongoMapper::Document.plugin(GeoSpatial)