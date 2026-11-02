package tn.winou.places;

import java.util.List;

import tn.winou.web.ApiModels.PlaceKind;

/** Where vets and shelters come from: OpenStreetMap in production, a fake in tests. */
public interface PlaceSource {

    record Place(String osmId, PlaceKind kind, String name, String phone, String openingHours, double lat,
            double lon) {}

    /** Every vet and animal shelter in the box. */
    List<Place> fetch(double south, double west, double north, double east);
}
