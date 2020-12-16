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
    
    private let tripsController: TripsController
    
    private let searchBar: UISearchBar = {
        let sb = UISearchBar(frame: .zero)
        sb.tintColor = RFColor.red
        sb.placeholder = "Search for a place or address"
        sb.searchBarStyle = .minimal
        return sb
    }()
    
    private let searchTableView = UITableView()
    private var searchResults = [MKPlacemark]()
    
    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    
    private var collectionView: UICollectionView!
    
    // MARK: - Lifecycle
    
    init(_ trip: Trip, tripsController: TripsController) {
        self.trip = trip
        self.tripsController = tripsController
        
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
    
    private func configureViews() {
        navigationItem.title = trip.name
        view.backgroundColor = RFColor.background
        
        // Configure Search Bar
        searchBar.delegate = self
        view.addSubview(searchBar)
        searchBar.anchor(top: view.safeAreaLayoutGuide.topAnchor,
                         left: view.leftAnchor,
                         right: view.rightAnchor,
                         paddingLeft: 8,
                         paddingRight: 8)
        
        // Configure MapView
        mapView.showsUserLocation = true
        mapView.layer.borderWidth = 1
        mapView.layer.borderColor = RFColor.red.cgColor
        view.addSubview(mapView)
        mapView.anchor(top: searchBar.bottomAnchor,
                       left: view.leftAnchor,
                       right: view.rightAnchor,
                       paddingTop: 4,
                       paddingLeft: 12,
                       paddingRight: 12,
                       height: view.frame.width * 0.8)
        
        // Configure Collection View
        collectionView = UICollectionView(frame: view.frame, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.backgroundColor = RFColor.background
        collectionView.register(EventCell.self, forCellWithReuseIdentifier: EventCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.anchor(top: mapView.bottomAnchor,
                              left: view.leftAnchor,
                              bottom: view.bottomAnchor,
                              right: view.rightAnchor,
                              paddingTop: 12)
        
        // Load Data
        collectionView.reloadData()
        
        configureTableView()
        loadTripAnnotations()
    }
    
    private func configureTableView() {
        searchTableView.backgroundColor = RFColor.background
        searchTableView.delegate = self
        searchTableView.dataSource = self
        searchTableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        searchTableView.rowHeight = 60
        searchTableView.tableFooterView = UIView()
        
        let height = view.frame.height - view.safeAreaInsets.top
        searchTableView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: height)
        view.addSubview(searchTableView)
    }
    
    private func reloadTrip() {
        guard let tripName = trip.name else { return }
        guard let trip = tripsController.getTrip(withName: tripName) else { return }
        
        self.trip = trip
        collectionView.reloadData()
        loadTripAnnotations()
    }
    
    func loadTripAnnotations() {
        for event in trip.eventsArray {
            let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            self.mapView.addAnnotation(annotation)
        }
        
        let annotations = mapView.annotations
        self.mapView.zoomToFit(annotations: annotations)
    }
    
    private func performQuery(with searchText: String?) {
        let queryText = searchText ?? ""
        
        searchBy(naturalLanguageQuery: queryText) { results in
            self.searchResults = results
            self.searchTableView.reloadData()
        }
    }
    
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark]) -> Void) {
        var results = [MKPlacemark]()
        
        let request = MKLocalSearch.Request()
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            
            response.mapItems.forEach { item in
                results.append(item.placemark)
            }
            
            completion(results)
        }
    }
    
    func showSearchTableView() {
        UIView.animate(withDuration: 0.2) {
            self.searchTableView.frame.origin.y = self.searchBar.frame.maxY
        }
    }
    
    func dismissSearchTableView(completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            self.searchTableView.frame.origin.y = self.view.frame.height
        }, completion: completion)
    }
}

extension TripDetailViewController: CLLocationManagerDelegate {
    private func enableLocationServices() {
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
        dismissSearchTableView()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
        showSearchTableView()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
}

// MARK: - Collection View Layout
extension TripDetailViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let xEdgeInset: CGFloat = 12
        let cellWidth = collectionView.frame.size.width - 2 * xEdgeInset
        let cellHeight: CGFloat = 70
        return CGSize(width: cellWidth, height: cellHeight)
    }
}

// MARK: - Collection View Data Source
extension TripDetailViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        trip.eventsArray.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventCell.reuseIdentifier, for: indexPath) as! EventCell

        cell.event = trip.eventsArray[indexPath.row]

        return cell
    }
}

// MARK: - Collection View Delegate
extension TripDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? EventCell,
              let event = cell.event else { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            // Setup Delete Event menu item
            let deleteEvent = UIAction(title: "Delete Event", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] action in
                guard let self = self else { return }
                self.tripsController.deleteEvent(event)
                self.reloadTrip()
            }
            
            return UIMenu(title: "", children: [deleteEvent])
        }
    }
}

/*
// MARK: - Collection View Delegate
extension TripDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? EventCell,
              let event = cell.event else { return }

        let detailVC = EventDetailViewController(event)
        show(detailVC, sender: self)
    }
}
*/

// MARK: - Search Table View DataSource

extension TripDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseIdentifier, for: indexPath) as! SearchResultCell
        cell.placemark = searchResults[indexPath.row]
        return cell
    }
}

// MARK: - Search Table View Delegate

extension TripDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPlacemark = searchResults[indexPath.row]
        addEvent(with: selectedPlacemark)
        dismissSearchTableView()
    }
    
    private func addEvent(with placemark: MKPlacemark) {
        let name = placemark.name
        let latitude = placemark.location?.coordinate.latitude
        let longitude = placemark.location?.coordinate.longitude
        tripsController.addEvent(name: name, latitude: latitude, longitude: longitude, trip: trip)
        reloadTrip()
    }
}