package tn.winou.domain;

import java.util.Arrays;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/** Species are stored in their API spelling ("cat"), as the Python API did. */
@Converter(autoApply = true)
public class SpeciesConverter implements AttributeConverter<Species, String> {

    @Override
    public String convertToDatabaseColumn(Species species) {
        return species == null ? null : species.api();
    }

    @Override
    public Species convertToEntityAttribute(String value) {
        return value == null ? null : Arrays.stream(Species.values())
                .filter(s -> s.api().equals(value))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("unknown species " + value));
    }
}
