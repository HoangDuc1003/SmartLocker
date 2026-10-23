package service;

import java.util.Optional;

/**
 * v3 (D6): the place for an IP-based location fallback, for when the browser cannot share its position.
 * Nothing calls an outside service yet: the page must work offline, and a third-party lookup needs the owner's
 * consent. Plug a real implementation in later; NoIpGeoLocator is the default.
 */
public interface IpGeoLocator {

    /** {latitude, longitude} of a client address, or empty when unknown. Never use a device IP for this. */
    Optional<double[]> locate(String clientIp);

    /** The default: knows nothing. */
    final class NoIpGeoLocator implements IpGeoLocator {
        @Override
        public Optional<double[]> locate(String clientIp) {
            return Optional.empty();
        }
    }
}
