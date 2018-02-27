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

class ViewController: UIViewController, UISearchBarDelegate, AGSGeoViewTouchDelegate, AGSCalloutDelegate {

    @IBOutlet weak var mapView: AGSMapView!

    let locator:AGSLocatorTask = AGSLocatorTask(url: URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)
    let routeTask:AGSRouteTask = {
        let routeTask = AGSRouteTask(url: URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
        routeTask.credential = _agsCredential
        return routeTask
    }()

    let geocodeResults:AGSGraphicsOverlay = {
        // Create a symbol for geocode results
        let markerSymbol = AGSSimpleMarkerSymbol(style: .circle, color: .orange, size: 15)
        markerSymbol.outline = AGSSimpleLineSymbol(style: .solid, color: .black, width: 3)

        // Set up a Graphics Overlay rendered with that symbol
        let overlay = AGSGraphicsOverlay()
        overlay.renderer = AGSSimpleRenderer(symbol: markerSymbol)

        return overlay
    }()

    let routeResults:AGSGraphicsOverlay = {
        // Create a symbol for geocode results
        let lineSymbol = AGSSimpleLineSymbol(style: .solid, color: UIColor.orange.withAlphaComponent(0.75), width: 6)

        // Set up a Graphics Overlay rendered with that symbol
        let overlay = AGSGraphicsOverlay()
        overlay.renderer = AGSSimpleRenderer(symbol: lineSymbol)

        return overlay
    }()

    let poiShortlistLayer:AGSFeatureLayer = {
        let table = AGSServiceFeatureTable(url: URL(string: "https://services.arcgis.com/OfH668nDRN7tbJh0/arcgis/rest/services/Palm_Springs_Shortlist/FeatureServer/0")!)
        return AGSFeatureLayer(featureTable: table)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let map = AGSMap(basemapType: .lightGrayCanvasVector, latitude: 33.82496, longitude: -116.54362, levelOfDetail: 15)

        mapView.map = map

        // Add the graphics overlay for geocode results to the map.
        mapView.graphicsOverlays.add(routeResults)
        mapView.graphicsOverlays.add(geocodeResults)

        // Add the POIs to the map
        map.operationalLayers.add(poiShortlistLayer)

        mapView.locationDisplay.start() { error in
            if let error = error {
                print("Unable to start location services: \(error.localizedDescription)")
            }
        }

        mapView.touchDelegate = self

        mapView.callout.delegate = self
        mapView.callout.accessoryButtonImage = #imageLiteral(resourceName: "directions")
    }


    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        mapView.identify(routeResults, screenPoint: screenPoint, tolerance: 10, returnPopupsOnly: false) { (routeResults) in
            guard let routeGraphic = routeResults.graphics.first else {
                self.mapView.identifyLayer(self.poiShortlistLayer, screenPoint: screenPoint, tolerance: 22, returnPopupsOnly: false) { results in
                    guard let result = results.geoElements.first as? AGSArcGISFeature else {
                        print("Nothing tapped")
                        self.mapView.callout.dismiss()
                        return
                    }

                    self.mapView.callout.show(for: result, tapLocation: mapPoint, animated: true)
                    self.mapView.callout.title = result.attributes.value(forKey: "Name") as? String ?? "Go away"
                    self.mapView.callout.detail = nil
                    self.mapView.callout.isAccessoryButtonHidden = false
                }
                return
            }

            self.mapView.callout.show(for: routeGraphic, tapLocation: mapPoint, animated: true)
            self.mapView.callout.title = routeGraphic.attributes.value(forKey: "title") as? String ?? "No deets"
            self.mapView.callout.detail = routeGraphic.attributes.value(forKey: "detail") as? String
            self.mapView.callout.isAccessoryButtonHidden = true
        }
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


    func didTapAccessoryButton(for callout: AGSCallout) {
        defer {
            mapView.callout.dismiss()
        }

        guard let result = callout.representedObject as? AGSArcGISFeature,
            let resultLocation = result.geometry as? AGSPoint else {
                print("Need a point location")
                return
        }

        self.routeTask.defaultRouteParameters(completion: { (params, error) in
            guard error == nil else {
                print("Error getting default route task parameters: \(error!.localizedDescription)")
                return
            }

            guard let params = params else {
                print("No default route task parameters found")
                return
            }

            guard let myLocation = self.mapView.locationDisplay.mapLocation else {
                print("Unablet to get device location")
                return
            }

            params.outputSpatialReference = self.mapView.spatialReference
            params.directionsDistanceUnits = AGSUnitSystem.metric

            let start = AGSStop(point: myLocation)
            let end = AGSStop(point: resultLocation)

            start.name = "Your location"
            end.name = (result.attributes.value(forKey: "Name") as? String) ?? "Destination"

            params.setStops([start, end])

            self.routeTask.solveRoute(with: params, completion: { (routeResult, error) in
                guard error == nil else {
                    print("Error solving route: \(error!.localizedDescription)")
                    return
                }

                if let route = routeResult?.routes.first, let routeGeom = route.routeGeometry {
                    self.routeResults.graphics.removeAllObjects()
                    let outUnit = AGSLinearUnit.miles()
                    let outVal = (outUnit.convert(route.totalLength, from: AGSLinearUnit.meters())*100).rounded()/100
                    let title = "\(outVal)\(outUnit.abbreviation), \((route.totalTime*100).rounded()/100) minutes"
                    let detail = "\(start.name) to \(end.name)"
                    self.routeResults.graphics.add(AGSGraphic(geometry: routeGeom, symbol: nil, attributes: ["title":title, "detail":detail]))

                    self.mapView.setViewpoint(AGSViewpoint(targetExtent: routeGeom.extent.toBuilder().expand(byFactor: 1.2).toGeometry()), completion: nil)
                }
            })
        })

    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

