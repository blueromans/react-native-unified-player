# Publishing to npm

This project uses GitHub Actions to automatically publish to npm when changes are pushed to the `main` or `master` branch.

## Setup

### 1. Create a Granular Access Token

Since npm revoked classic tokens (December 2025), you need to create a **Granular Access Token**:

1. Go to https://www.npmjs.com/settings/YOUR_USERNAME/access-tokens
2. Click "Generate New Token"
3. Select "Granular Access Token"
4. Choose "Automation" as the token type
5. Set permissions:
   - **Read and Write packages** (required for publishing)
   - Set expiration as needed (recommended: 1 year or custom)
6. Click "Generate Token"
7. **Copy the token immediately** (you won't be able to see it again)

### 2. Add Token to GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Name: `NPM_TOKEN`
5. Value: Paste your granular access token
6. Click **"Add secret"**

### 3. Verify 2FA is Enabled

npm now requires 2FA for publishing. Make sure you have 2FA enabled on your npm account:

1. Go to https://www.npmjs.com/settings/YOUR_USERNAME/security
2. Enable Two-Factor Authentication if not already enabled

## How It Works

The workflow automatically:

1. Runs on every push to `main` or `master` branch
2. Executes all CI checks (lint, test, build)
3. If all checks pass, uses `release-it` to:
   - Determine version bump based on conventional commits:
     - `feat:` → minor version (0.5.0 → 0.6.0)
     - `fix:` → patch version (0.5.0 → 0.5.1)
     - `BREAKING CHANGE:` → major version (0.5.0 → 1.0.0)
   - Build the package
   - Publish to npm
   - Create a git tag
   - Create a GitHub release

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

- `feat: add new feature` → minor version bump
- `fix: fix bug` → patch version bump
- `feat!: breaking change` or `BREAKING CHANGE: description` → major version bump
- `docs:`, `style:`, `refactor:`, `test:`, `chore:` → no version bump (skips release)

## Troubleshooting

### "403 Forbidden" Error

- Verify your token has "Read and Write packages" permission
- Ensure 2FA is enabled on your npm account
- Check that the token hasn't expired
- Verify the token is a Granular Access Token (not classic)

### "No version bump" Message

- This is normal if your commits don't follow conventional commit format
- Only commits with `feat:`, `fix:`, or `BREAKING CHANGE:` will trigger a release

### Token Expired

- Create a new granular access token
- Update the `NPM_TOKEN` secret in GitHub
- Consider setting a longer expiration (up to 1 year)

## Alternative: OIDC Authentication

For enhanced security, you can also use OpenID Connect (OIDC) for tokenless authentication. This requires additional setup with npm's trusted publishing feature.
