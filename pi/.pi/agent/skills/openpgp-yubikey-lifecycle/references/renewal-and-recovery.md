# Renewal, rotation, replacement, recovery, and revocation runbook

Read this entire reference before manipulating the offline certification key or any card.

## Decision table

| Situation | Correct action | Reprovision cards? |
|---|---|---|
| Existing subkeys are healthy; only expiration approaches | Extend expiration signatures with offline certification key | Usually no |
| Subkey is suspected compromised | Revoke that subkey, create a replacement, republish | Yes |
| Cryptographic policy changes or planned rotation | Create replacement subkeys, overlap if appropriate, republish | Yes |
| One card is lost but subkeys are not considered compromised | Provision a replacement from encrypted backup | No change to surviving cards |
| A card and its PINs are lost in an uncontrolled location | Assess compromise; rotate or revoke subkeys if exposure risk warrants | Usually yes |
| Certification key is near expiry | Extend its expiry and refresh public certificate | No, unless also rotating subkeys |
| Certification private key is lost but emergency certificate exists | Revoke identity and create a new identity | New cards/identity |

Expiration is metadata signed by the certification key. The card stores private subkey material, not the mutable public expiration signature. Therefore an expiration-only extension generally requires publishing/importing the refreshed public certificate, not rewriting card slots.

## Backup verification before ceremony

Use an offline trusted system where possible.

```sh
umask 077
RECOVERY=$(mktemp -d)
mkdir -m 700 "$RECOVERY/gnupg" "$RECOVERY/files"
```

Verify external checksum from the backup directory:

```sh
shasum -a 256 -c SHA256       # macOS
sha256sum -c SHA256           # Linux
```

Decrypt interactively. Never pass the archive passphrase on the command line:

```sh
gpg --output "$RECOVERY/recovery.tar" --decrypt openpgp-recovery-*.tar.gpg
tar -C "$RECOVERY/files" -xf "$RECOVERY/recovery.tar"
```

Verify internal checksums:

```sh
(cd "$RECOVERY/files" && shasum -a 256 -c SHA256SUMS)
```

Inspect before import:

```sh
gpg --batch --with-colons --import-options show-only --import \
  "$RECOVERY/files/secret-master-and-subkeys.asc"
```

Compare all full fingerprints with the manifest and the Home Lab runbook.

Import only into the isolated home:

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --import \
  "$RECOVERY/files/secret-master-and-subkeys.asc"
GNUPGHOME="$RECOVERY/gnupg" gpg --import-ownertrust \
  "$RECOVERY/files/ownertrust.txt"
```

## Expiration-only renewal

### Recommended timing

Begin 60–90 days before subkey expiration. For the current identity, schedule review by 2028-05-12 and complete before 2028-08-12.

### Pre-change snapshot

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --with-colons --list-keys \
  E8B6A281ADDB636C5D764F369C46D62749D0FB71 > before.txt
```

Confirm the restored secret primary is real private material, not a card stub (`#` rather than a card serial in colon output).

### Extend the primary

Choose a deliberate absolute policy. Example: five years from ceremony date:

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --quick-set-expire \
  E8B6A281ADDB636C5D764F369C46D62749D0FB71 5y
```

### Extend existing subkeys

Specify all full subkey fingerprints. Example:

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --quick-set-expire \
  E8B6A281ADDB636C5D764F369C46D62749D0FB71 2y \
  2BE45118EE209552F715E0C0CDC28C7E63F414D3 \
  ED607518E5133F2676D4ED9B388220BAF4D0E541 \
  CC53941C425E7DC771766262124790E7619CE29B
```

Check your installed GnuPG's `--quick-set-expire` syntax before running; versions differ. If uncertain, use `gpg --edit-key`, select each subkey individually, use `expire`, and inspect the selected `*` marker before confirming.

### Verify

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --with-colons --list-keys \
  E8B6A281ADDB636C5D764F369C46D62749D0FB71 > after.txt
```

Confirm fingerprints are unchanged and only intended expiration/self-signature metadata changed. Export a refreshed public certificate and complete a signing/encryption test with a card after importing that public certificate into a test keyring.

Cards normally do not need `keytocard` for this path.

## Planned subkey rotation

Use when replacing subkeys rather than extending them.

1. Restore and verify the complete backup.
2. Decide whether to keep old subkeys valid for a transition period.
3. Generate exactly one new signing, encryption, and authentication subkey.
4. Inspect capabilities and count before proceeding.
5. Export and verify a new complete encrypted recovery archive.
6. Provision each card from a separate restored copy.
7. Verify all cards contain the new fingerprints.
8. Update SSH `authorized_keys` everywhere if the authentication subkey changes.
9. Publish the refreshed public certificate.
10. Retain old encryption private material offline for historical decryption.
11. Revoke old subkeys only when intended; expiration alone may be preferable for planned rollover.

Do not delete an old encryption private key if historical ciphertext may still require it.

## Per-card provisioning detail

### Confirm and optionally reset

```sh
ykman list
ykman --device SERIAL openpgp info
ykman --device SERIAL openpgp reset --force  # only after explicit confirmation
```

A reset returns OpenPGP PINs to defaults and erases OpenPGP slots/settings. It does not reset FIDO, PIV, or OTP. Still, confirm the exact serial immediately before running it.

### Change credentials interactively

```sh
ykman --device SERIAL openpgp access change-pin
ykman --device SERIAL openpgp access change-admin-pin
ykman --device SERIAL openpgp access change-reset-code
```

Never use `--pin`, `--admin-pin`, `--new-pin`, or similar value-bearing options because they expose secrets in process arguments/history.

If the user PIN is wrong, stop after one attempt. Replace it using the known admin PIN:

```sh
ykman --device SERIAL openpgp access unblock-pin --admin-pin -
```

### Configure attributes

Use `gpg --edit-card`, then `admin`, then `key-attr`. Select RSA and 4096 for signature, encryption, and authentication. Complete one prompt at a time. Do not run `ykman` concurrently.

### Restore separately for each card

```sh
CARDHOME=$(mktemp -d)
chmod 700 "$CARDHOME"
GNUPGHOME="$CARDHOME" gpg --import secret-master-and-subkeys.asc
GNUPGHOME="$CARDHOME" gpg --card-status
GNUPGHOME="$CARDHOME" gpg --edit-key PRIMARY_FPR
```

Inside `gpg --edit-key`:

- `key 1`, `keytocard`, slot 1 for signing
- deselect key 1; `key 2`, `keytocard`, slot 2 for encryption
- deselect key 2; `key 3`, `keytocard`, slot 3 for authentication
- `save`

Selection state is critical: exactly one `ssb*` must be shown before each `keytocard`.

### Enable touch

```sh
ykman --device SERIAL openpgp keys set-touch --force sig on
ykman --device SERIAL openpgp keys set-touch --force dec on
ykman --device SERIAL openpgp keys set-touch --force aut on
```

Each prompts interactively for admin PIN.

### Tests

- Sign a new text file and verify its detached signature.
- Encrypt a new text file to the primary fingerprint, decrypt with the card, and compare byte-for-byte.
- Export the SSH public key and verify its fingerprint.
- Perform a real `BatchMode=yes` SSH login where possible.
- Verify full slot fingerprints, touch policies, and `3/3/3` counters.
- Kill agents and remove the per-card restoration home.

## Publication

Export the refreshed public certificate:

```sh
GNUPGHOME="$RECOVERY/gnupg" gpg --armor --export PRIMARY_FPR > public-key-refreshed.asc
file public-key-refreshed.asc
! grep -q 'PRIVATE KEY BLOCK' public-key-refreshed.asc
```

Before sending, show the user:

- UID
- full primary fingerprint
- full subkey fingerprints
- expiration dates
- exact keyserver names

Publish only after explicit confirmation:

```sh
gpg --keyserver hkps://keyserver.ubuntu.com --send-keys PRIMARY_FPR
gpg --keyserver hkps://keys.openpgp.org --send-keys PRIMARY_FPR
```

Do not regard successful submission as verification. Retrieve each result into a newly created mode-700 `GNUPGHOME` and compare the UID, every full fingerprint, capabilities, and expiration metadata.

### Ubuntu verification

Retrieve by exact full fingerprint. Hockeypuck may be temporarily inconsistent while replicas converge, so use a bounded retry with a short delay. Avoid repeated uploads merely because one immediate lookup returns 404.

### keys.openpgp.org verification

This service separates cryptographic key publication from UID/email publication:

1. Verify the fingerprint endpoint returns the primary and all expected subkeys.
2. Upload JSON containing the armored public key to `/vks/v1/upload` and inspect the returned status. If the address is `unpublished`, submit the returned token and intended address to `/vks/v1/request-verify` using the documented JSON schema.
3. Keep the returned short-lived verification token out of output, logs, shell history, and chat; build request files with mode `600` and remove them immediately afterward.
4. Have the user complete the link sent by `keys.openpgp.org`.
5. Verify the by-email endpoint returns HTTP 200, import it into a fresh home, and compare the UID and all fingerprints.

Uploading to Ubuntu does not synchronize the key to `keys.openpgp.org`. Record publication status explicitly as `not published`, `fingerprint-only / UID pending`, or `fully published and email-discoverable`.

## Revocation

Revocation is normally irreversible after publication.

- Do not import the emergency `.rev` file during routine restore.
- For a compromised subkey, prefer a targeted subkey revocation signed by the certification key.
- For a lost certification key, use the emergency primary revocation certificate.
- Preserve revoked encryption private material offline for historical decryption.
- Export the newly revoked public certificate and publish only after explicit confirmation.

## Cleanup

After all copies and tests pass:

```sh
GNUPGHOME="$RECOVERY/gnupg" gpgconf --kill all
rm -rf "$RECOVERY"
```

On flash media and SSDs, `rm` is not a reliable cryptographic erasure mechanism. The primary defense is keeping private exports passphrase-protected, minimizing plaintext lifetime, and using encrypted storage. Never claim secure deletion unless the storage design actually provides it.
