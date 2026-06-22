import Foundation

/// Looks up B2B "Client" accounts (employers / schools / courts) for the
/// "Who sent you?" autocomplete on the drug-screen flow.
///
/// Hits `GET /clients?search=` on the ALTNAdmin admin API (same Bearer-token
/// host the consent forms use). Results are used both for live suggestions and
/// for resolving a typed name to an exact account on submit so the appointment
/// can be auto-linked.
struct ReferralClientService {

    /// Search active B2B clients by company / contact. Returns [] for blank or
    /// too-short queries. Optionally restricts to a franchise (the kiosk's),
    /// falling back to all results when nothing matches that franchise.
    func search(_ query: String, franchise: String? = nil, limit: Int = 8) async throws -> [ReferralClient] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let rows: [ReferralClient] = try await Endpoints.consentAPI.get(
            "/clients",
            query: [
                URLQueryItem(name: "search",      value: trimmed),
                URLQueryItem(name: "active_only", value: "true"),
            ]
        )

        let active = rows.filter { $0.isActive && !$0.companyName.trimmingCharacters(in: .whitespaces).isEmpty }

        // Prefer the kiosk's own franchise, but don't hide everything if the
        // accounts aren't franchise-stamped consistently.
        let scoped: [ReferralClient]
        if let franchise, !franchise.isEmpty {
            let matches = active.filter { ($0.franchise ?? "") == franchise }
            scoped = matches.isEmpty ? active : matches
        } else {
            scoped = active
        }

        return Array(scoped.prefix(limit))
    }

    /// Resolve a typed referrer name to a single client account via a
    /// case-insensitive exact match on company name. Used at submit time so a
    /// fully-typed name (no suggestion tapped) still links. Returns nil when
    /// there is no unambiguous match.
    func exactMatch(_ name: String, franchise: String? = nil) async throws -> ReferralClient? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return nil }

        let candidates = try await search(needle, franchise: franchise, limit: 25)
        let exact = candidates.filter {
            $0.companyName.trimmingCharacters(in: .whitespaces)
                .caseInsensitiveCompare(needle) == .orderedSame
        }
        // Only auto-link when the match is unambiguous.
        return exact.count == 1 ? exact.first : nil
    }
}
