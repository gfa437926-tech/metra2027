# Supabase JWT Authentication Configuration

## Status

The API now has a configuration-driven ASP.NET Core JWT bearer boundary for Supabase Auth. This is an implementation of token validation only; it does not activate the initial registration endpoint, create METRA permissions, or change any database.

## Configuration

Set these server-side application settings:

- `Authentication:Supabase:Authority`: the exact Supabase Auth JWT issuer, including `/auth/v1`, for example `https://<project-ref>.supabase.co/auth/v1`.
- `Authentication:Supabase:Audience`: the expected access-token audience, normally `authenticated` for Supabase Auth access tokens.

Supply production values through the deployment secret/configuration system, not a committed appsettings file. The authority must be HTTPS and cannot contain credentials, query strings, or fragments.

In Development only, if either setting is absent, the API retains the existing unconfigured authentication scheme. That scheme never authenticates a request. Outside Development, missing values stop application startup.

## Validation guarantees

The configured bearer handler:

- obtains signing metadata and keys from the issuer's OIDC discovery document;
- validates the signature, exact issuer, configured audience, and token lifetime;
- allows only RS256 and ES256 asymmetric signing algorithms;
- uses a 60-second clock skew;
- does not save bearer tokens;
- disables inbound claim remapping so the immutable `sub` claim remains available.

METRA permission evaluation remains independent and server-side. The Supabase `role` claim is not treated as a METRA application role or permission grant. The existing deny-all permission evaluator remains in place until an authoritative METRA permission store is implemented.

## Supabase project prerequisite

Supabase's JWKS endpoint exposes public verification keys when the project uses asymmetric JWT signing keys. The default HS256 signing mode does not publish a usable public JWKS key set. Before configuring this API, the Supabase Auth project must be deliberately configured for an asymmetric signing key (RS256 or ES256), and the issuer and audience must be verified against a real access token from that project.

Do not copy a JWT secret into the API or commit it to source control. If the Supabase project remains on HS256, this JWT bearer setup must not be enabled; a separately reviewed server-side verification design is required.

## Not enabled by this change

- No production identity credentials or project URL are committed.
- No registration endpoint mapping or registration service registration is added.
- No role grants, station assignments, approval transitions, or database migrations are added.
- No database project is contacted or modified by this change.

## Operational verification still required

Before production activation, verify issuer discovery and JWKS retrieval from the deployment network, validate a real short-lived access token and negative cases (wrong issuer, audience, signature, expiry, and algorithm), and run the .NET build and test suite in CI. This repository change has not itself established a successful build or runtime token-validation test.
