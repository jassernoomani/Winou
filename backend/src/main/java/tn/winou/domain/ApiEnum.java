package tn.winou.domain;

import com.fasterxml.jackson.annotation.JsonValue;

/** An enum whose API spelling differs from its Java name, e.g. Species.CAT is "cat". */
public interface ApiEnum {

    @JsonValue
    String api();
}
