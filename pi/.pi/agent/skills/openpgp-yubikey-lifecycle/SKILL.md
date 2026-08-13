---
name: openpgp-yubikey-lifecycle
description: Safely creates, backs up, restores, renews, rotates, provisions, and verifies an offline-master OpenPGP identity across multiple YubiKeys on macOS or Linux. Use for GPG key or subkey expiration, YubiKey replacement, OpenPGP card provisioning, recovery archives, revocation certificates, SSH authentication subkeys, or publishing refreshed public keys.
compatibility: Requires GnuPG 2.4+, ykman, an OpenPGP-capable YubiKey, and interactive trusted pinentry. macOS commands may use shasum; Linux commands may use sha256sum.
---

# OpenPGP and YubiKey lifecycle

Use this workflow for Joel's offline certification key and all future OpenPGP/YubiKey lifecycle work.

## Non-negotiable safety rules

1. Never read, print, copy, or place PINs, passphrases, reset codes, private keys, or recovery codes in chat, command arguments, shell history, process arguments, logs, or ordinary wiki pages.
2. Secret values must be entered manually into trusted pinentry or terminal prompts. Store them only in the private Secret-space credential document or an approved password manager.
3. Before every destructive card action, independently verify the connected serial with `ykman list` and compare it with the intended role.
4. Reset only the OpenPGP application, never the entire YubiKey, unless the user explicitly requests a full-device reset after reviewing effects on FIDO, PIV, OTP, and other applications.
5. Never delete plaintext source material until an encrypted archive has passed checksums, isolated restore, fingerprint checks, and an encrypt/decrypt round trip.
6. Never attempt to clone a YubiKey. Restore the encrypted backup into a fresh isolated `GNUPGHOME` for each card and use `keytocard` from that copy.
7. Never place the certification/master private key on a YubiKey. Cards receive only dedicated signing, encryption, and authentication subkeys.
8. Do not query a card with `ykman` while GnuPG is in an interactive `gpg --edit-card` or `gpg --edit-key` transaction. Concurrent access can cause `Broken pipe` or stale-card failures.
9. Do not guess PINs. Stop after one failure, inspect counters, and use the known admin PIN or reset code to replace the user PIN.
10. Do not publish a key, update a keyserver, or import a revocation certificate without explicit user confirmation.
11. Treat `keytocard` as destructive to the current restoration copy. Always use a new copy for each card.
12. Use fingerprints, never short key IDs, for selection and verification.

## Current identity and card inventory

Read the private Secret-space page **OpenPGP recovery credentials** for credentials; do not reproduce secret values in agent context.

Public identifiers:

- User ID: `Joel Holder <jclosure@gmail.com>`
- Certification fingerprint: `E8B6A281ADDB636C5D764F369C46D62749D0FB71`
- Signing subkey: `2BE45118EE209552F715E0C0CDC28C7E63F414D3`
- Encryption subkey: `ED607518E5133F2676D4ED9B388220BAF4D0E541`
- Authentication subkey: `CC53941C425E7DC771766262124790E7619CE29B`
- SSH fingerprint: `SHA256:ZWBw6aYkyeoqxlqXer5tzFIkoVRS1qSNtPOb4DjpQfY`
- Primary YubiKey serial: `35905725`
- Secondary YubiKey serial: `35910688`
- Tertiary YubiKey serial: `27514466`

Expected expiration dates from the 2026-08-13 ceremony:

- Certification key: 2031-08-12
- Subkeys: 2028-08-12

Verified encrypted recovery archives:

- macOS: `~/openpgp-ceremony/new-2026-08-13T070413Z/openpgp-recovery-E8B6A281ADDB636C.tar.gpg`
- Air-gapped: `/Volumes/AIR_GAPPED/openpgp/E8B6A281ADDB636C5D764F369C46D62749D0FB71/openpgp-recovery-E8B6A281ADDB636C.tar.gpg`
- Linux: `/home/user/secure-archive/openpgp/joel-holder/E8B6A281ADDB636C5D764F369C46D62749D0FB71/openpgp-recovery-E8B6A281ADDB636C.tar.gpg`

## Start every operation with a plan

Classify the request before changing anything:

- **Extend expiration only:** Keep the same private keys and card contents. Restore the offline certification key, update expiration signatures, export and publish the refreshed public certificate. Usually no `keytocard` is needed.
- **Rotate/replace subkeys:** Generate new dedicated subkeys from the offline certification key, back them up, then independently reprovision every card.
- **Replace one lost/broken card:** Restore the complete encrypted backup into an isolated home, provision the same current subkeys to the replacement card, and test it.
- **Create a new identity:** Generate a certification-only primary and three dedicated subkeys in an isolated home, archive and verify before touching cards.
- **Revoke:** Confirm scope and reason, use the offline certification key or emergency certificate, export the revoked public certificate, and publish only after explicit confirmation.

Read [references/renewal-and-recovery.md](references/renewal-and-recovery.md) completely before executing an expiration, rotation, replacement, recovery, or revocation ceremony.

## Standard ceremony phases

### 1. Inspect without changing

Record:

```sh
gpg --version
ykman --version
ykman list
ykman openpgp info
gpg --with-colons --list-keys FINGERPRINT
gpg --with-colons --list-secret-keys FINGERPRINT
```

Confirm serial, slot fingerprints, touch policies, algorithms, expiry, PIN counters, available backups, mounted air-gapped volume, and server destination.

### 2. Work in an isolated home

```sh
umask 077
WORK="$HOME/openpgp-ceremony/$(date -u +%Y-%m-%dT%H%M%SZ)"
mkdir -m 700 -p "$WORK/gnupg" "$WORK/archive"
export GNUPGHOME="$WORK/gnupg"
```

Never perform certification-key work in the normal daily keyring.

### 3. Restore and verify before modification

Decrypt the recovery archive interactively, verify its external checksum, verify internal checksums, inspect packets with `--import-options show-only`, import into the isolated home, and compare every full fingerprint.

Perform a pre-change encrypt/decrypt round trip before modifying expiration or creating replacement subkeys.

### 4. Make the minimum required change

For expiration extension, use `gpg --quick-set-expire` with the primary fingerprint and explicit subkey fingerprints, or carefully use `gpg --edit-key`. Confirm the resulting absolute expiration dates.

For rotation, create exactly one dedicated subkey for each capability:

```sh
gpg --quick-add-key PRIMARY_FPR rsa4096 sign EXPIRY
gpg --quick-add-key PRIMARY_FPR rsa4096 encrypt EXPIRY
gpg --quick-add-key PRIMARY_FPR rsa4096 auth EXPIRY
```

Use graphical pinentry one operation at a time to avoid prompt timeouts. After each operation, inspect `--with-colons` output and remove accidental duplicates before archiving or provisioning.

### 5. Build and prove recovery

The encrypted recovery package must contain:

- passphrase-protected complete secret-key export
- public certificate
- revocation certificate
- ownertrust
- full fingerprint and expiry manifest
- internal checksums
- recovery and card-provisioning instructions
- ceremony metadata and verification status

Encrypt the package with a separate recovery-archive passphrase. Then decrypt into a new temporary directory, verify checksums, import into a fresh isolated `GNUPGHOME`, compare fingerprints, and perform an encryption/decryption round trip.

Copy the encrypted archive and safe metadata to at least the air-gapped volume and Linux server. Verify each copied archive against an external checksum before removing plaintext ceremony material.

### 6. Provision cards independently when required

For each role in order—Primary, Secondary, Tertiary:

1. Confirm the connected serial.
2. Confirm whether an OpenPGP reset is intended and safe.
3. Set card-specific user PIN, admin PIN, and reset code through interactive prompts.
4. Configure all three attributes as RSA-4096 when using this identity's current compatibility profile.
5. Restore the secret backup into a fresh per-card `GNUPGHOME`.
6. Move signing to slot 1, encryption to slot 2, and authentication to slot 3.
7. Save, then verify all full fingerprints with `ykman openpgp info`.
8. Set touch policy `on` for `sig`, `dec`, and `aut` through interactive admin-PIN prompts.
9. Test signing, encryption/decryption, SSH public-key derivation, and—where possible—a real SSH login.
10. Confirm counters remain `3/3/3` and delete the per-card restoration home.

### 7. Update daily workstations

Import only the refreshed public certificate into the daily keyring. Insert a provisioned card and run `gpg --card-status` to create card stubs. Ensure GPG agent SSH support remains configured and verify the expected SSH fingerprint.

### 8. Publish only after explicit confirmation

Before publishing, prove the export contains a public key block and no private-key block. Show the user the UID, full primary and subkey fingerprints, absolute expiration dates, and exact destinations. Obtain explicit confirmation in the current conversation.

For the current identity, publish to both independent services:

```sh
gpg --keyserver hkps://keyserver.ubuntu.com --send-keys PRIMARY_FPR
gpg --keyserver hkps://keys.openpgp.org --send-keys PRIMARY_FPR
```

Then verify each service independently in a fresh temporary `GNUPGHOME`; do not treat `gpg: sending key` as proof of publication.

For Ubuntu, retrieve by exact full fingerprint and confirm the UID, all subkey fingerprints, capabilities, and expiration dates. Hockeypuck replication may be briefly inconsistent, so retry a small bounded number of times rather than uploading repeatedly.

For `keys.openpgp.org`, fingerprint publication and email discoverability are separate. After upload:

1. Confirm `/vks/v1/by-fingerprint/PRIMARY_FPR` returns the expected key and subkeys.
2. If the UID is unpublished, use the documented JSON upload and `request-verify` API to request verification for the intended email address. Treat the short-lived verification token as sensitive and never print it.
3. Ask the user to complete the emailed verification link.
4. Confirm `/vks/v1/by-email/ENCODED_EMAIL` returns HTTP 200 and imports with the expected UID and every full fingerprint.

Record publication as one of: not published, fingerprint-only/pending UID verification, or fully published and email-discoverable.

### 9. Document and clean up

Update:

- Secret-space credential page: serials, card-specific credentials, public fingerprints, expiry, status
- Home Lab runbook: public operational and recovery procedure, backup paths, test status
- archive README and checksum metadata

Remove plaintext secret exports, temporary tar files, isolated keyrings, and transfer artifacts only after all verification gates pass.

## Required final report

Report concisely:

- primary and subkey fingerprints
- resulting expiration dates
- card serial-to-role mapping
- per-card fingerprints, touch policies, tests, and counters
- verified backup locations
- publication status
- remaining risks or follow-up date

Never include secret values in the report.
