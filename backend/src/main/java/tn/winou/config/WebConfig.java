package tn.winou.config;

import java.util.List;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.core.convert.converter.ConverterFactory;
import org.springframework.format.FormatterRegistry;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import tn.winou.domain.ApiEnum;
import tn.winou.security.CurrentUserResolver;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final CurrentUserResolver currentUserResolver;

    public WebConfig(CurrentUserResolver currentUserResolver) {
        this.currentUserResolver = currentUserResolver;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(currentUserResolver);
    }

    @Override
    public void addFormatters(FormatterRegistry registry) {
        registry.addConverterFactory(new EnumConverterFactory());
    }

    /** Query and form values use the API spelling: ?species=cat, ?type=lost, source=CAMERA. */
    @SuppressWarnings({"rawtypes", "unchecked"})
    static class EnumConverterFactory implements ConverterFactory<String, Enum> {

        @Override
        public <T extends Enum> Converter<String, T> getConverter(Class<T> type) {
            return value -> {
                for (T constant : type.getEnumConstants()) {
                    String api = constant instanceof ApiEnum e ? e.api() : constant.name();
                    if (api.equals(value)) {
                        return constant;
                    }
                }
                throw new IllegalArgumentException("unknown value " + value);
            };
        }
    }
}
