package tn.winou.domain;

public enum Species implements ApiEnum {
    CAT("cat"),
    DOG("dog"),
    OTHER("other");

    private final String api;

    Species(String api) {
        this.api = api;
    }

    @Override
    public String api() {
        return api;
    }
}
