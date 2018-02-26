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

class ViewController: UIViewController, UISearchBarDelegate, AGSGeoViewTouchDelegate {

    @IBOutlet weak var mapView: AGSMapView!

    let locator:AGSLocatorTask = AGSLocatorTask(url: URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)

    override func viewDidLoad() {
        super.viewDidLoad()

        let map = AGSMap(basemapType: .navigationVector, latitude: 33.82496, longitude: -116.53862, levelOfDetail: 17)

        mapView.map = map

        mapView.touchDelegate = self
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

            if let result = results?.first, let extent = result.extent {
                self.mapView.setViewpoint(AGSViewpoint(targetExtent: extent))
                print("Showing first result of \(results!.count): \(result.label)")
            }
        }
    }

    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        locator.reverseGeocode(withLocation: mapPoint) { (results, error) in
            guard error == nil else {
                print("Error reverse geocoding! \(error!.localizedDescription)")
                return
            }

            if let result = results?.first {
                print("You tapped at \(result.label)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

