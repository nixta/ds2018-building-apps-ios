// Copyright 2018 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

class ViewController: UIViewController, UISearchBarDelegate {

    @IBOutlet weak var mapView: AGSMapView!

    let locator:AGSLocatorTask = AGSLocatorTask(url: URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)

    let geocodeResults:AGSGraphicsOverlay = {
        // Create a symbol for geocode results
        let markerSymbol = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.blue, size: 15)
        markerSymbol.outline = AGSSimpleLineSymbol(style: .solid, color: UIColor.white, width: 2)

        // Set up a Graphics Overlay rendered with that symbol
        let overlay = AGSGraphicsOverlay()
        overlay.renderer = AGSSimpleRenderer(symbol: markerSymbol)

        return overlay
    }()

    let poiShortlistLayer:AGSFeatureLayer = {
        let table = AGSServiceFeatureTable(url: URL(string: "https://services.arcgis.com/OfH668nDRN7tbJh0/arcgis/rest/services/Palm_Springs_Shortlist/FeatureServer/0")!)
        return AGSFeatureLayer(featureTable: table)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let map = AGSMap(basemapType: .navigationVector, latitude: 33.82496, longitude: -116.53862, levelOfDetail: 17)

        mapView.map = map

        // Add the graphics overlay for geocode results to the map.
        mapView.graphicsOverlays.add(geocodeResults)

        // Add the POIs to the map
        map.operationalLayers.add(poiShortlistLayer)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Here we'll geocode!
        guard let searchText = searchBar.text else {
            return
        }

        print("Search for \(searchText)")

        locator.geocode(withSearchText: searchText) { (results, error) in
            guard error == nil else {
                print("Error geocoding! \(error!.localizedDescription)")
                return
            }

            if let result = results?.first {

                if let extent = result.extent {
                    self.mapView.setViewpoint(AGSViewpoint(targetExtent: extent))
                }

                print("Showing first result of \(results!.count): \(result.label)")

                self.geocodeResults.graphics.removeAllObjects()
                if let location = result.displayLocation {
                    let resultGraphic = AGSGraphic(geometry: location, symbol: nil, attributes: nil)
                    self.geocodeResults.graphics.add(resultGraphic)
                }
            }


        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

