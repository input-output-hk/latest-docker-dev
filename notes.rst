- Wrote the workflow
- Headeded to builkite, created a personal token and enabled:
  - Organistation access
  - Modify builds
  - Graphql API Access (ask Rhys)
- Added BUILDKITE_TOKEN to GitHub secrets
- Added "latest" to buildkite branch filters

Per Repo Actions:
=================

Buildkite:
- Add "latest" to buildkite branch filters
GitHub:
- Add Craige's Buildkite token to settings/secrets
  - Add new Secret
    - Name: Buildkite_Token
    - Value: past token in
Local:
- Create branch on repo
  - Write .github/workflows/release.yaml
  - Push and create PR

List of Repos:
=============

inputoutput/cardano-node
inputoutput/cardano-db-sync
inputoutput/cardano-graphql
inputoutput/cardano-rest
inputoutput/cardano-wallet
