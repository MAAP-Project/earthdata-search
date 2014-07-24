class DetailsPresenter

  def temporal(hash)
    if hash && hash['RangeDateTime']
      "#{hash['RangeDateTime']['BeginningDateTime']} to #{hash['RangeDateTime']['EndingDateTime']}"
    else
      'Not available'
    end
  end

  def spatial(hash)
    if hash
      spatial_list = hash.map do |h|
        spatial = []

        if h['HorizontalSpatialDomain']
          geometry = h['HorizontalSpatialDomain']['Geometry']
          if geometry['Point']
            points = Array.wrap(geometry['Point'])

            points.each do |point|
              latitude = point['PointLatitude']
              longitude = point['PointLongitude']
              spatial << "Point: (#{degrees(latitude)}, #{degrees(longitude)})"
            end

          elsif geometry['BoundingRectangle']
            boxes = Array.wrap(geometry['BoundingRectangle'])

            boxes.each do |box|
              north = box['NorthBoundingCoordinate']
              south = box['SouthBoundingCoordinate']
              east = box['EastBoundingCoordinate']
              west = box['WestBoundingCoordinate']
              spatial = "Bounding Rectangle: (#{degrees(north)}, #{degrees(west)}, #{degrees(south)}, #{degrees(east)})"
            end
          elsif geometry['GPolygon']
            polygons = Array.wrap(geometry['GPolygon'])

            polygons.each do |polygon|
              s = "Polygon: ("
              polygon['Boundary'].each do |point|
                point[1].each_with_index do |p, i|
                  latitude = p['PointLatitude']
                  longitude = p['PointLongitude']
                  s += "(#{degrees(latitude)}, #{degrees(longitude)})"
                  s += ", " if i+1 < point[1].size
                end
              end
              s += ")"
              spatial << s
            end

          elsif geometry['Line']
            lines = Array.wrap(geometry['Line'])

            lines.each do |line|
              latitude1 = line['Point'][0]['PointLatitude']
              longitude1 = line['Point'][0]['PointLongitude']
              latitude2 = line['Point'][1]['PointLatitude']
              longitude2 = line['Point'][1]['PointLongitude']
              spatial << "Line: ((#{degrees(latitude1)}, #{degrees(longitude1)}), (#{degrees(latitude2)}, #{degrees(longitude2)}))"
            end
          else
            spatial = ['Not available']
          end
        else
          spatial = ['Not available']
        end

        spatial
      end
    else
      spatial_list = ['Not available']
    end

    spatial_list.flatten
  end

  def degrees(text)
    "#{text}\xC2\xB0"
  end

end