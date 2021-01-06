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
    
    lazy private var compassButton: MKCompassButton = {
        let button = MKCompassButton(mapView: mapView)
        return button
    }()
    
    lazy private var userTrackingButton: MKUserTrackingButton = {
        let button = MKUserTrackingButton(mapView: mapView)
        button.setDimensions(height: 38, width: 38)
        button.tintColor = RFColor.red
        return button
    }()
    
    private let annotationZoomButton: UIButton = {
        let button = UIButton()
        button.setDimensions(height: 38, width: 38)
        let config = UIImage.SymbolConfiguration(scale: .large)
        button.setImage(UIImage(systemName: "mappin.and.ellipse")?.withConfiguration(config), for: .normal)
        button.tintColor = RFColor.red
        button.addTarget(self, action: #selector(zoomToFitAllEventAnnotations), for: .touchUpInside)
        return button
    }()
    
    lazy private var mapControlsView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 5
        view.layer.shadowColor = UIColor.systemGray.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = 6
        
        let contentView = UIView()
        contentView.backgroundColor = RFColor.groupedBackground
        contentView.layer.cornerRadius = 5
        contentView.layer.masksToBounds = true
        
        view.addSubview(contentView)
        contentView.anchor(top: view.topAnchor, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor)
        
        let line = UIView()
        line.setDimensions(height: 1)
        line.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
        
        contentView.addSubview(annotationZoomButton)
        contentView.addSubview(line)
        contentView.addSubview(userTrackingButton)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        annotationZoomButton.anchor(top: contentView.topAnchor, left: contentView.leftAnchor, right: contentView.rightAnchor)
        line.anchor(top: annotationZoomButton.bottomAnchor, left: contentView.leftAnchor, right: contentView.rightAnchor)
        userTrackingButton.anchor(top: line.bottomAnchor, left: contentView.leftAnchor, bottom: contentView.bottomAnchor, right: contentView.rightAnchor)
        
        return view
    }()
    
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
        // Configure Navigation Bar
        navigationItem.title = trip.name
        view.backgroundColor = RFColor.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addEventButtonTapped))
        navigationController?.navigationBar.tintColor = RFColor.red
        
        // Configure Search Bar
        searchBar.delegate = self
        view.addSubview(searchBar)
        searchBar.anchor(top: view.safeAreaLayoutGuide.topAnchor,
                         left: view.leftAnchor,
                         right: view.rightAnchor,
                         paddingLeft: 8,
                         paddingRight: 8)
        
        // Configure MapView
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.layer.borderWidth = 1
        mapView.layer.borderColor = UIColor.separator.withAlphaComponent(0.15).cgColor
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Event.annotationReuseIdentifier)
        view.addSubview(mapView)
        mapView.anchor(top: searchBar.bottomAnchor,
                       left: view.leftAnchor,
                       right: view.rightAnchor,
                       height: view.frame.width * 0.8)
        
        mapView.addSubview(mapControlsView)
        mapControlsView.anchor(top: mapView.topAnchor, right: mapView.rightAnchor, paddingTop: 8, paddingRight: 8)
        
        mapView.addSubview(compassButton)
        compassButton.centerX(inView: mapControlsView)
        compassButton.anchor(top: mapControlsView.bottomAnchor, paddingTop: 10)
        
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
                              paddingTop: 10)
        
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
    
    fileprivate func reloadTrip() {
        guard let trip = tripsController.getTrip(trip.id) else { return }
        
        self.trip = trip
        collectionView.reloadData()
        loadTripAnnotations()
    }
    
    func loadTripAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        
        for event in trip.eventsArray {
            mapView.addAnnotation(event)
        }
        
        zoomToFitAllEventAnnotations()
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
    
    @objc private func addEventButtonTapped() {
        showEventDetailViewController()
    }
    
    @objc private func zoomToFitAllEventAnnotations() {
        let annotations = mapView.annotations.filter { $0.isKind(of: Event.self) }
        mapView.zoomToFit(annotations: annotations, animated: true)
    }
    
    private func showEventDetailViewController(with event: Event? = nil) {
        let eventDetailVC = EventDetailViewController(trip: trip, tripsController: tripsController)
        eventDetailVC.event = event
        eventDetailVC.delegate = self
        let nav = UINavigationController(rootViewController: eventDetailVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    private func showEventDetailViewController(with placemark: MKPlacemark) {
        let eventDetailVC = EventDetailViewController(trip: trip, tripsController: tripsController, placemark: placemark)
        eventDetailVC.delegate = self
        let nav = UINavigationController(rootViewController: eventDetailVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
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
            
            // Setup Edit Event menu item
            let editEvent = UIAction(title: "Edit Event", image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) { [weak self] action in
                guard let self = self else { return }
                self.showEventDetailViewController(with: event)
            }
            
            // Setup Delete Event menu item
            let deleteEvent = UIAction(title: "Delete Event", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] action in
                guard let self = self else { return }
                self.tripsController.deleteEvent(event)
                self.reloadTrip()
            }
            
            return UIMenu(title: "", children: [editEvent, deleteEvent])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? EventCell,
              let event = cell.event else { return }
        
        mapView.selectAnnotation(event, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first, selectedIndexPath == indexPath {
            collectionView.deselectItem(at: indexPath, animated: false)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? EventCell, let event = cell.event {
                mapView.deselectAnnotation(event, animated: true)
            }
            
            return false
        }
        
        return true
    }
}

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
        showEventDetailViewController(with: selectedPlacemark)
        dismissSearchTableView()
    }
    
    private func addEvent(with placemark: MKPlacemark) {
        let name = placemark.name
        let latitude = placemark.location?.coordinate.latitude
        let longitude = placemark.location?.coordinate.longitude
        let address = placemark.address
        tripsController.addEvent(name: name, latitude: latitude, longitude: longitude, address: address, trip: trip)
        reloadTrip()
    }
}

// MARK: - Map View Delegate

extension TripDetailViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        
        guard let event = annotation as? Event else {
            NSLog("Missing the registered map annotation view")
            return nil
        }
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: Event.annotationReuseIdentifier, for: event) as? MKMarkerAnnotationView
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: event, reuseIdentifier: Event.annotationReuseIdentifier)
        }
        
        annotationView?.displayPriority = .required
        annotationView?.glyphImage = event.category.annotationGlyph
        annotationView?.markerTintColor = event.category.annotationMarkerTintColor
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let latitude = view.annotation?.coordinate.latitude,
              let longitude = view.annotation?.coordinate.longitude,
              let name = view.annotation?.title,
              let index = trip.eventsArray.firstIndex(where: { $0.coordinate.latitude == latitude && $0.coordinate.longitude == longitude && $0.name == name }) else { return }
        
        let indexPath = IndexPath(item: Int(index), section: 0)
        deselectAllEventCells()
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        deselectAllEventCells()
    }
    
    private func deselectAllEventCells() {
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems else { return }
        
        for indexPath in selectedIndexPaths {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
    }
}

// MARK: - EventDetailViewController Delegate

extension TripDetailViewController: EventDetailViewControllerDelegate {
    func didAddEvent(_ event: Event) {
        reloadTrip()
    }
    
    func didUpdateEvent(_ event: Event) {
        tripsController.updateEvent(event)
        reloadTrip()
    }
}
