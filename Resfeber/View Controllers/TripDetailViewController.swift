//
//  TripDetailViewController.swift
//  Resfeber
//
//  Created by David Wright on 12/13/20.
//  Copyright © 2020 Spencer Curtis. All rights reserved.
//

import UIKit
import MapKit

class TripDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    private var trip: Trip
    
    fileprivate let searchBar: UISearchBar = {
        let sb = UISearchBar(frame: .zero)
        sb.tintColor = RFColor.red
        sb.placeholder = "Search for a places or address"
        sb.searchBarStyle = .minimal
        return sb
    }()
    
    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    
    // MARK: - Lifecycle
    
    init(_ trip: Trip) {
        self.trip = trip
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        enableLocationServices()
        configureViews()
    }
    
    // MARK: - Helpers
    
    fileprivate func configureViews() {
        navigationItem.title = trip.name
        view.backgroundColor = RFColor.background
        
        // Configure Search Bar
        searchBar.delegate = self
        view.addSubview(searchBar)
        searchBar.anchor(top: view.safeAreaLayoutGuide.topAnchor,
                         left: view.leftAnchor,
                         right: view.rightAnchor,
                         paddingTop: 0,
                         paddingLeft: 12,
                         paddingRight: 12)
    }
    
    fileprivate func performQuery(with searchText: String?) {
        let queryText = searchText ?? ""
        print("DEBUG: Perform query with text: \(queryText)..")
    }
}

extension TripDetailViewController: CLLocationManagerDelegate {
    fileprivate func enableLocationServices() {
        locationManager.delegate = self
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        default:
            break
        }
    }
}

// MARK: - Search Bar Delegate
extension TripDetailViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        print("DEBUG: Search bar text changed: \(searchText)..")
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        performQuery(with: searchBar.text)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
}
